// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect, Copyright University of Washington, Nafundi and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of ODK Collect's instrumented DateTimeUtilsTest.getDateTimeLabelTest
// (Locale.ENGLISH), plus the labels of the picker dialog tests.
import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:test/test.dart';

void main() {
  const spinners = DatePickerMode.spinners;
  DatePickerDetails d(DatePickerType t, [DatePickerMode m = spinners]) =>
      DatePickerDetails(t, m);

  test('getDateTimeLabel', () {
    // 20 Oct 1991 14:00
    final date = DateTime(1991, 10, 20, 14);
    const gregorian = DatePickerDetails(
      DatePickerType.gregorian,
      DatePickerMode.calendar,
    );
    expect(dateTimeLabel(date, gregorian), 'Oct 20, 1991');
    expect(
      dateTimeLabel(date, gregorian, containsTime: true),
      'Oct 20, 1991, 14:00',
    );
    final expected = {
      DatePickerType.ethiopian: '9 Tikimt 1984',
      DatePickerType.coptic: '9 Paopi 1708',
      DatePickerType.islamic: "11 Rabi' al-thani 1412",
      DatePickerType.bikramSambat: '3 कार्तिक 2048',
      DatePickerType.myanmar: '12 သီတင်းကျွတ် 1353',
      DatePickerType.persian: '28 Mehr 1370',
      DatePickerType.buddhist: '20 ตุลาคม 2534',
    };
    expected.forEach((type, custom) {
      expect(dateTimeLabel(date, d(type)), '$custom (Oct 20, 1991)');
      expect(
        dateTimeLabel(date, d(type), containsTime: true),
        '$custom, 14:00 (Oct 20, 1991, 14:00)',
      );
    });
  });

  test('month-year and year modes', () {
    final date = DateTime(2020, 5, 12);
    expect(
      dateTimeLabel(
        date,
        d(DatePickerType.ethiopian, DatePickerMode.monthYear),
      ),
      'Ginbot 2012 (May 2020)',
    );
    expect(
      dateTimeLabel(date, d(DatePickerType.ethiopian, DatePickerMode.year)),
      '2012 (2020)',
    );
    expect(
      dateTimeLabel(DateTime(1904, 1, 6), d(DatePickerType.buddhist)),
      '6 มกราคม 2447 (Jan 06, 1904)',
    );
  });

  test('Bikram Sambat outside the library range has an empty custom text', () {
    expect(
      dateTimeLabel(DateTime(1900, 1, 1), d(DatePickerType.bikramSambat)),
      ' (Jan 01, 1900)',
    );
    // The library's truncating division maps the day before its epoch to
    // its first day.
    expect(
      dateTimeLabel(DateTime(1913, 4, 12), d(DatePickerType.bikramSambat)),
      '1 बैशाख 1970 (Apr 12, 1913)',
    );
  });

  test('custom formatter for the Gregorian part', () {
    expect(
      dateTimeLabel(
        DateTime(2020, 5, 12),
        d(DatePickerType.persian),
        formatGregorian: (date, details, {required containsTime}) => 'G',
      ),
      '23 Ordibehesht 1399 (G)',
    );
  });
}
