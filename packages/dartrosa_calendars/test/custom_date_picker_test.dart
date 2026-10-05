// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Ports of ODK Collect's *DatePickerDialogTest classes (the dialog opens
// on 2020-05-12) and of BuddhistDatePickerDialogTest, against the picker
// model, plus vector-driven checks of every picker month.
import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:test/test.dart';

import 'vectors/bikram_sambat_vectors.dart';
import 'vectors/coptic_vectors.dart';
import 'vectors/ethiopian_vectors.dart';
import 'vectors/islamic_vectors.dart';
import 'vectors/myanmar_vectors.dart';
import 'vectors/persian_vectors.dart';

CustomDatePickerModel open(
  DatePickerType type, [
  DatePickerMode mode = DatePickerMode.spinners,
  DateTime? date,
]) => CustomDatePickerModel(
  DatePickerDetails(type, mode),
  date ?? DateTime(2020, 5, 12),
);

void expectPickers(CustomDatePickerModel m, int year, int month, int day) {
  expect([m.year, m.monthId, m.day], [year, month, day]);
}

void main() {
  // [type, year, month, day, label, monthModeLabel, yearModeYear, yearModeLabel]
  final dialogCases = [
    (
      DatePickerType.ethiopian,
      2012,
      8,
      4,
      '4 Ginbot 2012 (May 12, 2020)',
      'Ginbot 2012 (May 2020)',
      '2012 (2019)',
    ),
    (
      DatePickerType.coptic,
      1736,
      8,
      4,
      '4 Pashons 1736 (May 12, 2020)',
      'Pashons 1736 (May 2020)',
      '1736 (2019)',
    ),
    (
      DatePickerType.islamic,
      1441,
      8,
      19,
      '19 Ramadan 1441 (May 12, 2020)',
      'Ramadan 1441 (Apr 2020)',
      '1441 (2019)',
    ),
    (
      DatePickerType.persian,
      1399,
      1,
      23,
      '23 Ordibehesht 1399 (May 12, 2020)',
      'Ordibehesht 1399 (Apr 2020)',
      '1399 (2020)',
    ),
    (
      DatePickerType.bikramSambat,
      2077,
      0,
      30,
      '30 बैशाख 2077 (May 12, 2020)',
      'बैशाख 2077 (Apr 2020)',
      '2077 (2020)',
    ),
    (
      DatePickerType.myanmar,
      1382,
      1,
      21,
      '21 ကဆုန် 1382 (May 12, 2020)',
      'ကဆုန် 1382 (Apr 2020)',
      '1381 (2020)',
    ),
  ];
  for (final (type, y, m, d, label, monthLabel, yearLabel) in dialogCases) {
    group(type.name, () {
      test('dialogShouldShowCorrectDate', () {
        final model = open(type);
        expectPickers(model, y, m, d);
        expect(model.label(), label);
        expect(model.showsDay && model.showsMonth, isTrue);
      });
      test('dialogShouldShowCorrectDate_forYearMode', () {
        final model = open(type, DatePickerMode.year);
        expectPickers(model, y, 0, 1);
        expect(model.label(), yearLabel);
        expect(model.showsMonth, isFalse);
      });
      test('dialogShouldShowCorrectDate_forMonthMode', () {
        final model = open(type, DatePickerMode.monthYear);
        expectPickers(model, y, m, 1);
        expect(model.label(), monthLabel);
        expect([model.showsDay, model.showsMonth], [false, true]);
      });
      test('settingDateInDatePicker_changesDateShownInTextView', () {
        final model = open(type)
          ..setYear(y)
          ..setMonth(m)
          ..setDay(d);
        expect(model.label(), label);
      });
      test('clickingOk_updatesDateInActivity', () {
        expect(open(type).gregorianDate, DateTime(2020, 5, 12));
      });
    });
  }

  group('Buddhist (BuddhistDatePickerDialogTest)', () {
    test('The dialog shows correct date', () {
      final model = open(
        DatePickerType.buddhist,
        DatePickerMode.spinners,
        DateTime(2010, 5, 12),
      );
      expect(model.label(), '12 พฤษภาคม 2553 (May 12, 2010)');
      final steps = [
        (6, 0, 2447, '6 มกราคม 2447 (Jan 06, 1904)'),
        (13, 1, 2459, '13 กุมภาพันธ์ 2459 (Feb 13, 1916)'),
        (21, 2, 2467, '21 มีนาคม 2467 (Mar 21, 1924)'),
        (10, 3, 2479, '10 เมษายน 2479 (Apr 10, 1936)'),
        (18, 4, 2487, '18 พฤษภาคม 2487 (May 18, 1944)'),
        (27, 5, 2499, '27 มิถุนายน 2499 (Jun 27, 1956)'),
        (8, 6, 2507, '8 กรกฎาคม 2507 (Jul 08, 1964)'),
        (15, 7, 2519, '15 สิงหาคม 2519 (Aug 15, 1976)'),
        (23, 8, 2527, '23 กันยายน 2527 (Sep 23, 1984)'),
        (30, 9, 2539, '30 ตุลาคม 2539 (Oct 30, 1996)'),
        (5, 10, 2547, '5 พฤศจิกายน 2547 (Nov 05, 2004)'),
        (12, 11, 2559, '12 ธันวาคม 2559 (Dec 12, 2016)'),
        (7, 0, 2567, '7 มกราคม 2567 (Jan 07, 2024)'),
        (14, 1, 2579, '14 กุมภาพันธ์ 2579 (Feb 14, 2036)'),
        (22, 2, 2587, '22 มีนาคม 2587 (Mar 22, 2044)'),
        (11, 3, 2599, '11 เมษายน 2599 (Apr 11, 2056)'),
        (19, 4, 2607, '19 พฤษภาคม 2607 (May 19, 2064)'),
        (26, 5, 2619, '26 มิถุนายน 2619 (Jun 26, 2076)'),
        (9, 6, 2627, '9 กรกฎาคม 2627 (Jul 09, 2084)'),
        (16, 7, 2639, '16 สิงหาคม 2639 (Aug 16, 2096)'),
      ];
      for (final (day, month, year, label) in steps) {
        model
          ..setDay(day)
          ..setMonth(month)
          ..setYear(year);
        expect(model.label(), label);
      }
    });

    test("The dialog shows correct date for 'year' mode", () {
      final model = open(
        DatePickerType.buddhist,
        DatePickerMode.year,
        DateTime(2010, 5, 12),
      );
      expect(model.label(), '2553 (2010)');
      for (final year in [2447, 2453, 2461, 2468, 2474, 2483, 2501, 2638]) {
        model.setYear(year);
        expect(model.label(), '$year (${year - 543})');
        expect(model.gregorianDate, DateTime(year - 543));
      }
    });

    test("The dialog shows correct date for 'month-year' mode", () {
      final model = open(
        DatePickerType.buddhist,
        DatePickerMode.monthYear,
        DateTime(2010, 5, 12),
      );
      expect(model.label(), 'พฤษภาคม 2553 (May 2010)');
      final steps = [
        (0, 2448, 'มกราคม 2448 (Jan 1905)'),
        (1, 2454, 'กุมภาพันธ์ 2454 (Feb 1911)'),
        (2, 2464, 'มีนาคม 2464 (Mar 1921)'),
        (9, 2538, 'ตุลาคม 2538 (Oct 1995)'),
        (11, 2560, 'ธันวาคม 2560 (Dec 2017)'),
        (2, 2595, 'มีนาคม 2595 (Mar 2052)'),
        (6, 2637, 'กรกฎาคม 2637 (Jul 2094)'),
      ];
      for (final (month, year, label) in steps) {
        model
          ..setMonth(month)
          ..setYear(year);
        expect(model.label(), label);
      }
    });
  });

  group('spinner behaviour', () {
    test('changing the month clamps the day (updateDays)', () {
      final model = open(
        DatePickerType.persian,
        DatePickerMode.spinners,
        DateTime(2020, 9, 21), // 31 Shahrivar 1399
      );
      expectPickers(model, 1399, 5, 31);
      model.setMonth(6); // Mehr has 30 days
      expect([model.day, model.dayPicker.maxValue], [30, 30]);
      expect(model.label(), '30 Mehr 1399 (Oct 21, 2020)');
    });

    test('Myanmar month list follows the year (yearUpdated)', () {
      final model = open(DatePickerType.myanmar);
      expect(model.monthPicker.displayedValues, myanmarMonthsOf(1382));
      model.setYear(1381);
      expect(model.monthPicker.displayedValues, myanmarMonthsOf(1381));
      expect(model.monthPicker.maxValue, myanmarMonthsOf(1381).length - 1);
    });

    test('year spinner wraps like a NumberPicker', () {
      final picker = NumberPickerState()
        ..minValue = 10
        ..maxValue = 20
        ..value = 22;
      expect(picker.value, 11);
      picker.value = 7;
      expect(picker.value, 18);
      final small = NumberPickerState()
        ..minValue = 1
        ..maxValue = 3
        ..value = 9;
      expect(small.value, 3);
    });
  });

  group('every picker month matches the JVM libraries', () {
    final joda = {
      DatePickerType.ethiopian: ethiopianPicker,
      DatePickerType.coptic: copticPicker,
      DatePickerType.islamic: islamicPicker,
      DatePickerType.persian: persianPicker,
    };
    joda.forEach((type, rows) {
      test(type.name, () {
        final calendar = CustomCalendar.of(type);
        for (final [year, month, _, max, start] in rows) {
          final first = DateTime(1970, 1, 1 + start);
          final model = open(type, DatePickerMode.spinners, first);
          expectPickers(model, year, month - 1, 1);
          expect(model.dayPicker.maxValue, max);
          expect(model.yearPicker.minValue, calendar.minYear);
          model.setDay(max);
          expect(model.gregorianDate, DateTime(1970, 1, start + max));
        }
      });
    });

    test('bikramSambat', () {
      for (final [year, month, days, start] in bikramSambatPicker) {
        if (year < 1970 || year > 2090 || days < 0) continue;
        final model = open(
          DatePickerType.bikramSambat,
          DatePickerMode.spinners,
          DateTime(1970, 1, 1 + start),
        );
        expectPickers(model, year, month - 1, 1);
        expect(model.dayPicker.maxValue, days);
        model.setDay(days);
        expect(model.gregorianDate, DateTime(1970, 1, start + days));
      }
    });

    test('myanmar', () {
      for (final [year, monthId, _, firstDay, length, start] in myanmarPicker) {
        if (year < 1261 || year > 1462) continue;
        final model = open(
          DatePickerType.myanmar,
          DatePickerMode.spinners,
          DateTime(1970, 1, start + firstDay),
        );
        expectPickers(model, year, monthId, firstDay);
        expect(
          [model.dayPicker.minValue, model.dayPicker.maxValue],
          [firstDay, length],
        );
        model.setDay(length);
        expect(model.gregorianDate, DateTime(1970, 1, start + length));
      }
    });
  });
}

List<String> myanmarMonthsOf(int year) {
  final row = myanmarYears.firstWhere((r) => r[0] == year);
  return [for (var i = 2; i < row.length; i += 2) myanmarNames[row[i]]];
}
