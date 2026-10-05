// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (TimeDataLimitationsTest), Copyright (C) 2009 JavaRosa
//  and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 TimeDataLimitationsTest. Dart can't change the
// time zone inside a process, so each half runs when the suite runs under
// TZ=Europe/Warsaw or TZ=Europe/Kiev (both are in the CI time-zone loop).
import 'dart:io';

import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  final tz = Platform.environment['TZ'];
  final inWarsaw = tz == 'Europe/Warsaw';
  final inKiev = tz == 'Europe/Kiev' || tz == 'Europe/Kyiv';

  // Warsaw and Kyiv change to summer time at the same instant, so the
  // offset saved in Warsaw "now" follows the local summer-time state.
  String savedInWarsaw() {
    final now = DateTime.now();
    final summer = now.timeZoneOffset != DateTime(now.year).timeZoneOffset;
    return summer ? '10:00:00.000+02:00' : '10:00:00.000+01:00';
  }

  test('editing forms saved in a different time zone (Warsaw)', () {
    expect(TimeValue(parseTime(savedInWarsaw())!).displayText, '10:00');
  }, skip: inWarsaw ? null : 'runs with TZ=Europe/Warsaw');

  test('editing forms saved in a different time zone (Kyiv)', () {
    expect(TimeValue(parseTime(savedInWarsaw())!).displayText, '11:00');
  }, skip: inKiev ? null : 'runs with TZ=Europe/Kiev');

  test('editing forms saved in the same location after a DST change', () {
    const saved = '10:00:00.000+02:00';
    expect(
      TimeValue(
        parseTimeWithFixedDate(
          saved,
          const DateFields(year: 2019, month: 8, day: 1),
        )!,
      ).displayText,
      '10:00',
    );
    expect(
      TimeValue(
        parseTimeWithFixedDate(
          saved,
          const DateFields(year: 2019, month: 12, day: 1),
        )!,
      ).displayText,
      '09:00',
    );
  }, skip: inWarsaw ? null : 'runs with TZ=Europe/Warsaw');
}
