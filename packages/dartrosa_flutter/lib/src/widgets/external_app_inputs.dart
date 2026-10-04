import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart' show FormEntryCaption;
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../external_apps.dart';
import '../localizations.dart';
import '../xform_scope.dart';
import 'common.dart';
import 'text_input.dart';

/// The `form` (e.g. `buttonText`, `noAppErrorString`) of [node]'s label.
String? _specialText(BuildContext context, FormNode node, String form) {
  final formDef = XFormScope.of(context).controller.session.definition.formDef;
  return FormEntryCaption(formDef, node.index).specialFormQuestionText(form);
}

/// A text, integer or decimal question filled by an external app (`ex:`
/// appearance) through `XFormDelegates.launchExternalApp`, like ODK
/// Collect's `ExStringWidget`, `ExIntegerWidget` and `ExDecimalWidget`:
/// the app gets the evaluated parameters and the current answer as
/// `value`, and returns the new answer as `value`. If no app handles the
/// request, the form's `noAppErrorString` is shown and the answer can be
/// typed.
class ExternalAppInput extends StatefulWidget {
  /// Creates the input for [node].
  const ExternalAppInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  State<ExternalAppInput> createState() => _ExternalAppInputState();
}

class _ExternalAppInputState extends State<ExternalAppInput> {
  /// Set when the app couldn't be launched; the answer is then typed.
  String? _error;

  Object? _valueForApp() => switch (widget.node.value) {
    IntegerValue(:final n) || LongValue(:final n) => n,
    DecimalValue(:final d) => d,
    _ => widget.node.displayValue,
  };

  AnswerValue? _answerFrom(Object? value) => switch (widget.node.dataType) {
    DataType.integer || DataType.long => ExternalAppsUtils.asIntegerData(value),
    DataType.decimal => ExternalAppsUtils.asDecimalData(value),
    _ => ExternalAppsUtils.asStringData(value),
  };

  Future<void> _launch() async {
    final node = widget.node;
    final scope = XFormScope.of(context);
    final delegates = scope.delegates;
    final strings = XFormLocalizations.of(context);
    final noApp = _specialText(context, node, 'noAppErrorString');
    final spec = externalAppSpec(node.appearance) ?? '';
    try {
      final params = ExternalAppsUtils.evaluateParameters(
        ExternalAppsUtils.extractParameters(spec),
        node.ref,
        scope.controller.session.definition.formDef,
        instanceProviderId: delegates.instanceProviderId ?? '-1',
      );
      // Collect's special key for the intent's data URI.
      final data = params.containsKey('uri_data')
          ? '${params.remove('uri_data')}'
          : null;
      final result = await delegates.launchExternalApp(
        context,
        intent: ExternalAppsUtils.extractIntentName(spec),
        params: {...params, 'value': _valueForApp()},
        data: data,
      );
      if (result == null || !mounted) return;
      answerQuestion(context, node, _answerFrom(result['value']));
    } on ExternalAppNotFoundException {
      if (mounted) setState(() => _error = noApp ?? strings.noApp);
    } on ExternalParamsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final error = _error;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          TextQuestionInput(node),
        ],
      );
    }
    final hidden = Appearance.parse(node.appearance).has('hidden-answer');
    return Row(
      children: [
        Expanded(
          child: hidden
              ? const SizedBox()
              : Text(numberDisplay(context, node) ?? ''),
        ),
        if (!node.isReadonly)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.open_in_new),
            label: Text(
              _specialText(context, node, 'buttonText') ??
                  XFormLocalizations.of(context).launchApp,
            ),
            onPressed: _launch,
          ),
      ],
    );
  }
}

/// A question whose answer is printed (`printer` appearance) through
/// `XFormDelegates.print`, like ODK Collect's `PrinterWidget`.
class PrinterInput extends StatelessWidget {
  /// Creates the input for [node].
  const PrinterInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FilledButton.tonalIcon(
      icon: const Icon(Icons.print),
      label: Text(XFormLocalizations.of(context).print),
      onPressed: () async {
        final content = node.displayValue;
        if (content == null) return;
        await XFormScope.of(context).delegates.print(context, content);
      },
    ),
  );
}

/// The `intent` attribute of [group], if it has a non-empty one.
String? intentOf(FormNode group) {
  if (group is! GroupNode) return null;
  final intent = group.element.additionalAttribute(null, 'intent');
  return intent == null || intent.isEmpty ? null : intent;
}

