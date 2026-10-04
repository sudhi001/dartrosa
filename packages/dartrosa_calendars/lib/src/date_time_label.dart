import 'custom_calendar.dart';
import 'date_picker_details.dart';

/// Formats the Gregorian part of a date label.
typedef GregorianDateFormatter =
    String Function(
      DateTime date,
      DatePickerDetails details, {
      required bool containsTime,
    });

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

String _year(int y) => y.toString().padLeft(4, '0');

/// The Gregorian date as Collect shows it in English
/// (`getGregorianDateTimeLabel` with `Locale.ENGLISH`/`en_US`, where
/// Android's best patterns for its skeletons are `MMM dd, yyyy`,
/// `MMM dd, yyyy, HH:mm`, `MMM yyyy` and `yyyy`).
String formatGregorianDateEnglish(
  DateTime date,
  DatePickerDetails details, {
  required bool containsTime,
}) {
  final month = _shortMonths[date.month - 1];
  if (details.isMonthYearMode) return '$month ${_year(date.year)}';
  if (details.isYearMode) return _year(date.year);
  final day = '$month ${_two(date.day)}, ${_year(date.year)}';
  return containsTime ? '$day, ${_two(date.hour)}:${_two(date.minute)}' : day;
}

/// The text Collect shows for [date] in a date (or, with [containsTime],
/// date-time) widget with [details]: port of
/// `DateTimeWidgetUtils.getDateTimeLabel`. For a custom calendar it is
/// `custom (gregorian)` (Collect's `custom_date` string, `%1$s (%2$s)`);
/// for the Gregorian calendar just the Gregorian date. [formatGregorian]
/// formats the Gregorian part (Collect uses the device locale; the default
/// is its English output).
String dateTimeLabel(
  DateTime date,
  DatePickerDetails details, {
  bool containsTime = false,
  GregorianDateFormatter formatGregorian = formatGregorianDateEnglish,
}) {
  final gregorian = formatGregorian(date, details, containsTime: containsTime);
  if (!details.isCustomCalendar) return gregorian;
  final custom = CustomCalendar.of(
    details.type,
  ).customDateText(date, details, containsTime: containsTime);
  return '$custom ($gregorian)';
}
