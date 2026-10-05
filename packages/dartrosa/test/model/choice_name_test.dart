// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ChoiceNameTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ChoiceNameTest.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void main() {
  test('choiceNameCallOnLiteralChoiceValue_getsChoiceName', () async {
    final scenario = await scenarioFor('jr-choice-name.xml');
    expect(
      scenario.answerOf('/jr-choice-name/literal_choice_name'),
      stringAnswer('Choice 2'),
    );
  });

  test(
    'choiceNameCallOutsideOfRepeatWithStaticChoices_getsChoiceName',
    () async {
      final scenario = await scenarioFor('jr-choice-name.xml');
      scenario.answer('/jr-choice-name/select_one_outside', 'choice3');
      expect(
        scenario.answerOf('/jr-choice-name/select_one_name_outside'),
        stringAnswer('Choice 3'),
      );
    },
  );

  test('choiceNameCallInRepeatWithStaticChoices_getsChoiceName', () async {
    final scenario = await scenarioFor('jr-choice-name.xml');
    scenario
      ..answer('/jr-choice-name/my-repeat[1]/select_one', 'choice4')
      ..answer('/jr-choice-name/my-repeat[2]/select_one', 'choice1')
      ..answer('/jr-choice-name/my-repeat[3]/select_one', 'choice5');

    expect(
      scenario.answerOf('/jr-choice-name/my-repeat[1]/select_one_name'),
      stringAnswer('Choice 4'),
    );
    expect(
      scenario.answerOf('/jr-choice-name/my-repeat[2]/select_one_name'),
      stringAnswer('Choice 1'),
    );
    expect(
      scenario.answerOf('/jr-choice-name/my-repeat[3]/select_one_name'),
      stringAnswer('Choice 5'),
    );
  });

  test('choiceNameCall_respectsLanguage', () async {
    final scenario = await scenarioFor('jr-choice-name.xml');
    scenario
      ..language = 'French (fr)'
      ..answer('/jr-choice-name/select_one_outside', 'choice3');
    expect(
      scenario.answerOf('/jr-choice-name/select_one_name_outside'),
      stringAnswer('Choix 3'),
    );
    scenario.answer('/jr-choice-name/my-repeat[1]/select_one', 'choice4');
    expect(
      scenario.answerOf('/jr-choice-name/my-repeat[1]/select_one_name'),
      stringAnswer('Choix 4'),
    );

    scenario
      ..language = 'English (en)'
      // TODO: why does test fail if value is not set to choice3 again? Does
      // changing language not trigger recomputation?
      ..answer('/jr-choice-name/select_one_outside', 'choice3');
    expect(
      scenario.answerOf('/jr-choice-name/select_one_name_outside'),
      stringAnswer('Choice 3'),
    );

    // TODO: why does test fail if value is not set to choice4 again? Does
    // changing language not trigger recomputation?
    scenario.answer('/jr-choice-name/my-repeat[1]/select_one', 'choice4');
    expect(
      scenario.answerOf('/jr-choice-name/my-repeat[1]/select_one_name'),
      stringAnswer('Choice 4'),
    );
  });

  // The choice list for question cocotero with dynamic itemset is populated
  // on DAG initialization time triggered by the jr:choice-name expression in
  // the calculate.
  test('choiceNameCallWithDynamicChoicesAndNoPredicate_selectsName', () async {
    final scenario = await scenarioFor('jr-choice-name.xml');
    scenario
      ..answer('/jr-choice-name/cocotero_a', 'a')
      ..answer('/jr-choice-name/cocotero_b', 'b');
    expect(
      scenario.answerOf('/jr-choice-name/cocotero_name'),
      stringAnswer('Cocotero a-b'),
    );
  });

  // The choice list for question city with dynamic itemset is populated at
  // DAG initialization time. Since country hasn't been set yet, the choice
  // list is empty. Setting the country does not automatically trigger
  // re-computation of the choice list for the city question. Instead,
  // clients trigger a recomputation of the list when the list is displayed.
  test(
    'choiceNameCallWithDynamicChoicesAndPredicate_requiresExplicitDynamicChoicesRecomputation',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Dynamic Choices and Predicates'),
            model([
              mainInstance([
                t('data id="dynamic-choices-predicates"', [
                  t('country'),
                  t('city'),
                  t('city_name'),
                ]),
              ]),
              t('itext', [
                t('translation lang="default"', [
                  t('text id="static_instance-countries-0"', [
                    tText('value', 'Canada'),
                  ]),
                  t('text id="static_instance-countries-1"', [
                    tText('value', 'France'),
                  ]),
                  t('text id="static_instance-cities-0"', [
                    tText('value', 'Montréal'),
                  ]),
                  t('text id="static_instance-cities-1"', [
                    tText('value', 'Grenoble'),
                  ]),
                ]),
              ]),
              t('instance id="cities"', [
                t('root', [
                  t('item', [
                    tText('itextId', 'static_instance-cities-0'),
                    tText('name', 'montreal'),
                    tText('country', 'canada'),
                  ]),
                  t('item', [
                    tText('itextId', 'static_instance-cities-1'),
                    tText('name', 'grenoble'),
                    tText('country', 'france'),
                  ]),
                ]),
              ]),
              bind('/data/country')..type('string'),
              bind('/data/city')..type('string'),
              bind('/data/city_name')
                ..type('string')
                ..calculate("jr:choice-name(/data/city,'/data/city')"),
            ]),
          ]),
          body([
            select1('/data/country', [
              item('canada', 'Canada'),
              item('france', 'France'),
            ]),
            t('select1 ref="/data/city"', [
              t(
                'itemset nodeset="instance(\'cities\')/root/item[selected(country,/data/country)]"',
                [t('value ref="name"'), t('label ref="jr:itext(itextId)"')],
              ),
            ]),
          ]),
        ),
      );

      scenario.answer('/data/country', 'france');

      // Trigger recomputation of the city choice list
      expect(scenario.choicesOf('/data/city')[0].value, 'grenoble');

      scenario.answer('/data/city', 'grenoble');
      expect(scenario.answerOf('/data/city_name'), stringAnswer('Grenoble'));
    },
  );

  test(
    'choiceNameCallWithIndexedRepeatAndStaticChoices_worksWithMultipleRepeats',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Static choices in repeat'),
            model([
              mainInstance([
                t('data id="static-choices-repeat"', [
                  t('thing', [t('choice')]),
                  t('choice1_label'),
                ]),
              ]),
              bind('/data/thing/choice')..type('string'),
              bind('/data/choice1_label')
                ..type('string')
                ..calculate(
                  'jr:choice-name(indexed-repeat(/data/thing/choice, '
                  "/data/thing, 1),'/data/thing/choice')",
                ),
            ]),
          ]),
          body([
            repeat('/data/thing', [
              select1('/data/thing/choice', [
                item('choice1', 'Choice1'),
                item('choice2', 'Choice2'),
              ]),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..next()
        ..next()
        ..createNewRepeatHere()
        ..answer('/data/thing[1]/choice', 'choice1');
      expect(scenario.answerOf('/data/choice1_label'), stringAnswer('Choice1'));

      scenario.answer('/data/thing[2]/choice', 'choice2');
      expect(scenario.answerOf('/data/choice1_label'), stringAnswer('Choice1'));
    },
  );

  test(
    'choiceNameCallWithIndexedRepeatAndDynamicChoices_worksWithMultipleRepeats',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Dynamic choices in repeat'),
            model([
              mainInstance([
                t('data id="dynamic-choices-repeat"', [
                  t('thing', [t('choice')]),
                  t('choice1_label'),
                ]),
              ]),
              t('instance id="choices"', [
                t('root', [
                  item('choice1', 'Choice1'),
                  item('choice2', 'Choice2'),
                ]),
              ]),
              bind('/data/thing/choice')..type('string'),
              bind('/data/choice1_label')
                ..type('string')
                ..calculate(
                  'jr:choice-name(indexed-repeat(/data/thing/choice, '
                  "/data/thing, 1),'/data/thing/choice')",
                ),
            ]),
          ]),
          body([
            repeat('/data/thing', [
              select1Dynamic(
                '/data/thing/choice',
                "instance('choices')/root/item",
              ),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..next()
        ..next()
        ..createNewRepeatHere()
        ..answer('/data/thing[1]/choice', 'choice1');
      expect(scenario.answerOf('/data/choice1_label'), stringAnswer('Choice1'));

      scenario.answer('/data/thing[2]/choice', 'choice2');
      expect(scenario.answerOf('/data/choice1_label'), stringAnswer('Choice1'));
    },
  );
}
