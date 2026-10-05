import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import 'delegates.dart';
import 'localizations.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/external_app_inputs.dart';
import 'widgets/label.dart';
import 'widgets/node_widgets.dart';
import 'xform_controller.dart';
import 'xform_scope.dart';

/// How a form is laid out.
enum XFormMode {
  /// All relevant questions on one scrolling page.
  scroll,

  /// One screen per question (or field-list group), like ODK Collect.
  pager,
}

/// Shows a form being filled.
class XFormView extends StatefulWidget {
  /// Creates a view of [session].
  const XFormView({
    required this.session,
    this.mode = XFormMode.pager,
    this.delegates = const NoDelegates(),
    this.widgetOverrides = const {},
    this.onFinalized,
    this.guidanceHints = GuidanceHintMode.yes,
    super.key,
  });

  /// When guidance hints are shown.
  final GuidanceHintMode guidanceHints;

  /// The form being filled.
  final FormSession session;

  /// The layout.
  final XFormMode mode;

  /// Platform features for capture questions.
  final XFormDelegates delegates;

  /// Replacement question widgets by `controlType` name (optionally with
  /// `:appearance`).
  final Map<String, QuestionWidgetBuilder> widgetOverrides;

  /// Called with the submission when the form is finalized.
  final ValueChanged<Submission>? onFinalized;

  @override
  State<XFormView> createState() => _XFormViewState();
}

class _XFormViewState extends State<XFormView> {
  late XFormController _controller = XFormController(widget.session);

  @override
  void didUpdateWidget(covariant XFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _controller.dispose();
      _controller = XFormController(widget.session);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finalize(BuildContext context) {
    final result = _controller.finalize();
    switch (result) {
      case FinalizeSuccess(:final submission):
        widget.onFinalized?.call(submission);
      case FinalizeFailure(:final failure):
        if (widget.mode == XFormMode.pager) {
          setState(() => widget.session.navigator.jumpTo(failure.index));
        }
        final strings = XFormLocalizations.of(context);
        announceError(
          context,
          _controller.errorFor(failure.index, strings) ??
              strings.answersNeedAttention,
        );
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(strings.answersNeedAttention)));
    }
  }

  @override
  Widget build(BuildContext context) => XFormScope(
    controller: _controller,
    delegates: widget.delegates,
    overrides: widget.widgetOverrides,
    guidanceHints: widget.guidanceHints,
    // Right-to-left form languages (ar, fa, he, ...) flip the layout.
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => Directionality(
        textDirection:
            textDirectionOfLanguage(widget.session.language) ??
            Directionality.of(context),
        child: child!,
      ),
      // Focus moves in form order, not by on-screen geometry.
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Builder(
          builder: (context) => switch (widget.mode) {
            XFormMode.scroll => _ScrollForm(
              onFinalize: () => _finalize(context),
            ),
            XFormMode.pager => _PagerForm(onFinalize: () => _finalize(context)),
          },
        ),
      ),
    ),
  );
}

class _ScrollForm extends StatelessWidget {
  const _ScrollForm({required this.onFinalize});

  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    final scope = XFormScope.of(context);
    return ListenableBuilder(
      listenable: scope.controller,
      builder: (context, _) {
        final nodes = scope.controller.session.root.visibleChildren;
        // Built lazily: forms can have hundreds of questions.
        return ListView.builder(
          padding: XFormTheme.of(context).pagePadding,
          itemCount: nodes.length + 1,
          itemBuilder: (context, i) => i < nodes.length
              ? nodeWidget(nodes[i])
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton(
                    onPressed: onFinalize,
                    child: Text(XFormLocalizations.of(context).finish),
                  ),
                ),
        );
      },
    );
  }
}

class _PagerForm extends StatefulWidget {
  const _PagerForm({required this.onFinalize});

  final VoidCallback onFinalize;

  @override
  State<_PagerForm> createState() => _PagerFormState();
}

