// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The Scenario code of docs/cookbook/test-your-forms.md, run as tests so
// the recipe can't rot (doc_snippets.dart checks that its snippets are
// here; the session API part is in cookbook_test.dart).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart' hide AnswerResult;
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

XFormsElement waterForm() => html(
  head([
    title('Water'),
    model([
      mainInstance([
        t('data id="water"', [t('has_water'), t('source'), t('members')]),
      ]),
      bind('/data/source')..relevant("/data/has_water = 'yes'"),
      bind('/data/members')
        ..type('int')
        ..constraint('. > 0 and . < 30'),
    ]),
  ]),
  body([
    input('/data/has_water'),
    input('/data/source'),
    input('/data/members'),
  ]),
);

void main() {
  test('the constraint on members', () async {
    final scenario = await Scenario.init(waterForm());

    expect(
      scenario.answer('/data/members', 40),
      AnswerResult.constraintViolated,
    );
    expect(scenario.answer('/data/members', 4), AnswerResult.ok);
    expect(scenario.answerOf('/data/members'), const IntegerValue(4));
  });

  test('the source is skipped without water', () async {
    final scenario = await Scenario.init(waterForm());
    scenario.answer('/data/has_water', 'no');

    scenario.jumpToBeginningOfForm();
    scenario.next(); // has_water
    scenario.next(); // source is not relevant: members comes next
    expect(scenario.refAtIndex, getRef('/data/members[1]'));
  });
}
