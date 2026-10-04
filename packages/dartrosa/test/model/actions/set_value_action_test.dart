// Port of JavaRosa v6.0.0 SetValueActionTest.
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

void main() {
  test('when_triggerNodeIsUpdated_targetNodeCalculation_isEvaluated', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Nested setvalue action'),
          model([
            mainInstance([
              t('data id="nested-setvalue"', [t('source'), t('destination')]),
            ]),
            bind('/data/source')..type('int'),
            bind('/data/destination')..type('int'),
          ]),
        ]),
        body([
          input('/data/source', [
            setvalue('xforms-value-changed', '/data/destination', '4*4'),
          ]),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/destination'), isNull);

    scenario
      ..next()
      ..answerCurrent(22);

    expect(scenario.answerOf('/data/destination'), intAnswer(16));
  });

  test('expressionAsLiteralValue_isNotEvaluated', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Literal setvalue'),
          model([
            mainInstance([
              t('data id="literal-setvalue"', [t('source'), t('destination')]),
            ]),
            bind('/data/source')..type('string'),
            bind('/data/destination')..type('string'),
          ]),
        ]),
        body([
          input('/data/source', [
            setvalueLiteral('xforms-value-changed', '/data/destination', '4*4'),
          ]),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/destination'), isNull);

    scenario
      ..next()
      ..answerCurrent(22);

    expect(scenario.answerOf('/data/destination'), stringAnswer('4*4'));
  });

  test(
    'when_triggerNodeIsUpdatedWithTheSameValue_targetNodeCalculation_isNotEvaluated',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Nested setvalue action'),
            model([
              mainInstance([
                t('data id="nested-setvalue"', [
                  t('source'),
                  t('destination'),
                  t('some-field'),
                ]),
              ]),
              bind('/data/destination')..type('string'),
            ]),
          ]),
          body([
            input('/data/source', [
              setvalue(
                'xforms-value-changed',
                '/data/destination',
                "concat('foo',/data/some-field)",
              ),
            ]),
            input('/data/some-field'),
          ]),
        ),
      );

      expect(scenario.answerOf('/data/destination'), isNull);

      scenario
        ..next()
        ..answerCurrent(22);
      expect(scenario.answerOf('/data/destination'), stringAnswer('foo'));

      scenario
        ..next()
        ..answerCurrent('bar')
        ..prev()
        ..answerCurrent(22);
      expect(scenario.answerOf('/data/destination'), stringAnswer('foo'));

      scenario.answerCurrent(23);
      expect(scenario.answerOf('/data/destination'), stringAnswer('foobar'));
    },
  );

  test(
    'setvalue_isSerializedAndDeserialized',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test(
    'setvalueWithNoValue_isSerializedAndDeserialized',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  // region groups
  test('setvalueInGroup_setsValueOutsideOfGroup', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Setvalue'),
                model([
                  mainInstance([
                    t('data id="setvalue"', [
                      t('g', [t('source')]),
                      t('destination'),
                    ]),
                  ]),
                  bind('/data/g/source')..type('int'),
                  bind('/data/destination')..type('int'),
                ]),
              ]),
              body([
                formGroup('/data/g', [
                  input('/data/g/source', [
                    setvalueLiteral(
                      'xforms-value-changed',
                      '/data/destination',
                      '7',
                    ),
                  ]),
                ]),
              ]),
            ),
          )
          ..answer('/data/g/source', 'foo');
    expect(scenario.answerOf('/data/destination'), intAnswer(7));
  });

  test('setvalueOutsideGroup_setsValueInGroup', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Setvalue'),
                model([
                  mainInstance([
                    t('data id="setvalue"', [
                      t('source'),
                      t('g', [t('destination')]),
                    ]),
                  ]),
                  bind('/data/source')..type('int'),
                  bind('/data/g/destination')..type('int'),
                ]),
              ]),
              body([
                input('/data/source', [
                  setvalueLiteral(
                    'xforms-value-changed',
                    '/data/g/destination',
                    '7',
                  ),
                ]),
              ]),
            ),
          )
          ..answer('/data/source', 'foo');
    expect(scenario.answerOf('/data/g/destination'), intAnswer(7));
  });
  // endregion

  // region repeats
  test('sourceInRepeat_updatesDestInSameRepeatInstance', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Nested setvalue action with repeats'),
          model([
            mainInstance([
              t('data id="nested-setvalue-repeats"', [
                t('repeat', [t('source'), t('destination')]),
              ]),
            ]),
            bind('/data/repeat/destination')..type('int'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [
            input('/data/repeat/source', [
              setvalue(
                'xforms-value-changed',
                '/data/repeat/destination',
                '4*position(..)',
              ),
            ]),
          ]),
        ]),
      ),
    );

    const repeatCount = 5;

    for (var i = 1; i <= repeatCount; i++) {
      scenario.createNewRepeat('/data/repeat');
      expect(scenario.answerOf('/data/repeat[$i]/destination'), isNull);
    }

    for (var i = 1; i <= repeatCount; i++) {
      scenario.answer('/data/repeat[$i]/source', 7);
    }

    for (var i = 1; i <= repeatCount; i++) {
      expect(
        scenario.answerOf('/data/repeat[$i]/destination'),
        intAnswer(4 * i),
      );
    }
  });

  XFormsElement setvalueIntoRepeatForm(String target) => html(
    head([
      title('Setvalue into repeat'),
      model([
        mainInstance([
          t('data id="setvalue-into-repeat"', [
            t('source'),
            t('repeat', [t('destination')]),
          ]),
        ]),
      ]),
    ]),
    body([
      input('/data/source', [
        setvalue('xforms-value-changed', target, '/data/source'),
      ]),
      repeat('/data/repeat', [input('/data/repeat/destination')]),
    ]),
  );

  test('setvalueAtRoot_setsValueOfNodeInFirstRepeatInstance', () async {
    final scenario =
        await Scenario.init(
            setvalueIntoRepeatForm('/data/repeat[position()=1]/destination'),
          )
          ..createNewRepeat('/data/repeat')
          ..createNewRepeat('/data/repeat')
          ..createNewRepeat('/data/repeat')
          ..answer('/data/source', 'foo');
    expect(
      scenario.answerOf('/data/repeat[1]/destination')!.displayText,
      'foo',
    );
  });

  test(
    'setvalueAtRoot_setsValueOfNodeInRepeatInstanceAddedAfterFormLoad',
    () async {
      final scenario =
          await Scenario.init(
              setvalueIntoRepeatForm('/data/repeat[position()=2]/destination'),
            )
            ..createNewRepeat('/data/repeat')
            ..createNewRepeat('/data/repeat')
            ..createNewRepeat('/data/repeat')
            ..answer('/data/source', 'foo');
      expect(
        scenario.answerOf('/data/repeat[2]/destination')!.displayText,
        'foo',
      );
    },
    skip:
        '@Ignore in JavaRosa: "TODO: verifyActions seems like it may be '
        'overzealous"',
  );

  test(
    'setValueAtRoot_throwsExpression_whenTargetIsUnboundReference',
    () async {
      final scenario =
          await Scenario.init(
              setvalueIntoRepeatForm('/data/repeat/destination'),
            )
            ..createNewRepeat('/data/repeat')
            ..createNewRepeat('/data/repeat')
            ..createNewRepeat('/data/repeat');

      expect(
        () => scenario.answer('/data/source', 'foo'),
        throwsA(
          isA<XPathTypeMismatchException>().having(
            (e) => e.message,
            'message',
            contains('has more than one node'),
          ),
        ),
      );
    },
  );

  test('setValueInRepeat_setsValueOutsideOfRepeat', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Nested setvalue action with repeats'),
          model([
            mainInstance([
              t('data id="nested-setvalue-repeats"', [
                tText('destination', '0'),
                t('repeat', [t('source')]),
              ]),
            ]),
            bind('/data/destination')..type('int'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [
            input('/data/repeat/source', [
              setvalue('xforms-value-changed', '/data/destination', '.+1'),
            ]),
          ]),
        ]),
      ),
    );

    const repeatCount = 5;

    for (var i = 1; i <= repeatCount; i++) {
      scenario.createNewRepeat('/data/repeat');
      expect(scenario.answerOf('/data/destination'), intAnswer(0));
    }

    for (var i = 1; i <= repeatCount; i++) {
      scenario.answer('/data/repeat[$i]/source', 7);
      expect(scenario.answerOf('/data/destination'), intAnswer(i));
    }
  });

  test('setvalueInOuterRepeat_setsInnerRepeatValue', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Nested repeats'),
                model([
                  mainInstance([
                    t('data id="nested-repeats"', [
                      t('repeat1', [
                        t('source'),
                        t('repeat2', [t('destination')]),
                      ]),
                    ]),
                  ]),
                ]),
              ]),
              body([
                repeat('/data/repeat1', [
                  input('/data/repeat1/source', [
                    setvalue(
                      'xforms-value-changed',
                      '/data/repeat1/repeat2/destination',
                      '../../source',
                    ),
                  ]),
                  repeat('/data/repeat1/repeat2', [
                    input('/data/repeat1/repeat2/destination'),
                  ]),
                ]),
              ]),
            ),
          )
          ..answer('/data/repeat1[0]/source', 'foo');
    expect(
      scenario.answerOf('/data/repeat1[0]/repeat2[0]/destination')!.displayText,
      'foo',
    );
  });
  // endregion

  /// Read-only is a display-only concern so it should be possible to use an
  /// action to modify the value of a read-only field.
  test('setvalue_setsValueOfReadOnlyField', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Setvalue readonly'),
          model([
            mainInstance([
              t('data id="setvalue-readonly"', [t('readonly-field')]),
            ]),
            bind('/data/readonly-field')
              ..readonly('1')
              ..type('int'),
            setvalue('odk-instance-first-load', '/data/readonly-field', '4*4'),
          ]),
        ]),
        body([input('/data/readonly-field')]),
      ),
    );

    expect(scenario.answerOf('/data/readonly-field'), intAnswer(16));
  });

  test('setvalue_withInnerEmptyString_clearsTarget', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Setvalue empty string'),
          model([
            mainInstance([
              t('data id="setvalue-empty-string"', [tText('a-field', '12')]),
            ]),
            bind('/data/a-field')..type('int'),
            setvalue('odk-instance-first-load', '/data/a-field'),
          ]),
        ]),
        body([input('/data/a-field')]),
      ),
    );

    expect(scenario.answerOf('/data/a-field'), isNull);
  });

  test('setvalue_withEmptyStringValue_clearsTarget', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Setvalue empty string'),
          model([
            mainInstance([
              t('data id="setvalue-empty-string"', [tText('a-field', '12')]),
            ]),
            bind('/data/a-field')..type('int'),
            setvalue('odk-instance-first-load', '/data/a-field', ''),
          ]),
        ]),
        body([input('/data/a-field')]),
      ),
    );

    expect(scenario.answerOf('/data/a-field'), isNull);
  });

  test('setvalue_setsValueOfMultipleFields', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Setvalue multiple destinations'),
                model([
                  mainInstance([
                    t('data id="setvalue-multiple"', [
                      t('source'),
                      t('destination1'),
                      t('destination2'),
                    ]),
                  ]),
                  bind('/data/destination1')..type('int'),
                  bind('/data/destination2')..type('int'),
                ]),
              ]),
              body([
                input('/data/source', [
                  setvalueLiteral(
                    'xforms-value-changed',
                    '/data/destination1',
                    '7',
                  ),
                  setvalueLiteral(
                    'xforms-value-changed',
                    '/data/destination2',
                    '11',
                  ),
                ]),
              ]),
            ),
          )
          ..answer('/data/source', 'foo');
    expect(scenario.answerOf('/data/destination1'), intAnswer(7));
    expect(scenario.answerOf('/data/destination2'), intAnswer(11));
  });

  test('xformsValueChanged_triggeredAfterRecomputation', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Value changed event'),
                model([
                  mainInstance([
                    t('data id="xforms-value-changed-event"', [
                      t('source'),
                      t('calculate'),
                      t('destination'),
                    ]),
                  ]),
                  bind('/data/calculate')
                    ..type('int')
                    ..calculate('/data/source * 2'),
                  bind('/data/destination')..type('int'),
                ]),
              ]),
              body([
                input('/data/source', [
                  setvalue(
                    'xforms-value-changed',
                    '/data/destination',
                    '/data/calculate',
                  ),
                ]),
              ]),
            ),
          )
          ..answer('/data/source', 12);
    expect(scenario.answerOf('/data/destination'), intAnswer(24));
  });

  test('setvalue_setsValueOfAttribute', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Setvalue attribute'),
          model([
            mainInstance([
              t('data id="setvalue-attribute"', [t('element attr=""')]),
            ]),
            setvalue('odk-instance-first-load', '/data/element/@attr', '7'),
          ]),
        ]),
        body([input('/data/element')]),
      ),
    );

    expect(scenario.answerOf('/data/element/@attr')!.displayText, '7');
  });

  test(
    'setvalue_setsValueOfAttribute_afterDeserialization',
    () {},
    skip: 'instance/form serialization (P6)',
  );
}
