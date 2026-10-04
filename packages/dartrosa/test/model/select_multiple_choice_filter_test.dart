@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 SelectMultipleChoiceFilterTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void main() {
  late Scenario scenario;

  setUp(() async {
    scenario = await scenarioFor('three-level-cascading-multi-select.xml');
  });

  test('dependentLevelsInBlankInstance_haveNoChoices', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);
  });

  test('selectingValueAtLevel1_filtersChoicesAtLevel2', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);

    scenario.answer('/data/level1', ['a', 'b']);

    expect(
      scenario.choicesOf('/data/level2'),
      unorderedMatches([
        choice('aa'),
        choice('ab'),
        choice('ac'),
        choice('ba'),
        choice('bb'),
        choice('bc'),
      ]),
    );
  });

  test('selectingValuesAtLevels1And2_filtersChoicesAtLevel3', () {
    scenario.newInstance();
    expect(scenario.choicesOf('/data/level2'), isEmpty);
    expect(scenario.choicesOf('/data/level3'), isEmpty);

    scenario
      ..answer('/data/level1', ['a', 'b'])
      ..answer('/data/level2', ['aa', 'ba']);
    expect(
      scenario.choicesOf('/data/level3'),
      unorderedMatches([
        choice('aaa'),
        choice('aab'),
        choice('baa'),
        choice('bab'),
      ]),
    );
  });

  test(
    'newChoiceFilterEvaluation_removesIrrelevantAnswersAtAllLevels_withoutChangingOrder',
    () {
      scenario.newInstance();
      expect(scenario.choicesOf('/data/level2'), isEmpty);
      expect(scenario.choicesOf('/data/level3'), isEmpty);

      scenario
        ..answer('/data/level1', ['a', 'b', 'c'])
        ..answer('/data/level2', ['aa', 'ba', 'ca'])
        ..answer('/data/level3', ['aab', 'baa', 'aaa'])
        // Remove b from the level1 answer; this should filter out b-related
        // answers and choices at levels 2 and 3
        ..answer('/data/level1', ['a', 'c'])
        // Force populateDynamicChoices to run again which is what filters
        // out irrelevant answers
        ..choicesOf('/data/level2');

      expect(scenario.answerOf('/data/level2'), answerText('aa, ca'));

      // This also runs populateDynamicChoices and filters out irrelevant
      // answers
      expect(
        scenario.choicesOf('/data/level3'),
        unorderedMatches([
          choice('aaa'),
          choice('aab'),
          choice('caa'),
          choice('cab'),
        ]),
      );

      expect(scenario.answerOf('/data/level3'), answerText('aab, aaa'));
    },
  );

  test(
    'newChoiceFilterEvaluation_leavesAnswerUnchangedIfAllSelectionsStillInChoices',
    () {
      scenario.newInstance();
      expect(scenario.choicesOf('/data/level2'), isEmpty);
      expect(scenario.choicesOf('/data/level3'), isEmpty);

      scenario
        ..answer('/data/level1', ['a', 'b', 'c'])
        ..answer('/data/level2', ['aa', 'ba', 'bb', 'ab'])
        ..answer('/data/level3', ['aab', 'baa', 'aaa'])
        // Remove c from the level1 answer; this should have no effect on
        // levels 2 and 3
        ..answer('/data/level1', ['a', 'b'])
        // Force populateDynamicChoices to run again which is what filters
        // out irrelevant answers
        ..choicesOf('/data/level2');

      expect(scenario.answerOf('/data/level2'), answerText('aa, ba, bb, ab'));

      // This also runs populateDynamicChoices and filters out irrelevant
      // answers
      expect(
        scenario.choicesOf('/data/level3'),
        unorderedMatches([
          choice('aaa'),
          choice('aab'),
          choice('baa'),
          choice('bab'),
        ]),
      );

      expect(scenario.answerOf('/data/level3'), answerText('aab, baa, aaa'));
    },
  );
}
