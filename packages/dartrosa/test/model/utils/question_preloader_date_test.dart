// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports) of `jr:preload="date"` with
// `jr:preloadParams="prevperiod-..."` and unknown preload types. JavaRosa
// has no tests for these; dates were captured from JavaRosa 6.0.0 (jshell,
// DateUtils.getPastPeriodDate with the same reference time and the
// parameter parsing of QuestionPreloader.preloadDate), in UTC.
@TestOn('vm')
library;

import 'package:clock/clock.dart';
import 'package:dartrosa/src/model/utils/question_preloader.dart';
import 'package:test/test.dart';

String? preload(String params) => withClock(
  Clock.fixed(DateTime.utc(2024, 5, 15, 10)),
  () => QuestionPreloader().getQuestionPreload('date', params),
)?.uncast().string;

void main() {
  test('previous period starts and ends', () {
    expect(preload('prevperiod-week-sun-head'), '2024-05-05');
    expect(preload('prevperiod-week-sun-tail'), '2024-05-11');
    expect(preload('prevperiod-week-wed-head'), '2024-05-08');
    expect(preload('prevperiod-week-wed-head-x'), '2024-05-08');
    expect(preload('prevperiod-week-mon-head--3'), '2024-04-22');
    expect(preload('prevperiod-week-sat-tail-x-0'), '2024-05-17');
    expect(preload('today'), '2024-05-15');
  });

  test('invalid parameters', () {
    final invalid = throwsA(
      isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        "invalid preload params for preload mode 'date'",
      ),
    );
    expect(() => preload('prevperiod-week-sun-middle'), invalid);
    expect(() => preload('prevperiod-week-sun-head-y'), invalid);
    expect(() => preload('prevperiod-week-sun-head-x-many'), invalid);
    expect(() => preload('prevperiod-year-sun-head'), invalid);
    expect(() => preload('prevperiod-week-xyz-head'), invalid);
    // Months aren't implemented: JavaRosa gets a null date.
    expect(() => preload('prevperiod-month-sun-head'), invalid);
    expect(() => preload('yesterday!!'), invalid);
  });

  test('unknown preload types give nothing', () {
    final preloader = QuestionPreloader();
    expect(preloader.getQuestionPreload('nope', null), isNull);
  });
}