/// [child], the widget of [question] alone on a pager screen, in an
/// [IntentGroup] if the question's closest group has an `intent` (and
/// the app can launch external apps), as ODK Collect shows it.
Widget inIntentGroup(
  BuildContext context,
  QuestionNode question,
  Widget child,
) {
  final parent = question.ancestors.lastOrNull;
  if (parent is! GroupNode ||
      intentOf(parent) == null ||
      !XFormScope.of(context).delegates.canLaunchExternalApps) {
    return child;
  }
  return IntentGroup(group: parent, questions: [question], child: child);
}

/// The questions in [node], recursively.
List<QuestionNode> _questionsIn(FormNode node) => switch (node) {
  QuestionNode() => [node],
  ContainerNode() => [
    for (final child in node.visibleChildren) ..._questionsIn(child),
  ],
  RepeatNode() => const [],
};

/// The questions of a group with an `intent` attribute (shown read-only)
/// under a button launching the external app, like ODK Collect's intent
/// groups (`ODKView.addIntentLaunchButton`): the app gets the evaluated
/// parameters of the intent and, by name, the answers of the text,
/// integer, decimal and binary questions; it returns new answers by
/// name.
class IntentGroup extends StatefulWidget {
  /// Creates an intent group of [group] whose questions on screen are
  /// [questions], above [child].
  const IntentGroup({
    required this.group,
    required this.questions,
    required this.child,
    super.key,
  });

  /// Creates an intent group showing all of [group]'s questions.
  factory IntentGroup.of(GroupNode group, {required Widget child, Key? key}) =>
      IntentGroup(
        group: group,
        questions: _questionsIn(group),
        key: key,
        child: child,
      );

  /// The group.
  final GroupNode group;

  /// The questions sent to and filled by the app.
  final List<QuestionNode> questions;

  /// The questions' widgets (made read-only).
  final Widget child;

  @override
  State<IntentGroup> createState() => _IntentGroupState();
}

class _IntentGroupState extends State<IntentGroup> {
  String? _error;

  static const _exchanged = {
    DataType.text, DataType.integer, DataType.decimal, DataType.binary, //
  };

  Future<void> _launch() async {
    final group = widget.group;
    final scope = XFormScope.of(context);
    final delegates = scope.delegates;
    final strings = XFormLocalizations.of(context);
    final noApp = _specialText(context, group, 'noAppErrorString');
    final intent = intentOf(group)!;
    setState(() => _error = null);
    try {
      final params = {
        ...ExternalAppsUtils.evaluateParameters(
          ExternalAppsUtils.extractParameters(intent),
          group.ref,
          scope.controller.session.definition.formDef,
          instanceProviderId: delegates.instanceProviderId ?? '-1',
        ),
        for (final q in widget.questions)
          if (_exchanged.contains(q.dataType)) q.ref!.lastName: q.value?.value,
      };
      final result = await delegates.launchExternalApp(
        context,
        intent: ExternalAppsUtils.extractIntentName(intent),
        params: params,
      );
      if (result == null || !mounted) return;
      _setDataForFields(result, strings);
    } on ExternalAppNotFoundException {
      if (mounted) setState(() => _error = noApp ?? strings.noApp);
    } on ExternalParamsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Port of `ODKView.setDataForFields`.
  void _setDataForFields(Map<String, Object?> result, XFormLocalizations s) {
    for (final MapEntry(:key, :value) in result.entries) {
      if (value == null) continue;
      final question = widget.questions
          .where((q) => q.ref!.lastName == key)
          .firstOrNull;
      if (question == null) continue;
      final AnswerValue? answer;
      switch (question.dataType) {
        case DataType.text:
          answer = ExternalAppsUtils.asStringData(value);
        case DataType.integer:
          answer = ExternalAppsUtils.asIntegerData(value);
        case DataType.decimal:
          answer = ExternalAppsUtils.asDecimalData(value);
        case DataType.binary:
          answer = UncastValue('$value');
        default:
          setState(
            () => _error = s.cannotAssignValue(
              question.ref!.toString(includePredicates: false),
            ),
          );
          return;
      }
      answerQuestion(context, question, answer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.open_in_new),
            label: Text(
              _specialText(context, widget.group, 'buttonText') ??
                  XFormLocalizations.of(context).launchApp,
            ),
            onPressed: _launch,
          ),
        ),
        if (error != null)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        // Answers come from the app.
        ExcludeFocus(child: AbsorbPointer(child: widget.child)),
      ],
    );
  }
}
