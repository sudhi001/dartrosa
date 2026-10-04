// Port of DateTimeWidgetUtilsTest.getDatePickerDetailsTest (ODK Collect).
import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:test/test.dart';

void main() {
  test('getDatePickerDetails', () {
    DatePickerDetails details(DatePickerType t, DatePickerMode m) =>
        DatePickerDetails(t, m);
    const g = DatePickerType.gregorian;
    expect(
      DatePickerDetails.fromAppearance(null),
      details(g, DatePickerMode.calendar),
    );
    final cases = {
      'something': details(g, DatePickerMode.calendar),
      'no-calendar': details(g, DatePickerMode.spinners),
      'NO-CALENDAR': details(g, DatePickerMode.spinners),
      'month-year': details(g, DatePickerMode.monthYear),
      'MONTH-year': details(g, DatePickerMode.monthYear),
      'year': details(g, DatePickerMode.year),
      'Year': details(g, DatePickerMode.year),
    };
    const calendars = {
      'ethiopian': DatePickerType.ethiopian,
      'coptic': DatePickerType.coptic,
      'islamic': DatePickerType.islamic,
      'bikram-sambat': DatePickerType.bikramSambat,
      'myanmar': DatePickerType.myanmar,
      'persian': DatePickerType.persian,
      'buddhist': DatePickerType.buddhist,
    };
    calendars.forEach((name, type) {
      final capitalized = name[0].toUpperCase() + name.substring(1);
      cases[name] = details(type, DatePickerMode.spinners);
      cases['$capitalized month-year'] = details(
        type,
        DatePickerMode.monthYear,
      );
      cases['month-year $name'] = details(type, DatePickerMode.monthYear);
      cases['$capitalized year'] = details(type, DatePickerMode.year);
      cases['year $name'] = details(type, DatePickerMode.year);
    });
    cases.forEach((appearance, expected) {
      expect(
        DatePickerDetails.fromAppearance(appearance),
        expected,
        reason: appearance,
      );
    });
  });

  test('calendar appearances are checked in Collect order', () {
    expect(
      DatePickerDetails.fromAppearance('persian ethiopian').type,
      DatePickerType.ethiopian,
    );
    expect(
      DatePickerDetails.fromAppearance('no-calendar coptic'),
      const DatePickerDetails(DatePickerType.coptic, DatePickerMode.spinners),
    );
  });
}
