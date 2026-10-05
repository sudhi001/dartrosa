// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (CustomDatePickerDialog, EthiopianDatePickerDialog),
//  Copyright 2017 Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'bikram_sambat.dart';
import 'custom_calendar.dart';
import 'date_picker_details.dart';
import 'date_time_label.dart';
import 'gregorian.dart';
import 'myanmar/myanmar_calendar.dart';
import 'myanmar/myanmar_date_utils.dart';

/// The value logic of an Android `NumberPicker` (API 29+), which Collect's
/// custom date pickers rely on: setting the bounds clamps the value, and
/// setting a value outside the bounds wraps it around when the wheel
/// wraps (more than three values) or clamps it otherwise.
final class NumberPickerState {
  /// Creates a picker whose bounds and value are 0.
  NumberPickerState();

  int _min = 0;
  int _max = 0;
  int _value = 0;

  /// `getDisplayedValues()` / `setDisplayedValues`: the labels of the
  /// values, if any.
  List<String>? displayedValues;

  /// `getMinValue()`.
  int get minValue => _min;

  /// `getMaxValue()`.
  int get maxValue => _max;

  /// `getValue()`.
  int get value => _value;

  bool get _wraps => _max - _min >= 3; // SELECTOR_WHEEL_ITEM_COUNT

  /// `setMinValue`.
  set minValue(int min) {
    _min = min;
    if (_min > _value) _value = _min;
  }

  /// `setMaxValue`.
  set maxValue(int max) {
    _max = max;
    if (_max < _value) _value = _max;
  }

  /// `setValue`.
  set value(int value) {
    if (_value == value) return;
    var current = value;
    if (_wraps) {
      // getWrappedSelectorIndex
      if (current > _max) {
        current = _min + (current - _max) % (_max - _min) - 1;
      } else if (current < _min) {
        current = _max - (_min - current) % (_max - _min) + 1;
      }
    } else {
      if (current < _min) current = _min;
      if (current > _max) current = _max;
    }
    _value = current;
  }

  /// The label of the current value.
  String get label => displayedValues?[_value] ?? '$_value';
}

/// The state of ODK Collect's custom-calendar date picker dialog: port of
/// `CustomDatePickerDialog` and its subclasses (`EthiopianDatePickerDialog`,
/// `CopticDatePickerDialog`, `IslamicDatePickerDialog`,
/// `BikramSambatDatePickerDialog`, `MyanmarDatePickerDialog`,
/// `PersianDatePickerDialog`, `BuddhistDatePickerDialog`).
///
/// The dialog has year, month and day spinners ([yearPicker],
/// [monthPicker], [dayPicker]); the day spinner is hidden in month-year
/// mode, and the month spinner too in year mode, in which case they keep
/// whatever value their bounds give them (so month-year mode saves the
/// first offered day of the month, and year mode the first offered day of
/// the first month). Call [setDay], [setMonth] and [setYear] as the user
/// turns the spinners; [gregorianDate] is what OK saves.
sealed class CustomDatePickerModel {
  /// The picker for [details] (a custom calendar), showing [date] (a
  /// Gregorian date; its time of day is ignored).
  factory CustomDatePickerModel(DatePickerDetails details, DateTime date) =>
      switch (CustomCalendar.of(details.type)) {
        final JodaCalendar c => _JodaPickerModel(details, date, c),
        final BuddhistCalendar c => _BuddhistPickerModel(details, date, c),
        final BikramSambatCalendar c => _BikramSambatPickerModel(
          details,
          date,
          c,
        ),
        final MyanmarCalendar c => _MyanmarPickerModel(details, date, c),
      };

  CustomDatePickerModel._(this.details, DateTime date) : _initialDate = date {
    _setUpDatePicker();
  }

  /// The picker's calendar and mode.
  final DatePickerDetails details;

  /// The date the dialog was opened with (`viewModel.getLocalDateTime()`).
  final DateTime _initialDate;

  /// The day spinner.
  final dayPicker = NumberPickerState();

  /// The month spinner (values are month positions, labelled with the
  /// month names).
  final monthPicker = NumberPickerState();

  /// The year spinner.
  final yearPicker = NumberPickerState();

  /// The calendar.
  CustomCalendar get calendar;

