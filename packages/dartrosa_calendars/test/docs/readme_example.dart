// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim; run by
// api_examples_test.dart.
// ignore_for_file: avoid_print
import 'package:dartrosa_calendars/dartrosa_calendars.dart';

void main() {
  final date = DateTime(2024, 3, 20);
  final details = DatePickerDetails.fromAppearance('ethiopian');
  final calendar = CustomCalendar.of(details.type);
  print(calendar.fromGregorian(date)); // 11 Megabit 2016
  print(dateTimeLabel(date, details)); // 11 Megabit 2016 (Mar 20, 2024)
}
