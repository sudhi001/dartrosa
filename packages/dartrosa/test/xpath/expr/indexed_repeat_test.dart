// Port of JavaRosa v6.0.0 IndexedRepeatTest.
import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

void main() {
  test('firstArgNotChildOfRepeat_throwsException', () async {
    await expectLater(
      Scenario.init(
        html(
          head([
            title('indexed-repeat'),
            model([
              mainInstance([
                t('data id="indexed-repeat"', [
                  t('outside'),
                  t('repeat', [t('inside')]),
                  t('calc'),
                ]),
              ]),
              bind('/data/calc')
                ..calculate('indexed-repeat(/data/outside, /data/repeat, 1)'),
            ]),
          ]),
          body([
            input('/data/outside'),
            repeat('/data/repeat', [input('/data/repeat/inside')]),
          ]),
        ),
      ),
      throwsA(
        isA<TriggerableEvaluationException>().having(
          (e) => e.cause,
          'cause',
          isA<XPathTypeMismatchException>(),
        ),
      ),
    );
  });

  test('getsIndexedValueInSingleRepeat', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('indexed-repeat'),
          model([
            mainInstance([
              t('data id="indexed-repeat"', [
                t('index'),
                // included to clarify intended evaluation context for index
                // references
                t('outer_group', [
                  t('repeat', [t('inside')]),
                ]),
                t('calc'),
              ]),
            ]),
            bind('/data/calc')..calculate(
              'indexed-repeat(/data/outer_group/repeat/inside, '
              '/data/outer_group/repeat, ../index)',
            ),
          ]),
        ]),
        body([
          input('/data/index'),
          formGroup('/data/outer_group', [
            repeat('/data/outer_group/repeat', [
              input('/data/outer_group/repeat/inside'),
            ]),
          ]),
        ]),
      ),
    );

    scenario
      ..createNewRepeat('/data/outer_group[1]/repeat')
      ..answer('/data/outer_group[1]/repeat[1]/inside', 'index1')
      ..createNewRepeat('/data/outer_group[1]/repeat')
      ..answer('/data/outer_group[1]/repeat[2]/inside', 'index2')
      ..createNewRepeat('/data/outer_group[1]/repeat')
      ..answer('/data/outer_group[1]/repeat[3]/inside', 'index3')
      ..answer('/data/index', '2');
    expect(scenario.answerOf('/data/calc'), stringAnswer('index2'));

    scenario.answer('/data/index', '1');
    expect(scenario.answerOf('/data/calc'), stringAnswer('index1'));
  });

  test('getsIndexedValueUsingParallelRepeatPosition', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('indexed-repeat'),
          model([
            mainInstance([
              t('data id="indexed-repeat"', [
                t('repeat1', [t('inside1')]),
                t('repeat2', [t('inside2'), t('from_repeat1')]),
              ]),
            ]),
            bind('/data/repeat2/from_repeat1')..calculate(
              'indexed-repeat(/data/repeat1/inside1, /data/repeat1, '
              'position(..))',
            ),
          ]),
        ]),
        body([
          repeat('/data/repeat1', [input('/data/repeat1/inside1')]),
          repeat('/data/repeat2', [input('/data/repeat2/inside2')]),
        ]),
      ),
    );

    scenario
      ..createNewRepeat('/data/repeat1')
      ..createNewRepeat('/data/repeat2')
      ..answer('/data/repeat1[1]/inside1', 'index1')
      ..createNewRepeat('/data/repeat1')
      ..createNewRepeat('/data/repeat2')
      ..answer('/data/repeat1[2]/inside1', 'index2')
      ..createNewRepeat('/data/repeat1')
      ..createNewRepeat('/data/repeat2')
      ..answer('/data/repeat1[3]/inside1', 'index3');

    expect(
      scenario.answerOf('/data/repeat2[1]/from_repeat1'),
      stringAnswer('index1'),
    );
    expect(
      scenario.answerOf('/data/repeat2[2]/from_repeat1'),
      stringAnswer('index2'),
    );
  });

  test('handlesTopLevelRepeats', () async {
    final scenario = await buildNestedRepeatForm();
    expect(scenario.answerOf('/data/r2-d1[1]/from-r1-d1'), stringAnswer('[1]'));
    expect(scenario.answerOf('/data/r2-d1[2]/from-r1-d1'), stringAnswer('[2]'));
  });

  test('handlesRepeatsTwoDeep', () async {
    final scenario = await buildNestedRepeatForm();
    for (final field in ['from-r1-d2-a', 'from-r1-d2-b']) {
      for (final (i, j) in [(1, 1), (1, 2), (2, 1), (2, 2)]) {
        expect(
          scenario.answerOf('/data/r2-d1[$i]/r2-d2[$j]/$field'),
          stringAnswer('[$i][$j]'),
        );
      }
    }
  });

  test('handlesRepeatsThreeDeep', () async {
    final scenario = await buildNestedRepeatForm();
    for (final field in ['from-r1-d3-a', 'from-r1-d3-b']) {
      for (final i in [1, 2]) {
        for (final j in [1, 2]) {
          for (final k in [1, 2]) {
            expect(
              scenario.answerOf('/data/r2-d1[$i]/r2-d2[$j]/r2-d3[$k]/$field'),
              stringAnswer('[$i][$j][$k]'),
            );
          }
        }
      }
    }
  });
}