  /// Whether the day spinner is shown (`hidePickersIfNeeded`).
  bool get showsDay => !details.isMonthYearMode && !details.isYearMode;

  /// Whether the month spinner is shown.
  bool get showsMonth => !details.isYearMode;

  /// `getDay()`.
  int get day => dayPicker.value;

  /// `getMonthId()`.
  int get monthId => monthPicker.value;

  /// `getYear()`.
  int get year => yearPicker.value;

  /// The user turned the day spinner to [value].
  // ignore: use_setters_to_change_properties
  void setDay(int value) {
    dayPicker.value = value;
  }

  /// The user turned the month spinner to position [value].
  void setMonth(int value) {
    monthPicker.value = value;
    _monthUpdated();
  }

  /// The user turned the year spinner to [value].
  void setYear(int value) {
    yearPicker.value = value;
    _yearUpdated();
  }

  /// The Gregorian date (local midnight) the spinners show, which OK saves
  /// (`DateTimeUtils.getDateAsGregorian(getOriginalDate())`); null where
  /// the calendar library cannot convert it (Collect crashes there).
  DateTime? get gregorianDate;

  /// The text under the spinners (`updateGregorianDateLabel`): Collect's
  /// label for [gregorianDate].
  String label({
    GregorianDateFormatter formatGregorian = formatGregorianDateEnglish,
  }) {
    final date = gregorianDate;
    if (date == null) return '';
    return dateTimeLabel(date, details, formatGregorian: formatGregorian);
  }

  /// `getDate()`: the dialog's date while the day spinner is unset.
  DateTime get _date => day == 0 ? _initialDate : gregorianDate!;

  void _setUpDatePicker();

  void _updateDays();

  void _monthUpdated() => _updateDays();

  void _yearUpdated() => _updateDays();

  /// `setUpDayPicker(minDay, dayOfMonth, daysInMonth)`.
  void _setUpDayPicker(int minDay, int dayOfMonth, int daysInMonth) {
    dayPicker
      ..minValue = minDay
      ..maxValue = daysInMonth;
    if (details.isSpinnerMode) dayPicker.value = dayOfMonth;
  }

  /// `setUpMonthPicker(monthOfYear, monthsArray)`.
  void _setUpMonthPicker(int monthOfYear, List<String> monthsArray) {
    monthPicker
      ..displayedValues = null
      ..maxValue = monthsArray.length - 1
      ..displayedValues = monthsArray;
    if (!details.isYearMode) monthPicker.value = monthOfYear - 1;
  }

  /// `setUpYearPicker(year, minSupportedYear, maxSupportedYear)`.
  void _setUpYearPicker(int year) {
    yearPicker
      ..minValue = calendar.minYear
      ..maxValue = calendar.maxYear
      ..value = year;
  }
}

/// Ethiopian, Coptic, Islamic and Persian pickers.
final class _JodaPickerModel extends CustomDatePickerModel {
  _JodaPickerModel(super.details, super.date, this.calendar) : super._();

  @override
  final JodaCalendar calendar;

  @override
  void _setUpDatePicker() {
    final c = calendar.chronology;
    final epochDay = epochDayOfDate(_date);
    final f = c.fieldsOf(epochDay);
    _setUpDayPicker(1, f.day, c.daysInMonthMaxAt(epochDay * millisPerDay));
    _setUpMonthPicker(f.month, calendar.monthNames(f.year));
    _setUpYearPicker(f.year);
  }

  /// `getCurrentXDate()`: the spinners' date, the day clamped to the month.
  (int, int, int) _current() {
    final month = monthId + 1;
    final max = calendar.maximumDayOfMonth(year, month);
    final d = day > max ? max : (day < 1 ? 1 : day);
    return (year, month, d);
  }

  @override
  void _updateDays() {
    final (y, m, d) = _current();
    final c = calendar.chronology;
    _setUpDayPicker(1, d, c.daysInMonthMaxAt(c.yearMonthDayMillis(y, m, d)));
  }

  @override
  DateTime get gregorianDate {
    final (y, m, d) = _current();
    return calendar.toGregorian(y, m, d);
  }
}

