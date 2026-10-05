// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (OptionalChoicesQuestionTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 OptionalChoicesQuestionTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

void main() {
  test('answerIsPreservedWhenQuestionHasIncompleteItemsetChoices', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title(),
          model([
            mainInstance([
              data([t('range')]),
            ]),
            instance('ticks', [item(-2, 'A'), item(0, 'B'), item(2, 'C')]),
            bind('/data/range')..type('int'),
          ]),
        ]),
        body([
          t('range ref="/data/range" start="-2" end="2" step="1"', [
            t(
              '''itemset nodeset="instance('ticks')/root/item"''',
              [t('label ref="label"'), t('value ref="value"')],
            ),
          ]),
        ]),
      ),
    );

    scenario
      ..answer('/data/range', 1)
      ..choicesOf('/data/range');
    expect(scenario.answerOf('/data/range'), intAnswer(1));
  });

  test('answerIsPreservedWhenQuestionHasIncompleteItemChoices', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title(),
          model([
            mainInstance([
              data([t('range')]),
            ]),
            bind('/data/range')..type('int'),
          ]),
        ]),
        body([
          t('range ref="/data/range" start="-2" end="2" step="1"', [
            item(-2, 'A'),
            item(0, 'B'),
            item(2, 'C'),
          ]),
        ]),
      ),
    );

    scenario
      ..answer('/data/range', 1)
      ..choicesOf('/data/range');
    expect(scenario.answerOf('/data/range'), intAnswer(1));
  });
}
