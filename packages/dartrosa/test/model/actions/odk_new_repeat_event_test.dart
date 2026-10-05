// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (OdkNewRepeatEventTest), Copyright (C) 2009 JavaRosa
//  and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 OdkNewRepeatEventTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';
import '../../support/matchers.dart';

void main() {
  const form = 'event-odk-new-repeat.xml';

  test('setValueOnRepeatInsertInBody_setsValueInRepeat', () async {
    final scenario = await scenarioFor(form);

    expect(scenario.countRepeatInstancesOf('/data/my-repeat'), 0);
    scenario.createNewRepeat('/data/my-repeat');
    expect(scenario.countRepeatInstancesOf('/data/my-repeat'), 1);
    expect(
      scenario.answerOf('/data/my-repeat[1]/defaults-to-position')!.displayText,
      '1',
    );
  });

  test('addingRepeat_doesNotChangeValueSetForPreviousRepeat', () async {
    final scenario = await scenarioFor(form)
      ..createNewRepeat('/data/my-repeat');
    expect(
      scenario.answerOf('/data/my-repeat[1]/defaults-to-position')!.displayText,
      '1',
    );

    scenario.createNewRepeat('/data/my-repeat');
    expect(
      scenario.answerOf('/data/my-repeat[2]/defaults-to-position')!.displayText,
      '2',
    );

    expect(
      scenario.answerOf('/data/my-repeat[1]/defaults-to-position')!.displayText,
      '1',
    );
  });

  test(
    'setValueOnRepeatInBody_usesCurrentContextForRelativeReferences',
    () async {
      final scenario = await scenarioFor(form)
        ..answer('/data/my-toplevel-value', '12')
        ..createNewRepeat('/data/my-repeat');
      expect(
        scenario
            .answerOf('/data/my-repeat[1]/defaults-to-toplevel')!
            .displayText,
        '14',
      );
    },
  );

  void nextUntilEnd(Scenario scenario) {
    while (!scenario.atTheEndOfForm) {
      scenario.next();
    }
  }

  test('setValueOnRepeatWithCount_setsValueForEachRepeat', () async {
    final scenario = await scenarioFor(form)
      ..answer('/data/repeat-count', 4);

    nextUntilEnd(scenario);

    expect(scenario.countRepeatInstancesOf('/data/my-jr-count-repeat'), 4);

    for (var i = 1; i <= 4; i++) {
      expect(
        scenario
            .answerOf(
              '/data/my-jr-count-repeat[$i]/defaults-to-position-again',
            )!
            .displayText,
        '$i',
      );
    }

    // Adding repeats should trigger odk-new-repeat for those new nodes
    scenario
      ..answer('/data/repeat-count', 6)
      ..jumpToBeginningOfForm();
    nextUntilEnd(scenario);
    expect(scenario.countRepeatInstancesOf('/data/my-jr-count-repeat'), 6);
    expect(
      scenario
          .answerOf('/data/my-jr-count-repeat[6]/defaults-to-position-again')!
          .displayText,
      '6',
    );
  });

  test(
    'setOtherThanIntegerValueOnRepeatWithCount_convertsValueToInteger',
    () async {
      // String
      final scenario = await scenarioFor(form)
        ..answer('/data/repeat-count', '1');
      nextUntilEnd(scenario);
      expect(scenario.countRepeatInstancesOf('/data/my-jr-count-repeat'), 1);

      // Decimal
      scenario
        ..jumpToBeginningOfForm()
        ..answer('/data/repeat-count', 2.5);
      nextUntilEnd(scenario);
      expect(scenario.countRepeatInstancesOf('/data/my-jr-count-repeat'), 2);

      // Long
      scenario
        ..jumpToBeginningOfForm()
        ..answer('/data/repeat-count', const LongValue(3));
      nextUntilEnd(scenario);
      expect(scenario.countRepeatInstancesOf('/data/my-jr-count-repeat'), 3);
    },
  );

  test('repeatInFormDefInstance_neverFiresNewRepeatEvent', () async {
    final scenario = await scenarioFor(form);

    expect(
      scenario.answerOf('/data/my-repeat-without-template[1]/my-value'),
      isNull,
    );
    expect(
      scenario.answerOf('/data/my-repeat-without-template[2]/my-value'),
      isNull,
    );

    scenario.createNewRepeat('/data/my-repeat-without-template');
    expect(
      scenario
          .answerOf('/data/my-repeat-without-template[3]/my-value')!
          .displayText,
      '2',
    );
  });

  test('newRepeatInstance_doesNotTriggerActionOnUnrelatedRepeat', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Parallel repeats'),
                model([
                  mainInstance([
                    t('data id="parallel-repeats"', [
                      t('repeat1', [t('q1')]),
                      t('repeat2', [t('q1')]),
                    ]),
                  ]),
                ]),
              ]),
              body([
                repeat('/data/repeat1', [
                  setvalue(
                    'odk-new-repeat',
                    '/data/repeat1/q1',
                    "concat('foo','bar')",
                  ),
                  input('/data/repeat1/q1'),
                ]),
                repeat('/data/repeat2', [
                  setvalue(
                    'odk-new-repeat',
                    '/data/repeat2/q1',
                    "concat('bar','baz')",
                  ),
                  input('/data/repeat2/q1'),
                ]),
              ]),
            ),
          )
          ..createNewRepeat('/data/repeat1')
          ..createNewRepeat('/data/repeat1')
          ..createNewRepeat('/data/repeat2')
          ..createNewRepeat('/data/repeat2');

    expect(scenario.answerOf('/data/repeat1[2]/q1')!.displayText, 'foobar');
    expect(scenario.answerOf('/data/repeat1[3]/q1')!.displayText, 'foobar');

    expect(scenario.answerOf('/data/repeat2[2]/q1')!.displayText, 'barbaz');
    expect(scenario.answerOf('/data/repeat2[3]/q1')!.displayText, 'barbaz');
  });

  test('newRepeatInstance_canUsePreviousInstanceAsDefault', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Default from prior instance'),
          model([
            mainInstance([
              t('data id="default-from-prior-instance"', [
                t('repeat', [t('q')]),
              ]),
            ]),
            bind('/data/repeat/q')..type('int'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [
            setvalue(
              'odk-new-repeat',
              '/data/repeat/q',
              '/data/repeat[position()=position(current()/..)-1]/q',
            ),
            input('/data/repeat/q'),
          ]),
        ]),
      ),
    );
    scenario
      ..next()
      ..next()
      ..answerCurrent(7);
    expect(scenario.answerOf('/data/repeat[1]/q'), intAnswer(7));

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next();
    expect(scenario.answerOf('/data/repeat[2]/q'), intAnswer(7));
    scenario
      ..answerCurrent(8) // override the default
      ..next()
      ..createNewRepeatHere()
      ..next();
    expect(scenario.answerOf('/data/repeat[1]/q'), intAnswer(7));
    expect(scenario.answerOf('/data/repeat[2]/q'), intAnswer(8));
    expect(scenario.answerOf('/data/repeat[3]/q'), intAnswer(8));
  });

  // Not part of ODK XForms so throws parse exception.
  test('setValueOnRepeatInsertInModel_notAllowed', () async {
    await expectLater(
      scenarioFor('event-odk-new-repeat-model.xml'),
      throwsA(isA<XFormParseException>()),
    );
  });
}