/// The Buddhist picker.
final class _BuddhistPickerModel extends CustomDatePickerModel {
  _BuddhistPickerModel(super.details, super.date, this.calendar) : super._();

  @override
  final BuddhistCalendar calendar;

  @override
  void _setUpDatePicker() {
    final b = calendar.fromGregorian(_date);
    _setUpDayPicker(
      1,
      b.day,
      calendar.maximumDayOfMonth(b.year, b.monthIndex + 1),
    );
    _setUpMonthPicker(b.monthIndex + 1, calendar.monthNames(b.year));
    _setUpYearPicker(b.year);
  }

  (int, int, int) _current() {
    final month = monthId + 1;
    final max = calendar.maximumDayOfMonth(year, month);
    return (year, month, day > max ? max : day);
  }

  @override
  void _updateDays() {
    final (y, m, d) = _current();
    _setUpDayPicker(1, d, calendar.maximumDayOfMonth(y, m));
  }

  @override
  DateTime get gregorianDate {
    final (y, m, d) = _current();
    return calendar.toGregorian(y, m, d);
  }
}

/// The Bikram Sambat picker.
final class _BikramSambatPickerModel extends CustomDatePickerModel {
  _BikramSambatPickerModel(super.details, super.date, this.calendar)
    : super._();

  @override
  final BikramSambatCalendar calendar;

  BsCalendar get _bs => BikramSambatCalendar.calendar;

  @override
  void _setUpDatePicker() {
    final date = _date;
    try {
      final b = _bs.toBik(date.year, date.month, date.day);
      _setUpDayPicker(1, b.day, _bs.daysInMonth(b.year, b.month));
      _setUpMonthPicker(b.month, BsCalendar.monthNames);
      _setUpYearPicker(b.year);
    } on BsException {
      // Collect logs the error and leaves the spinners as they are.
    }
  }

  @override
  void _updateDays() {
    var daysInMonth = 0;
    try {
      daysInMonth = _bs.daysInMonth(year, monthId + 1);
    } on BsException {
      // Collect logs the error.
    }
    _setUpDayPicker(1, day, daysInMonth);
  }

  @override
  DateTime? get gregorianDate {
    try {
      return localDateOf(
        _bs.toGregorianEpochDay((year: year, month: monthId + 1, day: day)),
      );
    } on BsException {
      return null;
    }
  }
}

/// The Myanmar picker, whose month spinner changes with the year.
final class _MyanmarPickerModel extends CustomDatePickerModel {
  _MyanmarPickerModel(super.details, super.date, this.calendar) : super._();

  @override
  final MyanmarCalendar calendar;

  void _setUpFor(MyanmarDate md) {
    _setUpDayPicker(
      MyanmarDateUtils.getFirstMonthDay(md),
      md.dayOfMonth,
      MyanmarDateUtils.getMonthLength(md),
    );
  }

  @override
  void _setUpDatePicker() {
    final md = MyanmarDateUtils.gregorianDateToMyanmarDate(
      epochDayOfDate(_date),
    );
    _setUpFor(md);
    _setUpMonthPicker(
      MyanmarDateUtils.getMonthId(md) + 1,
      MyanmarDateUtils.getMyanmarMonthsArray(md.year),
    );
    _setUpYearPicker(md.year);
  }

  /// `getCurrentMyanmarDate()`.
  MyanmarDate _current() {
    final monthIndexes = MyanmarDateUtils.getMonthIndexes(year);
    final monthIndex = monthId < monthIndexes.length
        ? monthIndexes[monthId]
        : monthIndexes.last;
    final monthLength = MyanmarDateUtils.getMonthLengthOf(year, monthIndex);
    final dayOfMonth = day > monthLength ? monthLength : day;
    return MyanmarDateUtils.createMyanmarDate(year, monthIndex, dayOfMonth);
  }

  @override
  void _updateDays() => _setUpFor(_current());

  @override
  void _yearUpdated() {
    final md = _current();
    _setUpMonthPicker(
      MyanmarDateUtils.getMonthId(md) + 1,
      MyanmarDateUtils.getMyanmarMonthsArray(md.year),
    );
    super._yearUpdated();
  }

  @override
  DateTime get gregorianDate =>
      localDateOf(MyanmarDateUtils.myanmarDateToGregorianDate(_current()));
}
