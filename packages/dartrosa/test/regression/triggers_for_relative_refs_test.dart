// Port of JavaRosa v6.0.0 TriggersForRelativeRefsTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

/// The nested indefinite-repeat form; [innerCount] and [targetCount] are the
/// calculates of `inner_count` and `target_count`.
XFormsElement nestedIndefiniteRepeatForm(
  String innerCount,
  String targetCount,
) => html(
  head([
    title('Indefinite repeat in nested repeat'),
    model([
      mainInstance([
        t('data id="indefinite-nested-repeat"', [
          t('outer_repeat', [
            t('inner_count'),
            t('target_count'),
            t('inner_repeat', [t('add_more')]),
          ]),
        ]),
      ]),
      bind('/data/outer_repeat/inner_count')
        ..type('int')
        ..calculate(innerCount),
      bind('/data/outer_repeat/target_count')
        ..type('int')
        ..calculate(targetCount),
    ]),
  ]),
  body([
    repeat('/data/outer_repeat', [
      repeat('/data/outer_repeat/inner_repeat', [
        input('/data/outer_repeat/inner_repeat/add_more'),
      ], 'target_count'),
    ]),
  ]),
);

void answerNestedIndefiniteRepeats(Scenario scenario) {
  scenario
    ..next()
    ..next()
    ..next()
    ..answerCurrent('yes')
    ..next()
    ..next()
    ..answerCurrent('yes')
    ..next()
    ..next()
    ..answerCurrent('no')
    ..next()
    ..createNewRepeatHere()
    ..next()
    ..next()
    ..answerCurrent('yes')
    ..next()
    ..next()
    ..answerCurrent('no')
    ..next()
    ..next();
}

void main() {
  test(
    'indefiniteRepeatJrCountExpression_inSingleRepeat_addsRepeatsUntilConditionMet',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Indefinite repeat'),
            model([
              mainInstance([
                t('data id="indefinite-repeat"', [
                  t('count'),
                  t('target_count'),
                  t('repeat', [t('add_more')]),
                ]),
              ]),
              bind('/data/count')
                ..type('int')
                ..calculate('count(/data/repeat)'),
              bind('/data/target_count')
                ..type('int')
                ..calculate(
                  'if(/data/count = 0 or '
                  "/data/repeat[position()=/data/count]/add_more = 'yes', "
                  '/data/count + 1, /data/count)',
                ),
              bind('/data/repeat/add_more')..type('string'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [
              input('/data/repeat/add_more'),
            ], '/data/target_count'),
          ]),
        ),
      );

      scenario
        ..next()
        ..next()
        ..answerCurrent('yes')
        ..next()
        ..next()
        ..answerCurrent('yes')
        ..next()
        ..next()
        ..answerCurrent('no')
        ..next();
      expect(scenario.atTheEndOfForm, isTrue);
    },
  );

  test(
    'indefiniteRepeatJrCountExpression_inNestedRepeat_addsRepeatsUntilConditionMet',
    () async {
      final scenario = await Scenario.init(
        nestedIndefiniteRepeatForm(
          'count(/data/outer_repeat/inner_repeat)',
          // The missing space before "or" is as in JavaRosa.
          'if(/data/outer_repeat/inner_count = 0'
              'or /data/outer_repeat/inner_repeat[position() = '
              "/data/outer_repeat/inner_count]/add_more = 'yes', "
              '/data/outer_repeat/inner_count + 1, '
              '/data/outer_repeat/inner_count)',
        ),
      );

      answerNestedIndefiniteRepeats(scenario);
      expect(scenario.atTheEndOfForm, isTrue);
    },
  );

  test(
    'indefiniteRepeatJrCountExpression_inNestedRepeat_withRelativePaths_addsRepeatsUntilConditionMet',
    () async {
      final scenario = await Scenario.init(
        nestedIndefiniteRepeatForm(
          'count(../inner_repeat)',
          // The missing space before "or" is as in JavaRosa.
          'if(../inner_count = 0'
              "or ../inner_repeat[position() = ../inner_count]/add_more = 'yes', "
              '../inner_count + 1, ../inner_count)',
        ),
      );

      answerNestedIndefiniteRepeats(scenario);
      expect(scenario.atTheEndOfForm, isTrue);
    },
  );

  test(
    'predicateWithRelativePathExpression_reevaluated_whenTriggerChanges',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Predicate trigger'),
            model([
              mainInstance([
                t('data id="predicate-trigger"', [
                  t('outer_repeat', [
                    t('cutoff_number'),
                    for (var n = 1; n <= 6; n++)
                      t('inner_repeat', [tText('number', '$n')]),
                    t('sum'),
                  ]),
                ]),
              ]),
              bind('/data/outer_repeat/cutoff_number')..type('int'),
              bind('/data/outer_repeat/inner_repeat/number')..type('int'),
              bind('/data/outer_repeat/sum')
                ..type('int')
                ..calculate(
                  'sum(../inner_repeat[number > ../cutoff_number]/number)',
                ),
            ]),
          ]),
          body([
            repeat('/data/outer_repeat', [
              input('/data/outer_repeat/cutoff_number'),
              repeat('/data/outer_repeat/inner_repeat', [
                input('/data/outer_repeat/inner_repeat/number'),
              ]),
            ]),
          ]),
        ),
      );

      scenario.answer('/data/outer_repeat/cutoff_number', 3);
      expect(scenario.answerOf('/data/outer_repeat/sum'), intAnswer(15));

      scenario.answer('/data/outer_repeat/cutoff_number', 7);
      expect(scenario.answerOf('/data/outer_repeat/sum'), intAnswer(0));

      scenario.answer('/data/outer_repeat/cutoff_number', -11);
      expect(scenario.answerOf('/data/outer_repeat/sum'), intAnswer(21));
    },
  );

  test(
    'predicateWithCurrentPathExpression_reevaluated_whenTriggerChanges',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Predicate trigger'),
            model([
              mainInstance([
                t('data id="predicate-trigger"', [
                  t('outer_repeat', [
                    t('cutoff_number'),
                    t('inner_repeat', [t('foo'), t('join')]),
                  ]),
                ]),
              ]),
              t('instance id="dataset"', [
                t('root', [
                  for (var n = 1; n <= 5; n++)
                    t('item', [tText('name', 'Item$n'), tText('value', '$n')]),
                ]),
              ]),
              bind('/data/outer_repeat/cutoff_number')..type('int'),
              bind('/data/outer_repeat/inner_repeat/join')
                ..type('string')
                ..calculate(
                  "join(', ', instance('dataset')/root/item"
                  '[value > current()/../../cutoff_number]/name)',
                ),
            ]),
          ]),
          body([
            repeat('/data/outer_repeat', [
              input('/data/outer_repeat/cutoff_number'),
              repeat('/data/outer_repeat/inner_repeat', [
                input('/data/outer_repeat/inner_repeat/foo'),
              ]),
            ]),
          ]),
        ),
      );

      scenario.answer('/data/outer_repeat/cutoff_number', 3);
      expect(
        scenario.answerOf('/data/outer_repeat/inner_repeat/join'),
        stringAnswer('Item4, Item5'),
      );

      scenario.answer('/data/outer_repeat/cutoff_number', 7);
      expect(scenario.answerOf('/data/outer_repeat/inner_repeat/join'), isNull);

      scenario.answer('/data/outer_repeat/cutoff_number', 4);
      expect(
        scenario.answerOf('/data/outer_repeat/inner_repeat/join'),
        stringAnswer('Item5'),
      );
    },
  );
}
