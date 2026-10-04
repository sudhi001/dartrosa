// Port of JavaRosa v6.0.0 SelectOneQuestionTest.
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

XFormsElement _form(String formTitle, String id, String calculate) => html(
  head([
    title(formTitle),
    model([
      mainInstance([
        t('data id="$id"', [t('select')]),
      ]),
      instance('yes_no', [item(0, 'No'), item(1, 'Yes')]),
      bind('/data/select')
        ..type('string')
        ..calculate(calculate),
    ]),
  ]),
  body([select1Dynamic('/data/select', "instance('yes_no')/root/item")]),
);

void main() {
  test('choiceIsSelectedWhenLiteralStringValueMatchesChoiceValue', () async {
    final scenario = await Scenario.init(
      _form('String calculate', 'string-calculate', "if(1=2, '1', '0')"),
    );

    scenario.choicesOf('/data/select'); // Populate choices
    expect(
      scenario.answerOf('/data/select')!.value,
      Selection.ofChoice(scenario.choicesOf('/data/select')[0]),
    );
    expect(scenario.answerOf('/data/select'), isA<SelectOneValue>());
  });

  test('choiceIsSelectedWhenLiteralIntegerValueMatchesChoiceValue', () async {
    final scenario = await Scenario.init(
      _form('Integer calculate', 'integer-calculate', 'if(1=2, 1, 0)'),
    );

    scenario.choicesOf('/data/select'); // Populate choices
    expect(
      scenario.answerOf('/data/select')!.value,
      Selection.ofChoice(scenario.choicesOf('/data/select')[0]),
    );
    expect(scenario.answerOf('/data/select'), isA<SelectOneValue>());
  });

  test(
    'choiceIsSelectedWhenLiteralIntegerValueMatchesChoiceValue_afterDeserialization',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test('selectQuestionValueBlankWhenValueNotInChoices', () async {
    final scenario = await Scenario.init(
      _form('String calculate', 'string-calculate', "if(1=2, '1', '7')"),
    );

    scenario.choicesOf('/data/select'); // Populate choices
    expect(scenario.answerOf('/data/select'), isNull);
  });
}
