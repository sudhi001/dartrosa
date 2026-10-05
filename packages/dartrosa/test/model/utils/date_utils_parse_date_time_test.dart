// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DateUtilsParseDateTimeTests), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DateUtilsParseDateTimeTests.
//
// The Java test asserts under several default time zones (default, UTC,
// GMT+12, GMT-13, GMT+0230); the assertions are zone-independent, so here
// they run in the local zone and CI repeats the suite under those zones.
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  const cases = [
    ('2016-04-13T16:26:00.000', '2016-04-13T16:26:00.000'),
    ('2016-04-13T16:26:00.000-07', '2016-04-13T16:26:00.000-07:00'),
    ('2015-12-16T16:09:00.000-08', '2015-12-16T16:09:00.000-08:00'),
    ('2015-12-16T07:09:00.000+08', '2015-12-16T07:09:00.000+08:00'),
    ('2015-11-30T16:09:00.000-08', '2015-11-30T16:09:00.000-08:00'),
    ('2015-11-01T07:09:00.000+08', '2015-11-01T07:09:00.000+08:00'),
    ('2015-12-31T16:09:00.000-08', '2015-12-31T16:09:00.000-08:00'),
  ];
  for (final (input, expected) in cases) {
    test('parseDateTime($input)', () {
      final parsed = parseDateTime(input)!;
      // Dart's DateTime.parse reads a string without offset as local time,
      // like Java's LocalDateTime in the default zone.
      expect(
        parsed.millisecondsSinceEpoch,
        DateTime.parse(expected).millisecondsSinceEpoch,
      );
    });
  }
}
