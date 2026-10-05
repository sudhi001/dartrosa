// Copyright 2026 The DartRosa Authors
// Derived from bikram-sambat (BsCalendar), Copyright Medic Mobile and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'gregorian.dart';

/// A Bikram Sambat date (`bikramsambat.BikramSambatDate`).
typedef BikramSambatDate = ({int year, int month, int day});

/// Thrown where `bikramsambat.BsCalendar` throws `BsException`: a date
/// outside the years the library encodes (1970-2090 BS) or an invalid
/// month or day.
final class BsException implements Exception {
  /// Creates the exception.
  const BsException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'BsException: $message';
}

/// Port of `bikramsambat.BsCalendar` from bikram-sambat 1.8.1
/// (github.com/medic/bikram-sambat, the jar ODK Collect bundles in
/// `collect_app/libs`): Nepal's official calendar, from a table of month
/// lengths for 1970-2090 BS.
final class BsCalendar {
  /// The calendar (`BsCalendar.getInstance()`).
  const BsCalendar();

  // Our own epoch for Bikram Sambat: 1970-1-1 BS, 1913-4-13 AD at 00:00
  // in Nepal (+05:30).
  static const _bsEpochTs = -1789990200000;
  static const _bsYearZero = 1970;

  /// `ENCODED_MONTH_LENGTHS`: per year, two bits per month holding the
  /// month length minus 29.
  static const _encodedMonthLengths = [
    5315258, 5314490, 9459438, 8673005, 5315258, 5315066, 9459438, 8673005, //
    5315258, 5314298, 9459438, 5327594, 5315258, 5314298, 9459438, 5327594,
    5315258, 5314286, 9459438, 5315306, 5315258, 5314286, 8673006, 5315306,
    5315258, 5265134, 8673006, 5315258, 5315258, 9459438, 8673005, 5315258,
    5314298, 9459438, 8673005, 5315258, 5314298, 9459438, 8473322, 5315258,
    5314298, 9459438, 5327594, 5315258, 5314298, 9459438, 5327594, 5315258,
    5314286, 8673006, 5315306, 5315258, 5265134, 8673006, 5315306, 5315258,
    9459438, 8673005, 5315258, 5314490, 9459438, 8673005, 5315258, 5314298,
    9459438, 8473325, 5315258, 5314298, 9459438, 5327594, 5315258, 5314298,
    9459438, 5327594, 5315258, 5314286, 9459438, 5315306, 5315258, 5265134,
    8673006, 5315306, 5315258, 5265134, 8673006, 5315258, 5314490, 9459438,
    8673005, 5315258, 5314298, 9459438, 8669933, 5315258, 5314298, 9459438,
    8473322, 5315258, 5314298, 9459438, 5327594, 5315258, 5314286, 9459438,
    5315306, 5315258, 5265134, 8673006, 5315306, 5315258, 5265134, 8673006,
    5315258, 5315258, 5527226, 5528046, 5527277, 5528250, 5528057, 5527277,
    5527277,
  ];

  /// `BsCalendar.MONTH_NAMES`, the names Collect's picker and label show.
  static const monthNames = [
    'बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज', //
    'कार्तिक', 'मंसिर', 'पौष', 'माघ', 'फाल्गुन', 'चैत',
  ];

  /// `daysInMonth`. Throws [BsException] for an unsupported year or month.
  int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw BsException('Month does not exist: $month');
    }
    final index = year - _bsYearZero;
    if (index < 0 || index >= _encodedMonthLengths.length) {
      throw BsException('Unsupported year/month combination: $year/$month');
    }
    // 29 + ((encoded >>> ((month - 1) << 1)) & 3), without bit operations
    // on values that may exceed 32 bits on the web.
    var encoded = _encodedMonthLengths[index];
    for (var i = 1; i < month; i++) {
      encoded ~/= 4;
    }
    return 29 + encoded % 4;
  }

  /// `toGreg`: the Gregorian day (days since 1970-01-01) of [bik]. Throws
  /// [BsException] for an invalid or unsupported date.
  int toGregorianEpochDay(BikramSambatDate bik) {
    var year = bik.year, month = bik.month;
    final day = bik.day;
    if (month < 1) throw BsException('Invalid month value $month');
    if (year < _bsYearZero) throw BsException('Invalid year value $year');
    if (day < 1 || day > daysInMonth(year, month)) {
      throw BsException('Invalid day value $day');
    }
    var timestamp = _bsEpochTs + millisPerDay * day;
    month--;
    while (year >= _bsYearZero) {
      while (month > 0) {
        timestamp += millisPerDay * daysInMonth(year, month);
        month--;
      }
      month = 12;
      year--;
    }
    // Calendar.getInstance(GMT).setTimeInMillis(timestamp)
    return floorDiv(timestamp, millisPerDay);
  }

  /// `toBik(year, month, day)` for a Gregorian date. Throws [BsException]
  /// outside the supported range.
  BikramSambatDate toBik(int year, int month, int day) {
    var y = _bsYearZero;
    // (int) Math.floor((parseDate(greg) - BS_EPOCH_TS) / MS_PER_DAY) + 1,
    // where the division is Java's truncating long division.
    var days =
        (epochDayOf(year, month, day) * millisPerDay - _bsEpochTs) ~/
            millisPerDay +
        1;
    while (days > 0) {
      for (var m = 1; m <= 12; ++m) {
        final dM = daysInMonth(y, m);
        if (days <= dM) return (year: y, month: m, day: days);
        days -= dM;
      }
      ++y;
    }
    throw BsException('Date outside supported range: $year-$month-$day AD');
  }
}
