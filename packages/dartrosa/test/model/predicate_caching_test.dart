@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 PredicateCachingTest.
import 'package:dartrosa/src/util/measure.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

const _events = ['PredicateEvaluation', 'IndexEvaluation'];

/// The form most tests use: `/data/choice` and two calculates filtering
/// `instance('instance')` with [calculate1] and [calculate2].
XFormsElement _twoCalculatesForm(
  List<XFormsElement> items,
  String calculate1,
  String calculate2,
) => html(
  head([
    title('Some form'),
    model([
      mainInstance([
        t('data id="some-form"', [
          t('choice'),
          t('calculate1'),
          t('calculate2'),
        ]),
      ]),
      instance('instance', items),
      bind('/data/choice')..type('string'),
      bind('/data/calculate1')
        ..type('string')
        ..calculate(calculate1),
      bind('/data/calculate2')
        ..type('string')
        ..calculate(calculate2),
    ]),
  ]),
  body([input('/data/choice')]),
);

void main() {
  test('repeatedEqPredicatesAreOnlyEvaluatedOnceWhileAnswering', () async {
    final scenario = await Scenario.init(
      _twoCalculatesForm(
        [item('a', 'A'), item('b', 'B')],
        "instance('instance')/root/item[value = /data/choice]/label",
        "instance('instance')/root/item[value = /data/choice]/value",
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario.answer('/data/choice', 'a');
    });

    // Check that we do less than (size of secondary instance) * (number of
    // calculates with a filter)
    expect(evaluations, lessThan(4));
  });

  test('repeatedCompPredicatesAreOnlyEvaluatedOnceWhileAnswering', () async {
    final scenario = await Scenario.init(
      _twoCalculatesForm(
        [item('1', 'A'), item('2', 'B')],
        "instance('instance')/root/item[value < /data/choice]/label",
        "instance('instance')/root/item[value < /data/choice]/value",
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario.answer('/data/choice', '2');
    });

    expect(evaluations, lessThan(4));
  });

  test(
    'repeatedIdempotentFuncPredicatesAreOnlyEvaluatedOnceWhileAnswering',
    () async {
      final scenario = await Scenario.init(
        _twoCalculatesForm(
          [item('1', 'A'), item('2', 'B')],
          "instance('instance')/root/item[regex(value, /data/choice)]/label",
          "instance('instance')/root/item[regex(value, /data/choice)]/value",
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario.answer('/data/choice', '1');
      });

      expect(evaluations, lessThan(4));
    },
  );

  test('repeatedEqPredicatesAreOnlyEvaluatedOnce', () async {
    final scenario = await Scenario.init(
      _twoCalculatesForm(
        [item('a', 'A'), item('b', 'B')],
        "instance('instance')/root/item[value = /data/choice]/label",
        "instance('instance')/root/item[value = /data/choice]/value",
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario
        ..answer('/data/choice', 'a')
        ..answer('/data/choice', 'b');
    });

    // Check that we do less than size of secondary instance * number of
    // times we answer
    expect(evaluations, lessThan(4));
  });

  test('firstPredicateInMultipleEqPredicatesAreOnlyEvaluatedOnce', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('calc'), t('input1'), t('input2')]),
            ]),
            instance('instance', [
              t('item', [
                tText('value', 'A'),
                tText('count', '2'),
                tText('id', 'A2'),
              ]),
              t('item', [
                tText('value', 'A'),
                tText('count', '3'),
                tText('id', 'A3'),
              ]),
              t('item', [
                tText('value', 'B'),
                tText('count', '2'),
                tText('id', 'B2'),
              ]),
            ]),
            bind('/data/calc')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input1]"
                '[count = /data/input2]/id',
              ),
            bind('/data/input1')..type('string'),
            bind('/data/input2')..type('string'),
          ]),
        ]),
        body([input('/data/input1'), input('/data/input2')]),
      ),
    );

    final evaluations = Measure.withMeasure(_events, () {
      scenario
        ..answer('/data/input1', 'A')
        ..answer('/data/input2', '3')
        ..answer('/data/input1', 'A')
        ..answer('/data/input2', '2');
    });

    // Check that we do less than size of (secondary instance + filtered
    // secondary instance) * number of times we answer
    expect(evaluations, lessThan(20));
  });

  test(
    'repeatedCompPredicatesWithSameAbsoluteValueAreOnlyEvaluatedOnce',
    () async {
      final scenario = await Scenario.init(
        _twoCalculatesForm(
          [item('1', 'A'), item('2', 'B')],
          "instance('instance')/root/item[value < /data/choice]/label",
          "instance('instance')/root/item[value < /data/choice]/value",
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', '2')
          ..answer('/data/choice', '2');
      });

      expect(evaluations, lessThan(4));
    },
  );

  test(
    'repeatedIdempotentFuncPredicatesWithSameAbsoluteValueAreOnlyEvaluatedOnce',
    () async {
      final scenario = await Scenario.init(
        _twoCalculatesForm(
          [item('a', 'A'), item('b', 'B')],
          "instance('instance')/root/item[regex(value,/data/choice)]/label",
          "instance('instance')/root/item[regex(value,/data/choice)]/value",
        ),
      );

      final evaluations = Measure.withMeasure(_events, () {
        scenario
          ..answer('/data/choice', 'a')
          ..answer('/data/choice', 'a');
      });

      expect(evaluations, lessThan(4));
    },
  );

  // A form with multiple secondary instances can have expressions with
  // "equivalent" predicates that filter on different sets of children.
  test(
    'equivalentPredicateExpressionsOnDifferentReferencesAreNotConfused',
    () async {
      final scenario = await scenarioFor('two-secondary-instances.xml');

      scenario
        ..next()
        ..answerCurrent('a');
      expect(scenario.answerOf('/data/both')!.value, 'AA');
    },
  );

  test('equivalentPredicateExpressionsInRepeatsDoNotGetConfused', () async {
    final scenario = await scenarioFor('repeat-secondary-instance.xml');

    scenario
      ..createNewRepeat('/data/repeat')
      ..createNewRepeat('/data/repeat')
      ..answer('/data/repeat[1]/choice', 'a');
    expect(scenario.answerOf('/data/repeat[1]/calculate')!.value, 'A');
    expect(scenario.answerOf('/data/repeat[2]/calculate'), isNull);

    scenario.answer('/data/repeat[2]/choice', 'b');
    expect(scenario.answerOf('/data/repeat[1]/calculate')!.value, 'A');
    expect(scenario.answerOf('/data/repeat[2]/calculate')!.value, 'B');
  });

  test('predicatesOnDifferentChildNamesDoNotGetConfused', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('cat'), t('dog'), t('input')]),
            ]),
            instance('instance', [
              t('cat', [tText('name', 'Vinnie'), tText('age', '12')]),
              t('dog', [tText('name', 'Vinnie'), tText('age', '9')]),
            ]),
            bind('/data/cat')
              ..type('string')
              ..calculate(
                "instance('instance')/root/cat[name = /data/input]/age",
              ),
            bind('/data/dog')
              ..type('string')
              ..calculate(
                "instance('instance')/root/dog[name = /data/input]/age",
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    scenario.answer('/data/input', 'Vinnie');

    expect(scenario.answerOf('/data/cat')!.value, '12');
    expect(scenario.answerOf('/data/dog')!.value, '9');
  });

  test('eqExpressionsWorkIfEitherSideIsRelative', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('calcltr'),
                t('calcrtl'),
                t('input'),
              ]),
            ]),
            instance('instance', [
              t('item', [tText('value', 'A')]),
              t('item', [tText('value', 'B')]),
            ]),
            bind('/data/calcltr')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input]/value",
              ),
            bind('/data/calcrtl')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[/data/input = value]/value",
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    scenario.answer('/data/input', 'A');
    expect(scenario.answerOf('/data/calcltr')!.value, 'A');
    expect(scenario.answerOf('/data/calcrtl')!.value, 'A');

    scenario.answer('/data/input', 'B');
    expect(scenario.answerOf('/data/calcltr')!.value, 'B');
    expect(scenario.answerOf('/data/calcrtl')!.value, 'B');
  });

  test('eqExpressionsWorkIfBothSidesAreRelative', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('calc'), t('input')]),
            ]),
            instance('instance', [
              t('item', [tText('value', 'A')]),
            ]),
            bind('/data/calc')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = value]/value",
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    expect(scenario.answerOf('/data/calc')!.value, 'A');
  });

  test('nestedPredicatesDoNotGetConfused', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('calc'),
                t('calc2'),
                t('input1'),
                t('input2'),
              ]),
            ]),
            instance('instance', [
              t('item', [
                tText('value', 'A'),
                tText('count', '2'),
                tText('id', 'A2'),
              ]),
              t('item', [
                tText('value', 'A'),
                tText('count', '3'),
                tText('id', 'A3'),
              ]),
              t('item', [
                tText('value', 'B'),
                tText('count', '2'),
                tText('id', 'B2'),
              ]),
            ]),
            bind('/data/calc')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input1]"
                "[count = '3']/id",
              ),
            bind('/data/calc2')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input2]"
                "[count = '3']/id",
              ),
            bind('/data/input1')..type('string'),
            bind('/data/input2')..type('string'),
          ]),
        ]),
        body([input('/data/input1'), input('/data/input2')]),
      ),
    );

    scenario
      ..answer('/data/input1', 'A')
      ..answer('/data/input2', 'B');

    expect(scenario.answerOf('/data/calc')!.value, 'A3');
    expect(scenario.answerOf('/data/calc2'), isNull);
  });

  test('similarCmpAndEqExpressionsDoNotGetConfused', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('input'),
                t('calculate1'),
                t('calculate2'),
              ]),
            ]),
            instance('instance', [item('1', 'A'), item('2', 'B')]),
            bind('/data/input')..type('string'),
            bind('/data/calculate1')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value < /data/input]/label",
              ),
            bind('/data/calculate2')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input]/label",
              ),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    scenario.answer('/data/input', '2');
    expect(scenario.answerOf('/data/calculate1')!.value, 'A');
    expect(scenario.answerOf('/data/calculate2')!.value, 'B');
  });

  test('differentEqExpressionsAreNotConfused', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('calc1'),
                t('calc2'),
                t('input1'),
                t('input2'),
              ]),
            ]),
            instance('instance', [item('a', 'A'), item('b', 'B')]),
            bind('/data/calc1')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = /data/input1]/label",
              ),
            bind('/data/calc2')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[label = /data/input2]/label",
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input1'), input('/data/input2')]),
      ),
    );

    scenario
      ..answer('/data/input1', 'a')
      ..answer('/data/input2', 'B');

    expect(scenario.answerOf('/data/calc1')!.value, 'A');
    expect(scenario.answerOf('/data/calc2')!.value, 'B');
  });

  test('differentKindsOfEqExpressionsAreNotConfused', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('calc1'), t('calc2'), t('input')]),
            ]),
            instance('instance', [item('a', 'A'), item('b', 'B')]),
            bind('/data/calc1')
              ..type('string')
              ..calculate("instance('instance')/root/item[value = 'a']/label"),
            bind('/data/calc2')
              ..type('string')
              ..calculate("instance('instance')/root/item[value != 'a']/label"),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    expect(scenario.answerOf('/data/calc1')!.value, 'A');
    expect(scenario.answerOf('/data/calc2')!.value, 'B');
  });

  test('repeatsUsedInCalculatesStayUpToDate', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('repeat', [t('name'), t('age')]),
                t('result'),
              ]),
            ]),
            bind('/data/repeat/input')..type('string'),
            bind('/data/result')
              ..type('string')
              ..calculate("/data/repeat[name = 'John Bell']/age"),
          ]),
        ]),
        body([
          formGroup('/data/repeat', [
            repeat('/data/repeat', [
              input('/data/repeat/name'),
              input('/data/repeat/age'),
            ]),
          ]),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/result'), isNull);

    scenario
      ..createNewRepeat('/data/repeat')
      ..answer('/data/repeat[1]/name', 'John Bell')
      ..answer('/data/repeat[1]/age', '70');

    expect(scenario.answerOf('/data/result')!.value, '70');
  });

  test('eqPredicatesDoNotIncreaseLoadTime', () async {
    final evaluations = await Measure.withMeasureAsync(_events, () async {
      await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('choice'),
                  t('calculate1'),
                  t('calculate2'),
                ]),
              ]),
              instance('instance', [item('a', 'A'), item('b', 'B')]),
              bind('/data/choice')..type('string'),
              bind('/data/calculate1')
                ..type('string')
                ..calculate(
                  "instance('instance')/root/item[value = /data/choice]/label",
                ),
            ]),
          ]),
          body([input('/data/choice')]),
        ),
      );
    });

    expect(evaluations, isNot(greaterThan(2)));
  });
}
