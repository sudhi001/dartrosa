// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

import 'bikram_sambat.dart';
import 'date_picker_details.dart';
import 'gregorian.dart';
import 'joda/basic_chronology.dart';
import 'joda/islamic_chronology.dart';
import 'joda/persian_chronology.dart';
import 'myanmar/myanmar_calendar.dart';
import 'myanmar/myanmar_date_utils.dart';

/// A date in a non-Gregorian calendar, as ODK Collect shows it.
@immutable
final class CalendarDate {
  /// Creates the date.
  const CalendarDate({
    required this.year,
    required this.monthIndex,
    required this.day,
    required this.monthName,
  });

  /// The year.
  final int year;

  /// The month's position (0-based) in [CustomCalendar.monthNames] of
  /// [year].
  final int monthIndex;

  /// The day of the month.
  final int day;

  /// The month's name.
  final String monthName;

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.monthIndex == monthIndex &&
      other.day == day &&
      other.monthName == monthName;

  @override
  int get hashCode => Object.hash(year, monthIndex, day, monthName);

  @override
  String toString() => '$day $monthName $year';
}

/// A non-Gregorian calendar of ODK Collect's date widgets: conversion of
/// the Gregorian dates ODK stores, the month names and the year range
/// Collect's spinners offer, and the text Collect shows (ports of
/// `DateTimeWidgetUtils.getDateTimeLabel` and of the `*DatePickerDialog`
/// classes' constants).
///
/// ```dart
/// final calendar = CustomCalendar.of(DatePickerType.persian);
/// print(calendar.fromGregorian(DateTime(2024, 3, 20))); // 1 Farvardin 1403
/// print(calendar.monthNames(1403).first); // Farvardin
/// print('${calendar.minYear}-${calendar.maxYear}'); // 1278-1478
/// ```
sealed class CustomCalendar {
  const CustomCalendar._();

  /// The calendar of [type]; throws [ArgumentError] for
  /// [DatePickerType.gregorian].
  factory CustomCalendar.of(DatePickerType type) => switch (type) {
    DatePickerType.ethiopian => const JodaCalendar._(
      DatePickerType.ethiopian,
      EthiopicChronology(),
      1893, // 1900 in Gregorian calendar
      2093, // 2100 in Gregorian calendar
      ethiopianMonthNames,
    ),
    DatePickerType.coptic => const JodaCalendar._(
      DatePickerType.coptic,
      CopticChronology(),
      1617,
      1817,
      copticMonthNames,
    ),
    DatePickerType.islamic => const JodaCalendar._(
      DatePickerType.islamic,
      IslamicChronology(),
      1318,
      1524,
      islamicMonthNames,
    ),
    DatePickerType.persian => const JodaCalendar._(
      DatePickerType.persian,
      PersianChronologyKhayyamBorkowski(),
      1278,
      1478,
      persianMonthNames,
    ),
    DatePickerType.buddhist => const BuddhistCalendar._(),
    DatePickerType.bikramSambat => const BikramSambatCalendar._(),
    DatePickerType.myanmar => const MyanmarCalendar._(),
    DatePickerType.gregorian => throw ArgumentError.value(
      type,
      'type',
      'not a custom calendar',
    ),
  };

  /// The calendar.
  DatePickerType get type;

  /// The first year of the year spinner.
  int get minYear;

  /// The last year of the year spinner.
  int get maxYear;

  /// The month names the month spinner shows for [year].
  List<String> monthNames(int year);

  /// The date [date] (its year, month and day) falls on, or null where
  /// the calendar library does not support it (Bikram Sambat outside
  /// 1913-2033).
  CalendarDate? fromGregorian(DateTime date);

