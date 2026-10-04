/// The oracle's `describe` of a form-entry event (shared by the walk and
/// fuzz conformance tests).
library;

import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/data_type.dart';

import 'structure_dump.dart';

String _dataTypeName(DataType t) => t == DataType.nullType ? 'null' : t.name;

/// The event at the model's current index, as the oracle records it.
Map<String, Object?> describe(FormEntryModel model, FormEntryEvent event) {
  final e = <String, Object?>{'event': event.name};
  final ref = model.formIndex.reference;
  if (ref != null) e['ref'] = ref.toString(includePredicates: true);
  if (event == FormEntryEvent.question) {
    final p = model.questionPrompt();
    e
      ..['control'] = p.controlType.name
      ..['dataType'] = _dataTypeName(p.dataType)
      ..['appearance'] = p.appearanceHint
      ..['label'] = normalize(p.longText)
      ..['hint'] = normalize(p.helpText)
      ..['required'] = p.isRequired
      ..['readonly'] = p.isReadOnly;
    final value = p.answerValue;
    e['value'] = value == null ? null : normalize(value.uncast().string);
    final q = p.question;
    if (q.controlType == ControlType.selectOne ||
        q.controlType == ControlType.selectMulti ||
        q.controlType == ControlType.rank) {
      final choices = [
        for (final c in p.selectChoices)
          {'value': c.value, 'label': normalize(p.selectChoiceText(c))},
      ];
      final itemset = q.dynamicChoices;
      if (itemset != null &&
          itemset.randomize &&
          itemset.randomSeedExpr == null) {
        choices.sort((a, b) => '${a['value']}'.compareTo('${b['value']}'));
        e['choicesOrder'] = 'unseededRandom';
      }
      e['choices'] = choices;
    }
  } else if (event == FormEntryEvent.group || event == FormEntryEvent.repeat) {
    e
      ..['label'] = normalize(model.captionPrompt().longText)
      ..['appearance'] = model.captionPrompt().appearanceHint;
  }
  return e;
}
