import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'external_data_util.dart';

/// Types saved answers of selects whose choices come from `search()`: the
/// saved values aren't among the form's static choices, so the default
/// resolver would drop them.
///
/// Port of Collect's `ExternalAnswerResolver` (Collect sets it while
/// loading a saved instance). Pass it to `loadXmlInstance` or
/// `XFormParser.parse`; `ExternalDataPlugin` provides it to sessions.
AnswerValue? externalAnswerResolver(
  String textVal,
  TreeElement treeElement,
  FormDef formDef,
) {
  final questionDef = questionForData(
    treeElement.dataType,
    formDef,
    treeElement.ref,
  );
  final controlType = questionDef?.controlType;
  if (questionDef != null &&
      (controlType == ControlType.selectOne ||
          controlType == ControlType.selectMulti ||
          controlType == ControlType.rank) &&
      ExternalDataUtil.getSearchXPathExpression(questionDef.appearance) !=
          null) {
    // Dynamic selects: read the static choices from the options sheet.
    final staticChoices = questionDef.choices ?? const <SelectChoice>[];
    for (var index = 0; index < staticChoices.length; index++) {
      final selectChoice = staticChoices[index];
      final selectChoiceValue = selectChoice.value;
      if (ExternalDataUtil.isAnInteger(selectChoiceValue)) {
        final selection = Selection.ofChoice(selectChoice);
        if (controlType == ControlType.selectOne) {
          // The user selected a static choice.
          if (selectChoiceValue == textVal) return SelectOneValue(selection);
        } else {
          // Collect checks whether the values contain the whole saved
          // text, so this only matches a single saved value.
          final textValues = textVal.split(' ').where((v) => v.isNotEmpty);
          if (textValues.contains(textVal) && selectChoiceValue == textVal) {
            return SelectMultiValue([selection]);
          }
        }
      } else {
        if (controlType == ControlType.selectOne) {
          // Wrap the saved value in a virtual choice.
          final customSelectChoice = SelectChoice.fromItem(
            textVal,
            textVal,
            isLocalizable: false,
          )..index = index;
          return SelectOneValue(Selection.ofChoice(customSelectChoice));
        }
        return SelectMultiValue([
          for (final choice in createCustomSelectChoices(textVal))
            Selection.ofChoice(choice),
        ]);
      }
    }
    // Only static numeric choices, none selected: Collect reports a bug.
    throw StateError(
      'The appearance column of the field ${treeElement.name} contains a '
      'search() call and the field type is ${treeElement.dataType} and the '
      'saved answer is $textVal',
    );
  }
  // The default behaviour for static selects, etc.
  return defaultAnswerResolver(textVal, treeElement, formDef);
}

/// A literal choice for each space-separated value of [completeTextValue].
List<SelectChoice> createCustomSelectChoices(String completeTextValue) {
  var index = 0;
  return [
    for (final textValue in completeTextValue.split(' '))
      if (textValue.isNotEmpty)
        SelectChoice.fromItem(textValue, textValue, isLocalizable: false)
          ..index = index++,
  ];
}
