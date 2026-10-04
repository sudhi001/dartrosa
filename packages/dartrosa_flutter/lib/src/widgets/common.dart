import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/widgets.dart';

import '../xform_scope.dart';

/// Answers [node] with [value] through the nearest form's controller.
AnswerResult answerQuestion(
  BuildContext context,
  QuestionNode node,
  AnswerValue? value,
) => XFormScope.of(context).controller.answer(node.index, value);

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
          for (final choice in node.choices)
            if (values.contains(choice.value)) Selection.ofChoice(choice),
        ]),
);

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
