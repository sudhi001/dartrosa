// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

void main() {
  test('library: dartrosa_calendars', () {
    expect(() {
      final details = DatePickerDetails.fromAppearance('ethiopian');
      final calendar = CustomCalendar.of(details.type);
      final date = DateTime(2024, 3, 20);
      print(calendar.fromGregorian(date)); // 11 Megabit 2016
      print(dateTimeLabel(date, details)); // 11 Megabit 2016 (Mar 20, 2024)
    }, prints('11 Megabit 2016\n11 Megabit 2016 (Mar 20, 2024)\n'));
  });

  test('CustomCalendar', () {
    expect(() {
      final calendar = CustomCalendar.of(DatePickerType.persian);
      print(calendar.fromGregorian(DateTime(2024, 3, 20))); // 1 Farvardin 1403
      print(calendar.monthNames(1403).first); // Farvardin
      print('${calendar.minYear}-${calendar.maxYear}'); // 1278-1478
    }, prints('1 Farvardin 1403\nFarvardin\n1278-1478\n'));
  });

  test('README example', () {
    expect(readme.main, prints(contains('11 Megabit 2016')));
  });

  test('example/example.dart', () {
    expect(example.main, prints(contains('persian month-year')));
  });
}
