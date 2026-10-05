// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (CurrentGroupCountRefTest), Copyright 2018 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 CurrentGroupCountRefTest.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';
import '../../support/matchers.dart';

void main() {
  late Scenario scenario;
  setUp(
    () async => scenario = await scenarioFor(
      'relative-current-ref-group-count-ref.xml',
    ),
  );

  test('current_in_repeat_count_should_work_as_expected', () {
    // Since the form sets a count of 3 repeats, we should be at the end of
    // the form after answering three times
    scenario
      ..next()
      ..next()
      ..answerCurrent('Janet')
      ..next()
      ..next()
      ..answerCurrent('Bob')
      ..next()
      ..next()
      ..answerCurrent('Kim')
      ..next();

    expect(scenario.answerOf('/data/my_group[1]/name'), stringAnswer('Janet'));
    expect(scenario.answerOf('/data/my_group[2]/name'), stringAnswer('Bob'));
    expect(scenario.answerOf('/data/my_group[3]/name'), stringAnswer('Kim'));
    expect(scenario.atTheEndOfForm, isTrue);
    expect(scenario.countRepeatInstancesOf('/data/my_group'), 3);
  });
}
