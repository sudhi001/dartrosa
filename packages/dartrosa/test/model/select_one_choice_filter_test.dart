// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (SelectOneChoiceFilterTest), Copyright 2019 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 SelectOneChoiceFilterTest.
//
// When itemsets are dynamically generated, the choices available to a user
// in a select one question can change based on the answers given to other
// questions. These tests verify that when several select ones are chained
// in a cascading pattern, updating selections at root levels correctly
// updates the choices available in dependent selects all the way down the
// cascade. They also verify that if an answer that is no longer part of
// the available choices was previously selected, that answer is cleared.
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void main() {
  late Scenario scenario;

  setUp(() async {
    scenario = await scenarioFor('three-level-cascading-select.xml');
  });

  test('dependentLevelsInBlankInstance_ShouldHaveNoChoices', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);
  });

  test('selectingValueAtLevel1_ShouldFilterChoicesAtLevel2', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);

    scenario.answer('/data/level1', 'b');

    expect(
      scenario.choicesOf('/data/level2'),
      unorderedMatches([choice('ba'), choice('bb'), choice('bc')]),
    );
  });

  test('selectingValuesAtLevels1And2_ShouldFilterChoicesAtLevel3', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);

    scenario
      ..answer('/data/level1', 'b')
      ..answer('/data/level2', 'ba');
    expect(
      scenario.choicesOf('/data/level3'),
      unorderedMatches([choice('baa'), choice('bab')]),
    );
  });

  test('clearingValueAtLevel2_ShouldClearChoicesAtLevel3', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);

    scenario
      ..answer('/data/level1', 'a')
      ..answer('/data/level2', 'aa');
    expect(
      scenario.choicesOf('/data/level3'),
      unorderedMatches([choice('aaa'), choice('aab')]),
    );
    scenario.answer('/data/level2', '');
    expect(scenario.choicesOf('/data/level3'), isEmpty);
  });

  test('clearingValueAtLevel1_ShouldClearChoicesAtLevels2And3', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);

    scenario
      ..answer('/data/level1', 'a')
      ..answer('/data/level2', 'aa');
    expect(
      scenario.choicesOf('/data/level3'),
      unorderedMatches([choice('aaa'), choice('aab')]),
    );

    scenario.answer('/data/level1', '');
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    // this next assertion is only true because the one before called
    // populateDynamicChoices
    expect(scenario.answerOf('/data/level2'), isNull);
    expect(scenario.choicesOf('/data/level3'), isEmpty);
  });

  test('clearingValueAtLevel1_ShouldClearValuesAtLevels2And3', () {
    scenario.newInstance();
    expect(scenario.answerOf('/data/level2'), isNull);
    expect(scenario.answerOf('/data/level3'), isNull);

    scenario
      ..answer('/data/level1', 'a')
      ..answer('/data/level2', 'aa')
      ..answer('/data/level3', 'aab')
      ..answer('/data/level1', '');

    var validate = scenario.validationOutcome!;
    expect(validate.failedPrompt, scenario.indexOf('/data/level2'));
    expect(validate.outcome, AnswerStatus.requiredButEmpty);

    // If we set level2 to "aa", form validation passes. Currently, clearing a
    // choice only updates filter expressions that directly depend on it.
    scenario
      ..answer('/data/level1', 'b')
      ..answer('/data/level2', 'bb');

    validate = scenario.validationOutcome!;
    expect(validate.failedPrompt, scenario.indexOf('/data/level3'));
    expect(validate.outcome, AnswerStatus.requiredButEmpty);
  });

  test('changingValueAtLevel2_ShouldClearLevel3_IfChoiceNoLongerAvailable', () {
    scenario
      ..newInstance()
      ..answer('/data/level1_contains', 'a')
      ..answer('/data/level2_contains', 'aa');
    expect(
      scenario.choicesOf('/data/level3_contains'),
      unorderedMatches([choice('aaa'), choice('aab'), choice('baa')]),
    );
    scenario
      ..answer('/data/level3_contains', 'aaa')
      ..answer('/data/level2_contains', 'ab');
    expect(
      scenario.choicesOf('/data/level3_contains'),
      unorderedMatches([choice('aab'), choice('bab')]),
    );
    // this next assertion is only true because the one before called
    // populateDynamicChoices
    expect(scenario.answerOf('/data/level3_contains'), isNull);
  });

  test('changingValueAtLevel2_ShouldNotClearLevel3_IfChoiceStillAvailable', () {
    scenario
      ..newInstance()
      ..answer('/data/level1_contains', 'a')
      ..answer('/data/level2_contains', 'aa');
    expect(
      scenario.choicesOf('/data/level3_contains'),
      unorderedMatches([choice('aaa'), choice('aab'), choice('baa')]),
    );
    scenario
      ..answer('/data/level3_contains', 'aab')
      ..answer('/data/level2_contains', 'ab');
    expect(scenario.answerOf('/data/level3_contains')!.displayText, 'aab');

    // Since recomputing the choice list can change answers, verify it
    // doesn't in this case
    expect(
      scenario.choicesOf('/data/level3_contains'),
      unorderedMatches([choice('aab'), choice('bab')]),
    );
    expect(scenario.answerOf('/data/level3_contains')!.displayText, 'aab');
  });
}
