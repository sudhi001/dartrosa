// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'delegates.dart';
import 'localizations.dart';
import 'outline.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/external_app_inputs.dart';
import 'widgets/label.dart';
import 'widgets/node_widgets.dart';
import 'widgets/question_focus.dart';
import 'window_size.dart';
import 'xform_controller.dart';
import 'xform_scope.dart';

/// How a form is laid out.
enum XFormMode {
  /// All relevant questions on one scrolling page.
  scroll,

  /// One screen per question (or field-list group), like ODK Collect.
  pager,
}

/// Where [XFormView] offers the form outline: every group and question
/// with its state (answered, required, error) and the current position,
/// to jump to any of them, like ODK Collect's hierarchy ("jump to")
/// screen.
enum XFormOutlineMode {
  /// A side panel when the view is at least 840dp wide (a Material
  /// expanded window), which the person can hide; on narrower views a
  /// bottom sheet, opened from the pager's progress button or by
  /// [XFormViewState.showOutline].
  adaptive,

  /// Only a bottom sheet, opened from the pager's progress button or by
  /// [XFormViewState.showOutline]; no side panel.
  onRequest,

  /// No outline (like Collect with "jump to" turned off): the pager
  /// still shows its progress, [XFormViewState.showOutline] does
  /// nothing.
  none,
}

/// Shows a form being filled.
///
/// The layout adapts to the width the view is given:
///
/// * narrower than 600dp (phones): one column using the full width;
/// * 600dp and wider: a centered column at most
///   [XFormTheme.effectiveMaxContentWidth] wide (720dp by default);
/// * 840dp and wider: also the form outline as a side panel (see
///   [outline]).
///
/// In pager mode the bottom bar shows Back, the position ("3 of 12",
/// which opens the outline) and Next. With a keyboard, Page Down and
/// Alt+Right (Alt+Left in right-to-left forms) move to the next screen,
/// Page Up and Alt+Left to the previous one, and Enter in a one-line
/// text field moves to the next field (or screen, for a question alone
/// on its screen). When moving on is blocked by an error, and when
/// finalizing fails, the first question in error is scrolled into view
/// and focused.
///
/// Use a `GlobalKey<XFormViewState>` to open the outline or jump to a
/// question from the app (for example from an app bar button).
class XFormView extends StatefulWidget {
  /// Creates a view of [session].
  const XFormView({
    required this.session,
    this.mode = XFormMode.pager,
    this.delegates = const NoDelegates(),
    this.widgetOverrides = const {},
    this.onFinalized,
    this.guidanceHints = GuidanceHintMode.yes,
    this.outline = XFormOutlineMode.adaptive,
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

  /// Where the form outline is offered (by default a side panel on wide
  /// views, a bottom sheet elsewhere).
  final XFormOutlineMode outline;

  @override
  XFormViewState createState() => XFormViewState();
}

/// The state of an [XFormView]: opens the outline and jumps to
/// questions. Reach it with a `GlobalKey<XFormViewState>`.
class XFormViewState extends State<XFormView> {
  late XFormController _controller = XFormController(widget.session);

  /// The pager screen shown (a question or a field-list group), for the
  /// outline; `null` in scroll mode and on the pager's other pages.
  final _currentScreen = ValueNotifier<FormIndex?>(null);
  final _pagerKey = GlobalKey<_PagerFormState>();
  final _scrollKey = GlobalKey<_ScrollFormState>();

  /// Whether the last layout was wide enough for the side panel.
  var _wide = false;

  /// Whether the person hid the side panel.
  var _panelHidden = false;

  /// Whether the outline is shown as a side panel.
  bool get isOutlinePanelVisible =>
      widget.outline == XFormOutlineMode.adaptive && _wide && !_panelHidden;

  @override
  void didUpdateWidget(covariant XFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _controller.dispose();
      _controller = XFormController(widget.session);
      _currentScreen.value = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentScreen.dispose();
    super.dispose();
  }

  /// Shows the outline: the side panel on wide views (showing it again
  /// if it was hidden), else a bottom sheet. Does nothing with
  /// [XFormOutlineMode.none].
  void showOutline() {
    switch (widget.outline) {
      case XFormOutlineMode.none:
        return;
      case XFormOutlineMode.adaptive when _wide:
        setState(() => _panelHidden = false);
      case XFormOutlineMode.adaptive || XFormOutlineMode.onRequest:
        _openOutlineSheet();
    }
  }

  /// Hides the outline side panel (it stays reachable from the collapsed
  /// rail, the pager's progress button and [showOutline]).
  void hideOutline() => setState(() => _panelHidden = true);

  /// Shows the question at [index] (or the first question of the group
  /// or repeat at [index]): in pager mode its screen, in scroll mode
  /// scrolled into view; then focuses it.
  void jumpTo(FormIndex index) => _jumpToNode(widget.session.nodeAt(index));

  void _jumpToNode(FormNode node) {
    final target = firstQuestionIn(node);
    if (target == null) return;
    switch (widget.mode) {
      case XFormMode.pager:
        _pagerKey.currentState?.show(target);
      case XFormMode.scroll:
        _scrollKey.currentState?.reveal(target).ignore();
    }
  }

  TextDirection _direction(BuildContext context) =>
      textDirectionOfLanguage(widget.session.language) ??
      Directionality.of(context);

  void _openOutlineSheet() {
    final direction = _direction(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: direction,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.3,
          builder: (context, scroll) => FormOutline(
            controller: _controller,
            currentScreen: _currentScreen,
            scrollController: scroll,
            onClose: () => Navigator.pop(sheetContext),
            onSelected: (node) {
              Navigator.pop(sheetContext);
              _jumpToNode(node);
            },
          ),
        ),
      ),
    ).ignore();
  }

