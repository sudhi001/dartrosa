// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// Integer arithmetic on proleptic Gregorian dates, shared by the calendar
/// ports. Works identically on the VM and on the web (no bit operations,
/// no values beyond 2^53).
library;

/// Milliseconds in a day.
const millisPerDay = 86400000;

/// Floor division (Java's `Math.floorDiv`), for any sign of [a].
int floorDiv(int a, int b) => (a - a % b) ~/ b;

/// Whether [year] is a Gregorian leap year.
bool isGregorianLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

/// The number of days of [month] (1-12) in the Gregorian [year].
int gregorianDaysInMonth(int year, int month) => switch (month) {
  2 => isGregorianLeapYear(year) ? 29 : 28,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

/// Days since 1970-01-01 of the proleptic Gregorian date.
int epochDayOf(int year, int month, int day) {
  // Howard Hinnant's days_from_civil.
  final y = month <= 2 ? year - 1 : year;
  final era = floorDiv(y, 400);
  final yoe = y - era * 400;
  final mp = (month + 9) % 12;
  final doy = (153 * mp + 2) ~/ 5 + day - 1;
  final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
  return era * 146097 + doe - 719468;
}

/// The proleptic Gregorian `(year, month, day)` of [epochDay].
({int year, int month, int day}) civilOf(int epochDay) {
  final z = epochDay + 719468;
  final era = floorDiv(z, 146097);
  final doe = z - era * 146097;
  final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
  final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
  final mp = (5 * doy + 2) ~/ 153;
  final day = doy - (153 * mp + 2) ~/ 5 + 1;
  final month = mp < 10 ? mp + 3 : mp - 9;
  final year = yoe + era * 400 + (month <= 2 ? 1 : 0);
  return (year: year, month: month, day: day);
}

/// Days since 1970-01-01 of the calendar date of [date] (its year, month
/// and day fields, whatever its time zone).
int epochDayOfDate(DateTime date) =>
    epochDayOf(date.year, date.month, date.day);

/// Local midnight of [epochDay], the way ODK stores a date.
DateTime localDateOf(int epochDay) {
  final c = civilOf(epochDay);
  return DateTime(c.year, c.month, c.day);
}
