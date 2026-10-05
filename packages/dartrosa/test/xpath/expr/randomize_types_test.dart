// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (RandomizeTypesTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 RandomizeTypesTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

XFormsElement choicesInstance([int count = 8]) => instance('choices', [
  for (final v in 'abcdefgh'.split('').take(count)) item(v, v.toUpperCase()),
]);

/// The values of the choices of the select at [ref], in display order.
List<String> choiceValues(Scenario scenario, String ref) => [
  for (final choice in scenario.choicesOf(ref)) choice.value,
];

void main() {
  test('stringNumberSeedConvertsWhenUsedInNodesetExpression', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Randomize non-numeric seed'),
          model([
            mainInstance([
              t('data id="rand-non-numeric"', [
                t('choices_numeric_seed'),
                t('choices_stringified_numeric_seed'),
              ]),
            ]),
            choicesInstance(),
            bind('/data/choices_numeric_seed')..type('string'),
            bind('/data/choices_stringified_numeric_seed')..type('string'),
          ]),
        ]),
        body([
          select1Dynamic(
            '/data/choices_numeric_seed',
            "randomize(instance('choices')/root/item, 1234)",
          ),
          select1Dynamic(
            '/data/choices_stringified_numeric_seed',
            "randomize(instance('choices')/root/item, '1234')",
          ),
        ]),
      ),
    );
    const shuffled = ['g', 'f', 'e', 'd', 'a', 'h', 'b', 'c'];
    const nodes = [
      '/data/choices_numeric_seed',
      '/data/choices_stringified_numeric_seed',
    ];
    for (final node in nodes) {
      expect(choiceValues(scenario, node), shuffled);
    }
  });

  test('stringNumberSeedConvertsWhenUsedInCalculate', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Randomize non-numeric seed'),
          model([
            mainInstance([
              t('data id="rand-non-numeric"', [
                t('choices_numeric_seed'),
                t('choices_stringified_numeric_seed'),
              ]),
            ]),
            choicesInstance(),
            bind('/data/choices_numeric_seed')
              ..type('string')
              ..calculate(
                "join('', randomize(instance('choices')/root/item/label, "
                '1234))',
              ),
            bind('/data/choices_stringified_numeric_seed')
              ..type('string')
              ..calculate(
                "join('', randomize(instance('choices')/root/item/label, "
                "'1234'))",
              ),
          ]),
        ]),
        body([
          input('/data/choices_numeric_seed'),
          input('/data/choices_stringified_numeric_seed'),
        ]),
      ),
    );
    expect(
      scenario.answerOf('/data/choices_numeric_seed')!.displayText,
      scenario.answerOf('/data/choices_stringified_numeric_seed')!.displayText,
    );
    expect(
      scenario.answerOf('/data/choices_numeric_seed')!.displayText,
      'GFEDAHBC',
    );
  });

  test('stringTextSeedConvertsWhenUsedInNodesetExpression', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Randomize non-numeric seed'),
          model([
            mainInstance([
              t('data id="rand-non-numeric"', [t('choice')]),
            ]),
            choicesInstance(),
            bind('/data/choice')..type('string'),
          ]),
        ]),
        body([
          select1Dynamic(
            '/data/choice',
            "randomize(instance('choices')/root/item, 'foo')",
          ),
        ]),
      ),
    );
    const shuffled = ['e', 'a', 'd', 'b', 'h', 'g', 'c', 'f'];
    expect(choiceValues(scenario, '/data/choice'), shuffled);
  });

  test('stringTextSeedConvertsWhenUsedInCalculate', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Randomize non-numeric seed'),
          model([
            mainInstance([
              t('data id="rand-non-numeric"', [t('choice')]),
            ]),
            choicesInstance(),
            bind('/data/choice')
              ..type('string')
              ..calculate(
                "join('', randomize(instance('choices')/root/item/label, "
                "'foo'))",
              ),
          ]),
        ]),
        body([input('/data/choice')]),
      ),
    );

    expect(scenario.answerOf('/data/choice')!.displayText, 'EADBHGCF');
  });

  test('seedInRepeatIsEvaluatedForEachInstance', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Randomize non-numeric seed'),
                model([
                  mainInstance([
                    t('data id="rand-non-numeric"', [
                      t('repeat', [t('input'), t('choice')]),
                    ]),
                  ]),
                  choicesInstance(2),
                  bind('/data/input')..type('string'),
                  bind('/data/choice')..type('string'),
                ]),
              ]),
              body([
                repeat('/data/repeat', [
                  input('/data/repeat/input'),
                  select1Dynamic(
                    '/data/repeat/choice',
                    "randomize(instance('choices')/root/item, 1 * ../input)",
                  ),
                ]),
              ]),
            ),
          )
          ..answer('/data/repeat[1]/input', 0);
    expect(scenario.choicesOf('/data/repeat[1]/choice')[0].value, 'a');

    scenario
      ..createNewRepeat('/data/repeat')
      ..answer('/data/repeat[2]/input', 1);
    expect(scenario.choicesOf('/data/repeat[2]/choice')[0].value, 'b');
    expect(scenario.choicesOf('/data/repeat[1]/choice')[0].value, 'a');
  });

  test('seedFromArbitraryInputCanBeUsed', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Randomize non-numeric seed'),
                model([
                  mainInstance([
                    t('data id="rand-non-numeric"', [t('input'), t('choice')]),
                  ]),
                  choicesInstance(),
                  bind('/data/input')..type('geopoint'),
                  bind('/data/choice')..type('string'),
                ]),
              ]),
              body([
                input('/data/input'),
                select1Dynamic(
                  '/data/choice',
                  "randomize(instance('choices')/root/item, /data/input)",
                ),
              ]),
            ),
          )
          ..answer('/data/input', '-6.8137120026589315 39.29392995851879');
    const shuffled = ['h', 'b', 'd', 'f', 'a', 'g', 'c', 'e'];
    expect(choiceValues(scenario, '/data/choice'), shuffled);
  });

  test('seed0FromNaNs', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Randomize non-numeric seed'),
                model([
                  mainInstance([
                    t('data id="rand-non-numeric"', [
                      t('input_emptystring'),
                      t('input_somestring'),
                      t('input_int'),
                      t('choice_emptystring'),
                      t('choice_somestring'),
                      t('choice_int'),
                    ]),
                  ]),
                  choicesInstance(),
                  bind('/data/input_emptystring')..type('string'),
                  bind('/data/input_somestring')..type('string'),
                  bind('/data/input_int')..type('int'),
                ]),
              ]),
              body([
                input('/data/input_emptystring'),
                input('/data/input_somestring'),
                input('/data/input_int'),
                select1Dynamic(
                  '/data/choice_emptystring',
                  "randomize(instance('choices')/root/item, "
                      '/data/input_emptystring)',
                ),
                select1Dynamic(
                  '/data/choice_somestring',
                  "randomize(instance('choices')/root/item, "
                      '/data/input_somestring)',
                ),
                select1Dynamic(
                  '/data/choice_int',
                  "randomize(instance('choices')/root/item, /data/input_int)",
                ),
              ]),
            ),
          )
          ..answer('/data/input_emptystring', '')
          ..answer('/data/input_somestring', 'somestring')
          ..answer('/data/input_int', '0');

    const shuffledNaNOr0 = ['c', 'b', 'h', 'a', 'f', 'd', 'g', 'e'];
    const shuffledSomestring = ['e', 'b', 'c', 'g', 'd', 'a', 'f', 'h'];
    expect(
      shuffledNaNOr0,
      isNot(shuffledSomestring),
      reason:
          'somestring-seeded expected order is distinct from 0-seeded '
          'expected order',
    );
    const shuffledFields = ['/data/choice_emptystring', '/data/choice_int'];
    for (final shuffledField in shuffledFields) {
      expect(choiceValues(scenario, shuffledField), shuffledNaNOr0);
    }
    expect(
      choiceValues(scenario, '/data/choice_somestring'),
      shuffledSomestring,
    );
  });
}