  void _finalize(BuildContext context) {
    final result = _controller.finalize();
    switch (result) {
      case FinalizeSuccess(:final submission):
        widget.onFinalized?.call(submission);
      case FinalizeFailure(:final failure):
        _jumpToNode(widget.session.nodeAt(failure.index));
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

  /// The outline's entry point while the side panel is not shown: the
  /// pager's progress button opens it; `null` without an outline.
  VoidCallback? get _outlineAction =>
      widget.outline == XFormOutlineMode.none || isOutlinePanelVisible
      ? null
      : showOutline;

  @override
  Widget build(BuildContext context) => XFormScope(
    controller: _controller,
    delegates: widget.delegates,
    overrides: widget.widgetOverrides,
    guidanceHints: widget.guidanceHints,
    // Right-to-left form languages (ar, fa, he, ...) flip the layout.
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, child) =>
          Directionality(textDirection: _direction(context), child: child!),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _wide =
              XFormWindowSize.fromWidth(constraints.maxWidth) >=
              XFormWindowSize.expanded;
          final theme = XFormTheme.of(context);
          final collapsed =
              widget.outline == XFormOutlineMode.adaptive &&
              _wide &&
              _panelHidden;
          final form = Builder(
            builder: (context) => switch (widget.mode) {
              XFormMode.scroll => _ScrollForm(
                key: _scrollKey,
                onFinalize: () => _finalize(context),
              ),
              XFormMode.pager => _PagerForm(
                key: _pagerKey,
                currentScreen: _currentScreen,
                onFinalize: () => _finalize(context),
                onOutline: () => _outlineAction,
              ),
            },
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOutlinePanelVisible) ...[
                SizedBox(
                  key: const ValueKey('outline'),
                  width: theme.outlinePanelWidth,
                  child: FocusTraversalGroup(
                    child: FormOutline(
                      controller: _controller,
                      currentScreen: _currentScreen,
                      onSelected: _jumpToNode,
                      onClose: hideOutline,
                      closeIcon: Icons.chevron_left,
                    ),
                  ),
                ),
                const VerticalDivider(key: ValueKey('divider'), width: 1),
              ] else if (collapsed) ...[
                _CollapsedOutline(
                  key: const ValueKey('collapsed'),
                  onOpen: showOutline,
                ),
                const VerticalDivider(key: ValueKey('divider'), width: 1),
              ],
              Expanded(
                key: const ValueKey('form'),
                // Focus moves in form order, not by on-screen geometry.
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: form,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// The side panel while hidden: a button showing it again.
class _CollapsedOutline extends StatelessWidget {
  const _CollapsedOutline({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Column(
      children: [
        IconButton(
          tooltip: XFormLocalizations.of(context).outline,
          icon: const Icon(Icons.toc),
          onPressed: onOpen,
        ),
      ],
    ),
  );
}

/// [child], a scroll view driven by [controller], with a scroll bar that
/// stays visible on desktops and in browsers; text in it can be selected
/// with the mouse there.
class _FormScrollbar extends StatelessWidget {
  const _FormScrollbar({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopOrWeb(context)) return child;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SelectionArea(child: child),
      ),
    );
  }
}

class _ScrollForm extends StatefulWidget {
  const _ScrollForm({required this.onFinalize, super.key});

  final VoidCallback onFinalize;

  @override
  State<_ScrollForm> createState() => _ScrollFormState();
}

class _ScrollFormState extends State<_ScrollForm> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls [question] into view and focuses it. The list is built
  /// lazily: until the question is built, scrolls towards its top-level
  /// node a screen at a time.
  Future<void> reveal(QuestionNode question) async {
    final session = XFormScope.of(context).controller.session;
    final top = question.ancestors.firstOrNull ?? question;
    for (var attempt = 0; attempt < 500; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      if (revealNode(context, question)) return;
      final nodes = session.root.visibleChildren;
      final target = nodes.indexWhere((n) => n.index == top.index);
      if (target < 0) return;
      final position = _scroll.position;
      final built = _builtRange(nodes);
      final double offset;
      if (built == null || attempt == 0) {
        // First a guess in proportion to the node's place in the form.
        offset = position.maxScrollExtent * target / nodes.length;
      } else if (target < built.$1) {
        offset = position.pixels - position.viewportDimension;
      } else if (target > built.$2) {
        offset = position.pixels + position.viewportDimension;
      } else {
        // Built but its question isn't (hidden): nothing to show.
        return;
      }
      final clamped = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (attempt > 0 && clamped == position.pixels) return;
      _scroll.jumpTo(clamped);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// The first and last of [nodes] (top-level) built in the list.
  (int, int)? _builtRange(List<FormNode> nodes) {
    final byKey = {for (final (i, n) in nodes.indexed) nodeKey(n): i};
    int? first;
    int? last;
    void visit(Element element) {
      final i = byKey[element.widget.key];
      if (i != null) {
        if (first == null || i < first!) first = i;
        if (last == null || i > last!) last = i;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return first == null ? null : (first!, last!);
  }

  @override
  Widget build(BuildContext context) {
    final scope = XFormScope.of(context);
    return ListenableBuilder(
      // Structural changes and the relevance of top-level nodes.
      listenable: scope.controller.listenableFor(null),
      builder: (context, _) {
        final nodes = scope.controller.session.root.visibleChildren;
        Map<Key, int>? positions;
        final theme = XFormTheme.of(context);
        // Built lazily: forms can have hundreds of questions.
        return LayoutBuilder(
          builder: (context, constraints) => _FormScrollbar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              padding: theme.pagePaddingFor(constraints.maxWidth),
              itemCount: nodes.length + 1,
              // Questions shown or hidden above keep the others' elements.
              findChildIndexCallback: (key) => (positions ??= {
                for (var i = 0; i < nodes.length; i++) nodeKey(nodes[i]): i,
              })[key],
              itemBuilder: (context, i) => i < nodes.length
                  ? nodeWidget(nodes[i])
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 48),
                        ),
                        onPressed: widget.onFinalize,
                        child: Text(XFormLocalizations.of(context).finish),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Moves the pager forward or back (keyboard shortcuts).
class _PageIntent extends Intent {
  const _PageIntent({required this.forward, this.arrow = false});

  final bool forward;

  /// Whether the shortcut is an arrow key (left alone in text fields,
  /// where it moves the cursor).
  final bool arrow;
}

class _PagerForm extends StatefulWidget {
  const _PagerForm({
    required this.currentScreen,
    required this.onFinalize,
    required this.onOutline,
    super.key,
  });

  final ValueNotifier<FormIndex?> currentScreen;
  final VoidCallback onFinalize;

  /// The outline's entry point (read at build time), if any.
  final VoidCallback? Function() onOutline;

  @override
  State<_PagerForm> createState() => _PagerFormState();
}

class _PagerFormState extends State<_PagerForm> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'XFormView pager', skipTraversal: true);

  FormNavigator get _nav => XFormScope.of(context).controller.session.navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nav.event == FormEntryEvent.beginningOfForm) _forward();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The field-list group containing the current position, if any.
  FormIndex? _fieldList() {
    final current = _nav.current;
    for (final ancestor in [...current.ancestors.reversed, current]) {
      if (isScreenGroup(ancestor)) return ancestor.index;
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
        if (isScreenGroup(_nav.current)) break;
        event = _nav.next();
        continue;
      }
      break;
    }
  }

  void _back() {
    var event = _nav.previous();
    while (event == FormEntryEvent.group || event == FormEntryEvent.repeat) {
      if (isScreenGroup(_nav.current)) break;
      event = _nav.previous();
    }
    if (event == FormEntryEvent.beginningOfForm) {
      _forward();
      return;
    }
    final fieldList = _fieldList();
    if (fieldList != null) _nav.jumpTo(fieldList);
  }

  /// Runs [move], then keeps keyboard focus in the pager if it was there
  /// (the focused control may be gone with the old screen).
  void _move(VoidCallback move) {
    final hadFocus = _focus.hasFocus;
    setState(move);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!hadFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  /// Shows the screen of [question] and focuses it.
  void show(QuestionNode question) {
    final screen = screenGroupOf(question);
    _move(() => _nav.jumpTo((screen ?? question).index));
    _revealAfterFrame(question);
  }

  void _revealAfterFrame(QuestionNode question) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealNode(context, question);
    });
  }

  /// Re-answers the questions on screen; whether all were accepted. The
  /// first question in error is scrolled to and focused.
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
    QuestionNode? firstInvalid;
    for (final q in questions) {
      if (q.isReadonly) continue;
      if (controller.answer(q.index, q.value) is! AnswerAccepted) {
        firstInvalid ??= q;
        firstError ??= controller.errorFor(
          q.index,
          XFormLocalizations.of(context),
        );
      }
    }
    if (firstError != null) announceError(context, firstError);
    if (firstInvalid != null) _revealAfterFrame(firstInvalid);
    return firstInvalid == null;
  }

  void _next() {
    final event = _nav.event;
    if (event == FormEntryEvent.endOfForm ||
        event == FormEntryEvent.promptNewRepeat) {
      return;
    }
    if (_validateScreen()) _move(_forward);
  }

  void _previous() => _move(_back);

  /// The screen shown: the current question or field-list group.
  FormIndex? _screen() => switch (_nav.event) {
    FormEntryEvent.question || FormEntryEvent.group => _nav.current.index,
    _ => null,
  };

  bool _pageShortcutEnabled(_PageIntent intent) {
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    if (focused is! EditableText) return true;
    // Arrows move the cursor; page keys too in multi-line fields.
    return !intent.arrow && focused.maxLines == 1;
  }

  @override
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.pageDown): const _PageIntent(
          forward: true,
        ),
        const SingleActivator(LogicalKeyboardKey.pageUp): const _PageIntent(
          forward: false,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            _PageIntent(forward: !rtl, arrow: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            _PageIntent(forward: rtl, arrow: true),
      },
      child: Actions(
        actions: {_PageIntent: _PageAction(this)},
        child: Focus(
          focusNode: _focus,
          autofocus: isDesktopOrWeb(context),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _page(context),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final event = _nav.event;
    final screen = _screen();
    if (screen != widget.currentScreen.value) {
      // After this frame: the outline is built beside the pager.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.currentScreen.value = screen;
      });
    }
    final Widget page = switch (event) {
      FormEntryEvent.endOfForm => _MaxContentWidth(
        child: _EndPage(onFinalize: widget.onFinalize),
      ),
      FormEntryEvent.promptNewRepeat => _MaxContentWidth(
        child: _NewRepeatPage(
          node: _nav.current,
          onAdd: () => _move(() {
            _nav.addRepeatAndEnter();
            _forward();
          }),
          onSkip: () => _move(_forward),
        ),
      ),
      _ => LayoutBuilder(
        builder: (context, constraints) => _FormScrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: XFormTheme.of(
              context,
            ).pagePaddingFor(constraints.maxWidth),
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
        ),
      ),
    };
    return Column(
      children: [
        Expanded(child: page),
        _PagerBar(
          event: event,
          screen: screen,
          onBack: _previous,
          onNext: _next,
          onOutline: widget.onOutline(),
        ),
      ],
    );
  }
}

