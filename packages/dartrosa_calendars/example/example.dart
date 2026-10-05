// Shows a Gregorian date the way ODK Collect's `ethiopian` and
// `persian` date appearances do.
import 'package:dartrosa_calendars/dartrosa_calendars.dart';

void main() {
  final date = DateTime(2024, 3, 20);
  for (final appearance in ['ethiopian', 'persian month-year']) {
    final details = DatePickerDetails.fromAppearance(appearance);
    final calendar = CustomCalendar.of(details.type);
    _log('$appearance: ${calendar.fromGregorian(date)}');
    _log('  label: ${dateTimeLabel(date, details)}');
    _log('  years ${calendar.minYear}-${calendar.maxYear}');
  }
}

// ignore: avoid_print
void _log(Object? message) => print(message);
