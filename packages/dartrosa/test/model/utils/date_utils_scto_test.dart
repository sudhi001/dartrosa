// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DateUtilsSCTOTests), Copyright (C) 2012-14 Dobility,
//  Inc.; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DateUtilsSCTOTests. The Java tests set the
// default zone; these run when the local zone matches (CI sets TZ).
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

import 'zone_helpers.dart';

void main() {
  final october2014 = DateTime(2014, 10, 5);

  test('parseDateTime in GMT+02', () {
    final date = parseDateTime('2014-10-05T00:03:05.244+03');
    expect(
      formatDateTime(date, DateFormatStyle.iso8601),
      '2014-10-04T23:03:05.244+02:00',
    );
  }, skip: skipUnlessFixedOffset(const Duration(hours: 2), october2014));

  // Java uses a SimpleTimeZone with a +2 raw offset and DST all year, i.e.
  // a constant +3; a fixed +3 zone is equivalent for this test.
  test('parseDateTime with DST', () {
    final date = parseDateTime('2014-10-05T00:03:05.244+03');
    expect(
      formatDateTime(date, DateFormatStyle.iso8601),
      '2014-10-05T00:03:05.244+03:00',
    );
  }, skip: skipUnlessFixedOffset(const Duration(hours: 3), october2014));

  test('parseTime in GMT+02', () {
    final date = parseTime('12:03:05.011+03');
    expect(formatTime(date, DateFormatStyle.iso8601), '11:03:05.011+02:00');
  }, skip: skipUnlessFixedOffset(const Duration(hours: 2), DateTime.now()));

  test(
    'parseTime with DST',
    () {},
    skip:
        'Ignored in JavaRosa: a time has no offset or zone until bound to a '
        'date, so the expectation does not make sense',
  );
}