  /// The date shown before the Gregorian date in Collect's label
  /// (`customDateText` of `DateTimeWidgetUtils.getDateTimeLabel`): day,
  /// month name and year in spinner mode, month name and year in
  /// month-year mode, the year in year mode, followed by `, HH:mm` when
  /// [containsTime]. Empty where [fromGregorian] is null.
  String customDateText(
    DateTime date,
    DatePickerDetails details, {
    bool containsTime = false,
  }) {
    final c = fromGregorian(date);
    if (c == null) return '';
    final day = details.isSpinnerMode ? '${c.day} ' : '';
    final month = details.isSpinnerMode || details.isMonthYearMode
        ? '${c.monthName} '
        : '';
    final time = containsTime ? ', ${_hhmm(date)}' : '';
    return '$day$month${c.year}$time';
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hhmm(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

/// A calendar backed by a Joda-Time chronology (Ethiopian, Coptic,
/// Islamic, Persian), as Collect's `EthiopianDatePickerDialog`,
/// `CopticDatePickerDialog`, `IslamicDatePickerDialog` and
/// `PersianDatePickerDialog` use it.
final class JodaCalendar extends CustomCalendar {
  const JodaCalendar._(
    this.type,
    this.chronology,
    this.minYear,
    this.maxYear,
    this._monthNames,
  ) : super._();

  @override
  final DatePickerType type;

  /// The Joda chronology.
  final BasicChronology chronology;

  @override
  final int minYear;

  @override
  final int maxYear;

  final List<String> _monthNames;

  @override
  List<String> monthNames(int year) => _monthNames;

  @override
  CalendarDate fromGregorian(DateTime date) {
    final f = chronology.fieldsOf(epochDayOfDate(date));
    return CalendarDate(
      year: f.year,
      monthIndex: f.month - 1,
      day: f.day,
      monthName: _monthNames[f.month - 1],
    );
  }

  /// `localDateTime.dayOfMonth().getMaximumValue()` for the first day of
  /// [month] (1-based) of [year]: the last day the day spinner offers.
  int maximumDayOfMonth(int year, int month) =>
      chronology.maximumDayOfMonth(year, month);

  /// The Gregorian date (local midnight) of [day] [month] [year], as
  /// `DateTimeUtils.getDateAsGregorian` converts it.
  DateTime toGregorian(int year, int month, int day) =>
      localDateOf(chronology.epochDayOf(year, month, day));
}

/// The Buddhist (Thai solar) calendar of Collect's
/// `BuddhistDatePickerDialog` (Joda-Time's `BuddhistChronology`: the
/// Gregorian calendar with years counted from 543 BC).
final class BuddhistCalendar extends CustomCalendar {
  const BuddhistCalendar._() : super._();

  /// `BuddhistChronology.BUDDHIST_OFFSET`.
  static const offset = 543;

  @override
  DatePickerType get type => DatePickerType.buddhist;

  @override
  int get minYear => 2443; // 1900 in Gregorian calendar

  @override
  int get maxYear => 2643; // 2100 in Gregorian calendar

  @override
  List<String> monthNames(int year) => buddhistMonthNames;

  @override
  CalendarDate fromGregorian(DateTime date) => CalendarDate(
    year: date.year + offset,
    monthIndex: date.month - 1,
    day: date.day,
    monthName: buddhistMonthNames[date.month - 1],
  );

  /// The last day of [month] (1-based) of the Buddhist [year].
  int maximumDayOfMonth(int year, int month) =>
      gregorianDaysInMonth(year - offset, month);

  /// The Gregorian date (local midnight) of [day] [month] [year].
  DateTime toGregorian(int year, int month, int day) =>
      DateTime(year - offset, month, day);
}

/// Nepal's Bikram Sambat calendar of Collect's
/// `BikramSambatDatePickerDialog` (bikram-sambat 1.8.1's `BsCalendar`).
final class BikramSambatCalendar extends CustomCalendar {
  const BikramSambatCalendar._() : super._();

  /// The library.
  static const calendar = BsCalendar();

  @override
  DatePickerType get type => DatePickerType.bikramSambat;

  @override
  int get minYear => 1970; // 1913 in Gregorian calendar

  @override
  int get maxYear => 2090; // 2033 in Gregorian calendar

  @override
  List<String> monthNames(int year) => BsCalendar.monthNames;

  @override
  CalendarDate? fromGregorian(DateTime date) {
    try {
      final b = calendar.toBik(date.year, date.month, date.day);
      return CalendarDate(
        year: b.year,
        monthIndex: b.month - 1,
        day: b.day,
        monthName: BsCalendar.monthNames[b.month - 1],
      );
    } on BsException {
      return null;
    }
  }
}

/// The Myanmar calendar of Collect's `MyanmarDatePickerDialog`
/// (mmcalendar through Collect's `MyanmarDateUtils`): the months, and
/// so the month names, vary from year to year.
final class MyanmarCalendar extends CustomCalendar {
  const MyanmarCalendar._() : super._();

  @override
  DatePickerType get type => DatePickerType.myanmar;

  @override
  int get minYear => 1261; // 1900 in Gregorian calendar

  @override
  int get maxYear => 1462; // 2100 in Gregorian calendar

  @override
  List<String> monthNames(int year) =>
      MyanmarDateUtils.getMyanmarMonthsArray(year);

  @override
  CalendarDate fromGregorian(DateTime date) =>
      fromMyanmarDate(myanmarDateOfWestern(date.year, date.month, date.day));

  /// The picker's view of [date].
  CalendarDate fromMyanmarDate(MyanmarDate date) => CalendarDate(
    year: date.year,
    monthIndex: MyanmarDateUtils.getMonthId(date),
    day: date.dayOfMonth,
    monthName: date.monthName,
  );
}

/// Collect's `R.array.ethiopian_months`.
const ethiopianMonthNames = [
  'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit', //
  'Miazia', 'Ginbot', 'Senie', 'Hamlie', 'Nehasie', 'Pagumien',
];

/// Collect's `R.array.coptic_months`.
const copticMonthNames = [
  'Thout', 'Paopi', 'Hathor', 'Koiak', 'Tobi', 'Meshir', 'Paremhat', //
  'Parmouti', 'Pashons', 'Paoni', 'Epip', 'Mesori', 'Pi Kogi Enavot',
];

/// Collect's `R.array.islamic_months`.
const islamicMonthNames = [
  'Muharram', 'Safar', "Rabi' al-awwal", "Rabi' al-thani", //
  'Jumada al-awwal', 'Jumada al-thani', 'Rajab', "Sha'ban", 'Ramadan',
  'Shawwal', 'Dhu al-Qidah', 'Dhu al-Hijjah',
];

/// Collect's `R.array.persian_months`.
const persianMonthNames = [
  'Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', //
  'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand',
];

/// Collect's `R.array.buddhist_months`.
const buddhistMonthNames = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', //
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