class _PagerFormState extends State<_PagerForm> {
  FormNavigator get _nav => XFormScope.of(context).controller.session.navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nav.event == FormEntryEvent.beginningOfForm) _forward();
  }

  /// Whether [node] is a group shown as one screen (`field-list`, or
  /// `table-list`, which implies it).
  static bool _isScreen(FormNode node) =>
      node is GroupNode && (node.isFieldList || isTableList(node));

  /// The field-list group containing the current position, if any.
  FormIndex? _fieldList() {
    final current = _nav.current;
    for (final ancestor in [...current.ancestors.reversed, current]) {
      if (_isScreen(ancestor)) return ancestor.index;
    }
    return null;
  }

  /// Moves forward past groups and repeat headers (shown with their
  /// content) and out of a field-list group shown as one screen.
  void _forward() {
    final fieldList = _fieldList();
    var event = _nav.next();
    while (true) {
      if (fieldList != null &&
          event != FormEntryEvent.endOfForm &&
          FormIndex.isSubElement(fieldList, _nav.position)) {
        event = _nav.next();
        continue;
      }
      if (event == FormEntryEvent.group || event == FormEntryEvent.repeat) {
        if (_isScreen(_nav.current)) break;
        event = _nav.next();
        continue;
      }
      break;
    }
  }

  void _back() {
    var event = _nav.previous();
    while (event == FormEntryEvent.group || event == FormEntryEvent.repeat) {
      if (_isScreen(_nav.current)) break;
      event = _nav.previous();
    }
    if (event == FormEntryEvent.beginningOfForm) {
      _forward();
      return;
    }
    final fieldList = _fieldList();
    if (fieldList != null) _nav.jumpTo(fieldList);
  }

  /// Re-answers the questions on screen; whether all were accepted.
  bool _validateScreen() {
    final controller = XFormScope.of(context).controller;
    final current = _nav.current;
    final questions = <QuestionNode>[];
    void collect(FormNode node) {
      if (!node.isRelevant) return;
      switch (node) {
        case QuestionNode():
          questions.add(node);
        case ContainerNode():
          node.children.forEach(collect);
        case RepeatNode():
          node.instances.forEach(collect);
      }
    }

    collect(current);
    String? firstError;
    for (final q in questions) {
      if (q.isReadonly) continue;
      if (controller.answer(q.index, q.value) is! AnswerAccepted) {
        firstError ??= controller.errorFor(
          q.index,
          XFormLocalizations.of(context),
        );
      }
    }
    if (firstError != null) announceError(context, firstError);
    return firstError == null;
  }

  void _next() {
    if (_validateScreen()) setState(_forward);
  }

  @override
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final event = _nav.event;
        final Widget page = switch (event) {
          FormEntryEvent.endOfForm => _EndPage(onFinalize: widget.onFinalize),
          FormEntryEvent.promptNewRepeat => _NewRepeatPage(
            node: _nav.current,
            onAdd: () => setState(() {
              _nav.addRepeatAndEnter();
              _forward();
            }),
            onSkip: () => setState(_forward),
          ),
          _ => SingleChildScrollView(
            padding: XFormTheme.of(context).pagePadding,
            // `quick` selects advance only when alone on the screen.
            child: _nav.current is QuestionNode
                ? XFormPagerScope(
                    advance: _next,
                    child: inIntentGroup(
                      context,
                      _nav.current as QuestionNode,
                      nodeWidget(_nav.current),
                    ),
                  )
                : nodeWidget(_nav.current),
          ),
        };
        return Column(
          children: [
            Expanded(child: page),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.chevron_left),
                      label: Text(XFormLocalizations.of(context).back),
                      onPressed: () => setState(_back),
                    ),
                    const Spacer(),
                    if (event != FormEntryEvent.endOfForm &&
                        event != FormEntryEvent.promptNewRepeat)
                      FilledButton.icon(
                        icon: const Icon(Icons.chevron_right),
                        label: Text(XFormLocalizations.of(context).next),
                        onPressed: _next,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewRepeatPage extends StatelessWidget {
  const _NewRepeatPage({
    required this.node,
    required this.onAdd,
    required this.onSkip,
  });

  final FormNode node;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          XFormLabel(node.label),
          const SizedBox(height: 16),
          Text(
            XFormLocalizations.of(
              context,
            ).addRepeatPrompt(node.label.text ?? ''),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: onSkip,
                child: Text(XFormLocalizations.of(context).doNotAdd),
              ),
              FilledButton(
                onPressed: onAdd,
                child: Text(XFormLocalizations.of(context).addGroup),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EndPage extends StatelessWidget {
  const _EndPage({required this.onFinalize});

  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    final session = XFormScope.of(context).controller.session;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.definition.title ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(XFormLocalizations.of(context).endOfForm),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onFinalize,
              child: Text(XFormLocalizations.of(context).finalize),
            ),
          ],
        ),
      ),
    );
  }
}
