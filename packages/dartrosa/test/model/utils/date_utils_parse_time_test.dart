// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DateUtilsParseTimeTests), Copyright (C) 2009 JavaRosa;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DateUtilsParseTimeTests.
//
// parseTime uses today's local date. The Java test asserts under several
// default time zones that the result reads back as the input time at the
// input's offset (or in local time without one); here it runs in the local
// zone and CI repeats the suite under those zones.
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  const cases = [
    ('14:00', null),
    ('14:00Z', Duration.zero),
    ('14:00+02', Duration(hours: 2)),
    ('14:00-02', Duration(hours: -2)),
    ('14:00+02:30', Duration(hours: 2, minutes: 30)),
    ('14:00-02:30', Duration(hours: -2, minutes: -30)),
  ];
  for (final (input, offset) in cases) {
    test('parseTime($input)', () {
      final parsed = parseTime(input)!;
      final wall = offset == null
          ? parsed.toLocal()
          : parsed.toUtc().add(offset);
      expect((wall.hour, wall.minute, wall.second), (14, 0, 0));
    });
  }
}
