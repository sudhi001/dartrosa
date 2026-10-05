// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa test pinning JavaRosa's dates before the Gregorian cutover:
// java.util's hybrid calendar reads them as Julian dates (and the ten
// skipped days of October 1582 leniently), year 0 is 1 BC and years are
// printed as years of the era. Expected values were captured from
// JavaRosa 6.0.0 (TZ=UTC); found by fuzzing Collect's validate.xml.
@TestOn('vm')
library;

import 'package:dartrosa/javarosa.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';

String eval(String xpath) {
  final v = parseXPath(xpath).eval(null, EvaluationContext(null));
  return v is double ? javaDoubleToString(v) : toXPathString(v);
}

void main() {
  const daysSinceEpoch = {
    '1-01-01': '-719164.0',
    '100-01-01': '-683005.0',
    '200-01-01': '-646480.0',
    '1000-01-01': '-354280.0',
    '1300-01-01': '-244705.0',
    '1500-01-01': '-171655.0',
    '1582-10-04': '-141428.0',
    // In the skipped days: read as Julian, i.e. 1582-10-20.
    '1582-10-10': '-141422.0',
    '1582-10-15': '-141427.0',
    '1583-01-01': '-141349.0',
    '1700-01-01': '-98615.0',
    // Year 0 is 1 BC.
    '0-01-01': '-719530.0',
  };
  for (final MapEntry(key: date, value: days) in daysSinceEpoch.entries) {
    test(
      'decimal-date-time($date)',
      skip: skipUnlessUtc,
      () => expect(eval("decimal-date-time('$date')"), days),
    );
  }

  test('dates print in the hybrid calendar', skip: skipUnlessUtc, () {
    expect(eval("string(date('1582-10-10'))"), '1582-10-20');
    expect(eval("string(date('1000-01-01'))"), '1000-01-01');
    // 1 BC is year 1 of its era.
    expect(eval("string(date('0-01-01'))"), '1-01-01');
  });
}
