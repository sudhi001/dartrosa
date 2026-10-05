import 'dart:async';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart' show FormEntryPrompt;
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../appearance.dart';
import '../localizations.dart';
import '../xform_scope.dart';

/// Answers [node] with [value] through the nearest form's controller.
AnswerResult answerQuestion(
  BuildContext context,
  QuestionNode node,
  AnswerValue? value,
) => XFormScope.of(context).controller.answer(node.index, value);

/// [text] as an answer of [node]'s data type (kept as text if it doesn't
/// parse, so the engine can reject it).
AnswerValue typedAnswer(QuestionNode node, String text) {
  final uncast = UncastValue(text);
  try {
    return castToDataType(uncast, node.dataType);
  } on Object {
    return uncast;
  }
}

/// The choices of [node] and the warning to show if they couldn't be
/// loaded: those of its `search()` appearance (external data, through
/// `dartrosa_external_data`'s `loadSelectChoices`), else its own. Like
/// ODK Collect's `ItemsWidgetUtils.loadItemsAndHandleErrors`, a failed
/// load gives no choices and a warning.
({List<SelectChoice> choices, String? warning}) loadChoices(
  BuildContext context,
  QuestionNode node,
) {
  if (!Appearance.parse(node.appearance).has('search()')) {
    return (choices: node.choices, warning: null);
  }
  final strings = XFormLocalizations.of(context);
  final form = XFormScope.of(context).controller.session.definition.formDef;
  try {
    return (
      choices: loadSelectChoices(FormEntryPrompt(form, node.index)),
      warning: null,
    );
  } on ExternalDataFileMissingException catch (e) {
    return (choices: const [], warning: strings.fileMissing(e.path));
  } on ExternalDataException catch (e) {
    return (choices: const [], warning: e.message);
  } on Object catch (e) {
    return (choices: const [], warning: strings.parserException('$e'));
  }
}

/// The image URI of [choice] of [node], if any (from its label, or the
/// image column of an external data choice).
String? choiceImage(QuestionNode node, SelectChoice choice) =>
    choice is ExternalSelectChoice
    ? choice.image
    : node.choiceMedia(choice, 'image');

/// The choices of [node] (see [loadChoices]).
List<SelectChoice> choicesOf(BuildContext context, QuestionNode node) =>
    loadChoices(context, node).choices;

/// The values of [node]'s selected choices.
Set<String> selectedValues(QuestionNode node) => switch (node.value) {
  MultipleItemsValue(:final selections) => {
    for (final s in selections) s.value,
  },
  SelectOneValue(:final selection) => {selection.value},
  final v? => {v.displayText},
  null => const {},
};

/// Answers a select-multiple [node] with the choices whose values are in
/// [values], in choice order.
void answerSelections(
  BuildContext context,
  QuestionNode node,
  Set<String> values,
) => answerQuestion(
  context,
  node,
  values.isEmpty
      ? null
      : MultipleItemsValue([
          for (final choice in choicesOf(context, node))
            if (values.contains(choice.value)) Selection.ofChoice(choice),
        ]),
);

/// Whether [group] has the `table-list` appearance: its selects form one
/// grid, on one screen.
bool isTableList(GroupNode group) =>
    group.appearance?.toLowerCase().contains('table-list') ?? false;

/// Selects or deselects the choice [value] of a select-multiple [node].
void toggleSelection(BuildContext context, QuestionNode node, String value) {
  final selected = selectedValues(node);
  answerSelections(
    context,
    node,
    selected.contains(value)
        ? ({...selected}..remove(value))
        : {...selected, value},
  );
}

/// Answers a select-one [node] with [choice] (`null` clears it) unless it
/// is read-only; with the `quick` appearance an accepted choice moves to
/// the next pager screen.
void selectChoice(
  BuildContext context,
  QuestionNode node,
  SelectChoice? choice,
) {
  if (node.isReadonly) return;
  final result = answerQuestion(
    context,
    node,
    choice == null ? null : SelectOneValue(Selection.ofChoice(choice)),
  );
  if (choice != null &&
      result is AnswerAccepted &&
      Appearance.parse(node.appearance).has('quick')) {
    XFormPagerScope.advanceOf(context)?.call();
  }
}

/// Gives the questions of a pager screen showing a single question a way
/// to move to the next screen (used by `quick` selects).
class XFormPagerScope extends InheritedWidget {
  /// Creates a scope whose questions can call [advance].
  const XFormPagerScope({
    required this.advance,
    required super.child,
    super.key,
  });

  /// Validates the screen and moves to the next one.
  final VoidCallback advance;

  /// The nearest screen's [advance], or `null` when the question is not
  /// alone on a pager screen.
  static VoidCallback? advanceOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<XFormPagerScope>()?.advance;

  @override
  bool updateShouldNotify(XFormPagerScope oldWidget) => false;
}

/// Asks screen readers to read out [message] (e.g. a validation error
/// that blocked moving on).
void announceError(BuildContext context, String message) => unawaited(
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
    assertiveness: Assertiveness.assertive,
  ),
);

/// A question's answer next to the buttons acting on it (capture, pick,
/// launch, ...); the buttons move under the answer when both don't fit
/// on one line (narrow screens, large text).
class AnswerWithActions extends StatelessWidget {
  /// Creates the row of [answer] and [actions].
  const AnswerWithActions({
    required this.answer,
    required this.actions,
    super.key,
  });

  /// The answer, usually a [Text].
  final Widget answer;

  /// The buttons; none for read-only questions.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.spaceBetween,
    spacing: 8,
    overflowSpacing: 8,
    children: [
      answer,
      if (actions.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
    ],
  );
}
