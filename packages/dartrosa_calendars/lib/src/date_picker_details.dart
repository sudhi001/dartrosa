// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (DatePickerDetails), Copyright 2017 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

/// The calendar a date question's picker uses (Collect's
/// `DatePickerDetails.DatePickerType`).
enum DatePickerType {
  /// The Gregorian calendar (no calendar appearance).
  gregorian,

  /// `ethiopian`: Joda-Time's Ethiopic chronology.
  ethiopian,

  /// `coptic`: Joda-Time's Coptic chronology.
  coptic,

  /// `islamic`: Joda-Time's Islamic chronology (16-based leap years).
  islamic,

  /// `bikram-sambat`: Nepal's Bikram Sambat calendar.
  bikramSambat,

  /// `myanmar`: the Myanmar (Burmese) lunisolar calendar.
  myanmar,

  /// `persian`: the Persian (Solar Hijri) calendar.
  persian,

  /// `buddhist`: the Thai solar (Buddhist era) calendar.
  buddhist,
}

/// What a date question's picker lets the user choose (Collect's
/// `DatePickerDetails.DatePickerMode`).
enum DatePickerMode {
  /// A calendar (Gregorian only).
  calendar,

  /// Year, month and day spinners.
  spinners,

  /// `month-year`: year and month.
  monthYear,

  /// `year`: the year only.
  year,
}

/// The picker a date question uses: port of ODK Collect's
/// `org.odk.collect.android.widgets.datetime.DatePickerDetails` and of
/// `DateTimeWidgetUtils.getDatePickerDetails`.
@immutable
final class DatePickerDetails {
  /// Creates details for [type] and [mode].
  const DatePickerDetails(this.type, this.mode);

  /// The picker for a question with [appearance]
  /// (`DateTimeWidgetUtils.getDatePickerDetails`): the first calendar
  /// appearance found (in Collect's order) selects the calendar and the
  /// spinners; `month-year` or `year` restrict them.
  factory DatePickerDetails.fromAppearance(String? appearance) {
    var type = DatePickerType.gregorian;
    var mode = DatePickerMode.calendar;
    if (appearance != null) {
      final a = appearance.toLowerCase();
      for (final (name, calendar) in _calendarAppearances) {
        if (a.contains(name)) {
          type = calendar;
          mode = DatePickerMode.spinners;
          break;
        }
      }
      if (type == DatePickerType.gregorian && a.contains('no-calendar')) {
        mode = DatePickerMode.spinners;
      }
      if (a.contains('month-year')) {
        mode = DatePickerMode.monthYear;
      } else if (a.contains('year')) {
        mode = DatePickerMode.year;
      }
    }
    return DatePickerDetails(type, mode);
  }

  static const _calendarAppearances = [
    ('ethiopian', DatePickerType.ethiopian),
    ('coptic', DatePickerType.coptic),
    ('islamic', DatePickerType.islamic),
    ('bikram-sambat', DatePickerType.bikramSambat),
    ('myanmar', DatePickerType.myanmar),
    ('persian', DatePickerType.persian),
    ('buddhist', DatePickerType.buddhist),
  ];

  /// The calendar.
  final DatePickerType type;

  /// What can be picked.
  final DatePickerMode mode;

  /// `isCalendarMode`.
  bool get isCalendarMode => mode == DatePickerMode.calendar;

  /// `isSpinnerMode`.
  bool get isSpinnerMode => mode == DatePickerMode.spinners;

  /// `isMonthYearMode`.
  bool get isMonthYearMode => mode == DatePickerMode.monthYear;

  /// `isYearMode`.
  bool get isYearMode => mode == DatePickerMode.year;

  /// Whether the picker uses a non-Gregorian calendar.
  bool get isCustomCalendar => type != DatePickerType.gregorian;

  @override
  bool operator ==(Object other) =>
      other is DatePickerDetails && other.type == type && other.mode == mode;

  @override
  int get hashCode => Object.hash(type, mode);

  @override
  String toString() => 'DatePickerDetails(${type.name}, ${mode.name})';
}
