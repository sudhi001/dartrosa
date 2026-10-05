// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (SelectCachingTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 SelectCachingTest.
import 'package:dartrosa/src/util/measure.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const _events = ['PredicateEvaluation', 'IndexEvaluation'];

/// A form with `/data/choice`, optionally `/data/other_choice`, and dynamic
/// selects named by [selects] (name → itemset nodeset) over
/// `instance('instance')` holding [items].
XFormsElement _form(
  List<XFormsElement> items,
  Map<String, String> selects, {
  bool otherChoice = false,
  String choiceType = 'string',
}) => html(
  head([
    title('Some form'),
    model([
      mainInstance([
        t('data id="some-form"', [
          t('choice'),
          if (otherChoice) t('other_choice'),
          for (final name in selects.keys) t(name),
        ]),
      ]),
      instance('instance', items),
      bind('/data/choice')..type(choiceType),
      if (otherChoice) bind('/data/other_choice')..type('string'),
      for (final name in selects.keys) bind('/data/$name')..type('string'),
    ]),
  ]),
  body([
    input('/data/choice'),
    if (otherChoice) input('/data/other_choice'),
    for (final MapEntry(:key, :value) in selects.entries)
      select1Dynamic('/data/$key', value),
  ]),
);

void main() {
  test(
    'eqChoiceFiltersAreOnlyEvaluatedOnceForRepeatedChoiceListEvaluations',
    () async {
      final scenario = await Scenario.init(
        _form(
          [item('a', 'A'), item('b', 'B')],
          {'select': "instance('instance')/root/item[value=/data/choice]"},
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', 'a')
          ..choicesOf('/data/select')
          ..choicesOf('/data/select');
      });

      // Check that we do just (size of secondary instance)
      expect(evaluations, 2);
    },
  );

  test(
    'andOfTwoEqChoiceFiltersAreOnlyEvaluatedOnceForRepeatedChoiceListEvaluations',
    () async {
      final scenario = await Scenario.init(
        _form(
          [item('a', 'A'), item('b', 'B')],
          {
            'select':
                "instance('instance')/root/item"
                '[value=/data/choice and value=/data/choice]',
          },
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', 'a')
          ..choicesOf('/data/select')
          ..choicesOf('/data/select');
      });

      // Check that we do just (size of secondary instance)
      expect(evaluations, 2);
    },
  );

  test('andOfTwoEqChoiceFiltersIsNotConfusedWithOr', () async {
    final scenario = await Scenario.init(
      _form(
        [item('a', 'A'), item('b', 'B')],
        {
          'select1':
              "instance('instance')/root/item"
              '[value=/data/choice or value!=/data/choice]',
          'select2':
              "instance('instance')/root/item"
              '[value=/data/choice and value!=/data/choice]',
        },
      ),
    );

    scenario.answer('/data/choice', 'a');
    expect(scenario.choicesOf('/data/select1'), hasLength(2));
    expect(scenario.choicesOf('/data/select2'), hasLength(0));
  });

  test(
    'repeatedEqChoiceFiltersAreOnlyEvaluatedOnce_whileLiteralExpressionIsTheSame',
    () async {
      final scenario = await Scenario.init(
        _form(
          [item('a', 'A'), item('b', 'B')],
          {
            'select1': "instance('instance')/root/item[value=/data/choice]",
            'select2': "instance('instance')/root/item[value=/data/choice]",
          },
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', 'a')
          ..choicesOf('/data/select1')
          ..choicesOf('/data/select2');
      });

      // Check that we do just (size of secondary instance)
      expect(evaluations, 2);
    },
  );

  test(
    'repeatedCompChoiceFiltersAreOnlyEvaluatedOnce_whileLiteralExpressionIsTheSame',
    () async {
      final scenario = await Scenario.init(
        _form(
          [item('1', 'A'), item('2', 'B')],
          {
            'select1': "instance('instance')/root/item[value</data/choice]",
            'select2': "instance('instance')/root/item[value</data/choice]",
          },
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', '3')
          ..choicesOf('/data/select1')
          ..choicesOf('/data/select2');
      });

      // Check that we do just (size of secondary instance)
      expect(evaluations, 2);
    },
  );

  test('repeatedEqChoiceFiltersAreOnlyEvaluatedOnce', () async {
    final scenario = await Scenario.init(
      _form(
        [item('a', 'A'), item('b', 'B')],
        {
          'select1': "instance('instance')/root/item[value=/data/choice]",
          'select2': "instance('instance')/root/item[value=/data/choice]",
        },
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario
        ..answer('/data/choice', 'a')
        ..choicesOf('/data/select1')
        ..answer('/data/choice', 'b')
        ..choicesOf('/data/select2');
    });

    // Check that we do just (size of secondary instance)
    expect(evaluations, 2);
  });

  test(
    'nestedPredicatesAreOnlyEvaluatedOnceForAQuestionWhileTheFormStateIsStable',
    () async {
      final scenario = await Scenario.init(
        _form(
          [item('a', 'A'), item('b', 'B')],
          {
            'select':
                "instance('instance')/root/item"
                '[value=/data/choice][value=/data/other_choice]',
          },
          otherChoice: true,
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', 'a')
          ..answer('/data/other_choice', 'a')
          ..choicesOf('/data/select')
          ..choicesOf('/data/select');
      });

      // Check that we do less than (secondary instance size) * (number of
      // lookups) - the number could fluctuate depending on how the nested
      // predicates are individually cached/indexed.
      expect(evaluations, lessThan(4));
    },
  );

  test('nestedPredicatesAreCorrectAfterFormStateChanges', () async {
    final scenario = await Scenario.init(
      _form(
        [item('a', 'A'), item('b', 'B')],
        {
          'select':
              "instance('instance')/root/item"
              '[value=/data/choice][value=/data/other_choice]',
        },
        otherChoice: true,
      ),
    );

    scenario
      ..answer('/data/choice', 'a')
      ..answer('/data/other_choice', 'a');
    expect(scenario.choicesOf('/data/select'), hasLength(1));

    scenario.answer('/data/other_choice', 'b');
    expect(scenario.choicesOf('/data/select'), hasLength(0));
  });

  // region repeats
  test('eqChoiceFilter_inRepeat_onlyEvaluatedOnce', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Select in repeat'),
          model([
            mainInstance([
              t("data id='repeat-select'", [
                t('filter'),
                t('repeat', [t('select')]),
              ]),
            ]),
            instance('choices', [
              item('a', 'A'),
              item('aa', 'AA'),
              item('b', 'B'),
              item('bb', 'BB'),
            ]),
          ]),
        ]),
        body([
          input('filter'),
          repeat('/data/repeat', [
            select1Dynamic(
              '/data/repeat/select',
              "instance('choices')/root/item[value=/data/filter]",
            ),
          ]),
        ]),
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario
        ..answer('/data/filter', 'a')
        ..choicesOf('/data/repeat[1]/select')
        ..createNewRepeat('/data/repeat')
        ..choicesOf('/data/repeat[2]/select');
    });

    // Check that we do just (size of secondary instance)
    expect(evaluations, 4);
  });

  test(
    'eqChoiceFiltersInRepeatsWithCurrentPathExpressionsAreOnlyEvaluatedOnce',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Select in repeat'),
            model([
              mainInstance([
                t("data id='repeat-select'", [
                  t('outer', [
                    t('filter'),
                    t('inner', [t('select')]),
                  ]),
                ]),
              ]),
              instance('choices', [item('a', 'A'), item('b', 'B')]),
            ]),
          ]),
          body([
            repeat('/data/outer', [
              input('filter'),
              repeat('/data/outer/inner', [
                select1Dynamic(
                  '/data/outer/inner/select',
                  "instance('choices')/root/item"
                      '[value=current()/../../filter]',
                ),
              ]),
            ]),
          ]),
        ),
      );

      scenario
        ..answer('/data/outer[1]/filter', 'a')
        ..createNewRepeat('/data/outer[1]/inner')
        ..answer('/data/outer[2]/filter', 'a')
        ..createNewRepeat('/data/outer[2]/inner')
        ..createNewRepeat('/data/outer[2]/inner');

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..choicesOf('/data/outer[1]/inner[1]/select')
          ..choicesOf('/data/outer[1]/inner[2]/select');
      });

      // Check that we do just (size of secondary instance)
      expect(evaluations, 2);
    },
  );
  // endregion

  test('eqChoiceFiltersForIntsWork', () async {
    final scenario = await Scenario.init(
      _form(
        [item('1', 'One'), item('2', 'Two')],
        {'select': "instance('instance')/root/item[value=/data/choice]"},
        choiceType: 'int',
      ),
    );

    scenario.answer('/data/choice', 1);
    expect(scenario.choicesOf('/data/select'), hasLength(1));
  });
}