class _PageAction extends Action<_PageIntent> {
  _PageAction(this.pager);

  final _PagerFormState pager;

  @override
  bool isEnabled(_PageIntent intent) => pager._pageShortcutEnabled(intent);

  @override
  Object? invoke(_PageIntent intent) {
    if (intent.forward) {
      pager._next();
    } else {
      pager._previous();
    }
    return null;
  }
}

/// The pager's bottom bar: progress, Back, the position (opening the
/// outline) and Next.
class _PagerBar extends StatelessWidget {
  const _PagerBar({
    required this.event,
    required this.screen,
    required this.onBack,
    required this.onNext,
    required this.onOutline,
  });

  final FormEntryEvent event;
  final FormIndex? screen;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onOutline;

  @override
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final strings = XFormLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final compact =
        XFormWindowSize.fromWidth(MediaQuery.sizeOf(context).width) <
        XFormWindowSize.medium;
    // Thumb-sized buttons on phones, with less padding to leave room for
    // large text.
    final buttonSize = Size(64, compact ? 48 : 40);
    final buttonPadding = compact
        ? const EdgeInsetsDirectional.symmetric(horizontal: 12)
        : null;
    return ListenableBuilder(
      // Relevance changes the number of screens.
      listenable: controller.formChanges,
      builder: (context, _) {
        final summary = OutlineSummary.of(
          outlineEntries(controller.session.root),
          controller,
        );
        final total = summary.screens.length;
        final atEnd = event == FormEntryEvent.endOfForm;
        final index = atEnd ? total : summary.positionOf(screen);
        final hasPosition = total > 0 && index >= 0;
        final canGoBack = index != 0;
        final showNext = !atEnd && event != FormEntryEvent.promptNewRepeat;
        final position = hasPosition
            ? strings.progress(math.min(index + 1, total), total)
            : '';
        return Material(
          color: scheme.surfaceContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The position text says the same to screen readers.
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: !hasPosition ? 0 : (atEnd ? 1 : (index + 1) / total),
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              SafeArea(
                top: false,
                child: _MaxContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final back = strings.back;
                        final next = strings.next;
                        // Labels when they fit beside the position, else
                        // icon buttons (narrow screens, large text).
                        final labels =
                            _buttonWidth(context, back) +
                                (showNext ? _buttonWidth(context, next) : 0) +
                                48 <=
                            constraints.maxWidth;
                        return Row(
                          children: [
                            if (labels)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: buttonSize,
                                  padding: buttonPadding,
                                ),
                                icon: const Icon(Icons.chevron_left),
                                label: Text(back),
                                onPressed: canGoBack ? onBack : null,
                              )
                            else
                              IconButton.outlined(
                                tooltip: back,
                                icon: const Icon(Icons.chevron_left),
                                onPressed: canGoBack ? onBack : null,
                              ),
                            Expanded(
                              child: Center(
                                child: hasPosition
                                    ? _Position(
                                        text: position,
                                        onPressed: onOutline,
                                      )
                                    : null,
                              ),
                            ),
                            if (showNext && labels)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: buttonSize,
                                  padding: buttonPadding,
                                ),
                                icon: const Icon(Icons.chevron_right),
                                iconAlignment: IconAlignment.end,
                                label: Text(next),
                                onPressed: onNext,
                              )
                            else if (showNext)
                              IconButton.filled(
                                tooltip: next,
                                icon: const Icon(Icons.chevron_right),
                                onPressed: onNext,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The width of a pager button labelled [label] (with its icon and
/// padding) at the current text scale.
double _buttonWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: Theme.of(context).textTheme.labelLarge),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  // Icon 18, gap 8, padding 16 and 24 (at most).
  return width + 18 + 8 + 40;
}

/// The pager's position ("3 of 12"): a button opening the outline when
/// [onPressed] is set.
class _Position extends StatelessWidget {
  const _Position({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge,
    );
    final onPressed = this.onPressed;
    if (onPressed == null) {
      return Padding(padding: const EdgeInsets.all(8), child: label);
    }
    final outline = XFormLocalizations.of(context).outline;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Between the buttons on a narrow screen with large text there
        // may only be room for the icon.
        final textWidth = MediaQuery.textScalerOf(
          context,
        ).scale(8.0 * text.length);
        if (constraints.maxWidth < 48) return const SizedBox.shrink();
        if (constraints.maxWidth < 64 + textWidth) {
          return IconButton(
            tooltip: '$outline, $text',
            icon: const Icon(Icons.toc),
            onPressed: onPressed,
          );
        }
        return Tooltip(
          message: outline,
          child: TextButton.icon(
            icon: const Icon(Icons.toc),
            label: label,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}

/// [child] at most as wide as the theme's content (with its page
/// padding), centered.
class _MaxContentWidth extends StatelessWidget {
  const _MaxContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = XFormTheme.of(context);
    final max = theme.effectiveMaxContentWidth;
    if (!max.isFinite) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: max + theme.pagePadding.horizontal,
        ),
        child: child,
      ),
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
          Icon(
            Icons.library_add_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
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
            runSpacing: 12,
            alignment: WrapAlignment.center,
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
    final controller = XFormScope.of(context).controller;
    final session = controller.session;
    final theme = Theme.of(context);
    final strings = XFormLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              session.definition.title ?? '',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(strings.endOfForm, textAlign: TextAlign.center),
            ListenableBuilder(
              listenable: controller.formChanges,
              builder: (context, _) {
                final summary = OutlineSummary.of(
                  outlineEntries(session.root),
                  controller,
                );
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      strings.answeredCount(
                        summary.answered,
                        summary.answerable,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (summary.missing > 0)
                      Text(
                        strings.requiredLeft(summary.missing),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: XFormTheme.of(context).errorColorOf(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: onFinalize,
              child: Text(strings.finalize),
            ),
          ],
        ),
      ),
    );
  }
}
