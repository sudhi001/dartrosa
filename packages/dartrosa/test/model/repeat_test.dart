// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (RepeatTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 RepeatTest.
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('whenRepeatIsNotRelevant_repeatPromptIsSkipped', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Non relevant repeat'),
                model([
                  mainInstance([
                    t('data id="non_relevant_repeat"', [
                      t('repeat1', [t('q1')]),
                    ]),
                  ]),
                  bind('/data/repeat1')..relevant('false()'),
                ]),
              ]),
              body([
                repeat('/data/repeat1', [input('/data/repeat1/q1')]),
              ]),
            ),
          )
          ..jumpToBeginningOfForm();

    final event = scenario.next();
    expect(event, FormEntryEvent.endOfForm);
  });

  test(
    'whenRepeatRelevanceIsDynamic_andNotRelevant_repeatPromptIsSkipped',
    () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Repeat relevance - dynamic expression'),
                  model([
                    mainInstance([
                      t('data id="repeat_relevance_dynamic"', [
                        t('selectYesNo'),
                        t('repeat1', [t('q1')]),
                      ]),
                    ]),
                    bind('/data/repeat1')
                      ..relevant("/data/selectYesNo = 'yes'"),
                  ]),
                ]),
                body([
                  select1('/data/selectYesNo', [
                    item('yes', 'Yes'),
                    item('no', 'No'),
                  ]),
                  repeat('/data/repeat1', [input('/data/repeat1/q1')]),
                ]),
              ),
            )
            ..jumpToBeginningOfForm()
            ..answer('/data/selectYesNo', 'no');

      final event = scenario.next();
      expect(event, FormEntryEvent.endOfForm);
    },
  );

  test(
    'whenRepeatAndTopLevelNodeHaveSameRelevanceExpression_andExpressionEvaluatesToFalse_repeatPromptIsSkipped',
    () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Repeat relevance same as other'),
                  model([
                    mainInstance([
                      t('data id="repeat_relevance_same_as_other"', [
                        tText('selectYesNo', 'no'),
                        t('repeat1', [t('q1')]),
                        t('q0'),
                      ]),
                    ]),
                    bind('/data/q0')..relevant("/data/selectYesNo = 'yes'"),
                    bind('/data/repeat1')
                      ..relevant("/data/selectYesNo = 'yes'"),
                  ]),
                ]),
                body([
                  select1('/data/selectYesNo', [
                    item('yes', 'Yes'),
                    item('no', 'No'),
                  ]),
                  repeat('/data/repeat1', [input('/data/repeat1/q1')]),
                ]),
              ),
            )
            ..jumpToBeginningOfForm()
            ..next();
      final event = scenario.next();

      expect(event, FormEntryEvent.endOfForm);
    },
  );

  /// The original ODK XForms spec deviated from XPath rules by stating that
  /// path expressions representing single nodes should be evaluated as
  /// relative to the current nodeset. That has since been removed and all
  /// known form builders create relative references in expressions within
  /// a repeat. We currently maintain this behavior for legacy purposes.
  test('absoluteSingleNodePaths_areQualified_forLegacyPurposes', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Absolute relative ref'),
                model([
                  mainInstance([
                    t('data id="data"', [
                      t('outer', [
                        t('outerq1'),
                        t('outercalcabs'),
                        t('outercalcrel'),
                        t('inner', [
                          t('innerq1'),
                          t('innercalcabs'),
                          t('innercalcrel'),
                        ]),
                      ]),
                    ]),
                  ]),
                  bind('/data/outer/outercalcabs')
                    ..calculate('/data/outer/outerq1 + 1'),
                  bind('/data/outer/outercalcrel')..calculate('../outerq1 + 1'),
                  bind('/data/outer/inner/innercalcabs')
                    ..calculate('/data/outer/inner/innerq1 + 2'),
                  bind('/data/outer/inner/innercalcrel')
                    ..calculate('../innerq1 + 2'),
                ]),
              ]),
              body([
                repeat('/data/outer', [
                  input('/data/outer/outerq1'),
                  repeat('/data/outer/inner', [
                    input('/data/outer/inner/innerq1'),
                  ]),
                ]),
              ]),
            ),
          )
          ..answer('/data/outer[1]/outerq1', '5');
    expect(
      scenario.answerOf('/data/outer[1]/outercalcabs'),
      const IntegerValue(6),
    );
    expect(
      scenario.answerOf('/data/outer[1]/outercalcrel'),
      const IntegerValue(6),
    );

    scenario
      ..createNewRepeat('/data/outer')
      ..answer('/data/outer[2]/outerq1', '23');
    // In a standards-compliant XPath engine, this would be 6 because
    // /data/outer/outerq1 in the calculate expression would always be
    // equivalent to /data/outer[1]/outerq1
    expect(
      scenario.answerOf('/data/outer[2]/outercalcabs'),
      const IntegerValue(24),
    );
    expect(
      scenario.answerOf('/data/outer[2]/outercalcrel'),
      const IntegerValue(24),
    );

    scenario.answer('/data/outer[1]/inner[1]/innerq1', 18);
    expect(
      scenario.answerOf('/data/outer[1]/inner[1]/innercalcabs'),
      const IntegerValue(20),
    );
    expect(
      scenario.answerOf('/data/outer[1]/inner[1]/innercalcrel'),
      const IntegerValue(20),
    );

    scenario
      ..createNewRepeat('/data/outer[1]/inner')
      ..answer('/data/outer[1]/inner[2]/innerq1', 19);
    // In a standards-compliant XPath engine, this would be 20 because
    // /data/outer/inner/innerq1 in the calculate expression would always be
    // equivalent to /data/outer[1]/inner[1]/innerq1
    expect(
      scenario.answerOf('/data/outer[1]/inner[2]/innercalcabs'),
      const IntegerValue(21),
    );
    expect(
      scenario.answerOf('/data/outer[1]/inner[2]/innercalcrel'),
      const IntegerValue(21),
    );
  });
}