Future<Scenario> buildNestedRepeatForm() async {
  final scenario = await Scenario.init(
    html(
      head([
        title('indexed-repeat'),
        model([
          mainInstance([
            t('data id="indexed-repeat"', [
              t('r1-d1 jr:template=""', [
                t('inside-r1-d1'),
                t('r1-d2 jr:template=""', [
                  t('inside-r1-d2'),
                  t('r1-d3 jr:template=""', [t('inside-r1-d3')]),
                ]),
              ]),
              t('r2-d1 jr:template=""', [
                t('inside-r2-d1'),
                t('from-r1-d1'),
                t('r2-d2 jr:template=""', [
                  t('inside-r2-d2'),
                  t('from-r1-d2-a'),
                  t('from-r1-d2-b'),
                  t('r2-d3 jr:template=""', [
                    t('inside-r2-d3'),
                    t('from-r1-d3-a'),
                    t('from-r1-d3-b'),
                  ]),
                ]),
              ]),
            ]),
          ]),
          bind('/data/r1-d1/inside-r1-d1')
            ..calculate("concat('[', position(..), ']')"),
          bind('/data/r1-d1/r1-d2/inside-r1-d2')..calculate(
            "concat('[', position(../..), ']', '[', position(..), ']')",
          ),
          bind('/data/r1-d1/r1-d2/r1-d3/inside-r1-d3')..calculate(
            "concat('[', position(../../..), ']', '[', position(../..), ']', "
            "'[', position(..), ']')",
          ),
          bind('/data/r2-d1/from-r1-d1')..calculate(
            'indexed-repeat(/data/r1-d1/inside-r1-d1, /data/r1-d1, '
            'position(..))',
          ),
          bind('/data/r2-d1/r2-d2/from-r1-d2-a')..calculate(
            'indexed-repeat(/data/r1-d1/r1-d2/inside-r1-d2, /data/r1-d1, '
            'position(../..), /data/r1-d1/r1-d2, position(..))',
          ),
          // Same as from-r1-d2-a with the repeatN/indexN pairs swapped
          bind('/data/r2-d1/r2-d2/from-r1-d2-b')..calculate(
            'indexed-repeat(/data/r1-d1/r1-d2/inside-r1-d2, '
            '/data/r1-d1/r1-d2, position(..), /data/r1-d1, '
            'position(../..))',
          ),
          bind('/data/r2-d1/r2-d2/r2-d3/from-r1-d3-a')..calculate(
            'indexed-repeat(/data/r1-d1/r1-d2/r1-d3/inside-r1-d3, '
            '/data/r1-d1, position(../../..), /data/r1-d1/r1-d2, '
            'position(../..), /data/r1-d1/r1-d2/r1-d3, position(..))',
          ),
          // Same as from-r1-d3-a with the repeatN/indexN pairs reordered
          bind('/data/r2-d1/r2-d2/r2-d3/from-r1-d3-b')..calculate(
            'indexed-repeat(/data/r1-d1/r1-d2/r1-d3/inside-r1-d3, '
            '/data/r1-d1/r1-d2, position(../..), /data/r1-d1, '
            'position(../../..), /data/r1-d1/r1-d2/r1-d3, position(..))',
          ),
        ]),
      ]),
      body([
        repeat('/data/r1-d1', [
          input('/data/r1-d1/inside-r1-d1'),
          repeat('/data/r1-d1/r1-d2', [
            input('/data/r1-d1/r1-d2/inside-r1-d2'),
            repeat('/data/r1-d1/r1-d2/r1-d3', [
              input('/data/r1-d1/r1-d2/r1-d3/inside-r1-d3'),
            ]),
          ]),
        ]),
        repeat('/data/r2-d1', [
          input('/data/r2-d1/inside-r2-d1'),
          repeat('/data/r2-d1/r2-d2', [
            input('/data/r2-d1/r2-d2/inside-r2-d2'),
            repeat('/data/r2-d1/r2-d2/r2-d3', [
              input('/data/r2-d1/r2-d2/r2-d3/inside-r2-d3'),
            ]),
          ]),
        ]),
      ]),
    ),
  );

  for (final r in ['r1', 'r2']) {
    scenario
      ..createNewRepeat('/data/$r-d1')
      ..createNewRepeat('/data/$r-d1')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2[1]/$r-d3')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2[1]/$r-d3')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2[2]/$r-d3')
      ..createNewRepeat('/data/$r-d1[1]/$r-d2[2]/$r-d3')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2[1]/$r-d3')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2[1]/$r-d3')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2[2]/$r-d3')
      ..createNewRepeat('/data/$r-d1[2]/$r-d2[2]/$r-d3');
  }

  return scenario;
}
