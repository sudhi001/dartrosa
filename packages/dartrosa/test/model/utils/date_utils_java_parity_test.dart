// Edge cases whose expected values were captured from JavaRosa 6.0.0 via
// jshell (Java 27), beyond JavaRosa's own DateUtils tests.
import 'package:clock/clock.dart';
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

import 'zone_helpers.dart';

void main() {
  final sunday = DateTime(2018, 1, 7, 10, 20, 30, 400);

  group('formatting', () {
    test('styles', () {
      expect(
        formatDateTime(
          DateTime.utc(2018, 1, 7, 15, 20, 30, 400),
          DateFormatStyle.timestampHttp,
        ),
        'Sun, 07 Jan 2018 15:20:30 GMT',
      );
      expect(
        formatDateTime(sunday, DateFormatStyle.humanReadableShort),
        '07/01/18 10:20',
      );
      expect(
        formatDateTime(sunday, DateFormatStyle.timestampSuffix),
        '20180107102030',
      );
      expect(formatDateTime(null, DateFormatStyle.iso8601), '');
    });

    test('escapes', () {
      expect(
        formatFields(
          DateFields.of(12345, 1, 2, 3, 4, 5, 6),
          '%Y %y %m %n %d %e %H %h %M %S %3 %%',
        ),
        '12345 345 01 1 02 2 03 3 04 05 006 %',
      );
      expect(intPad(-5, 3), '0-5');
    });

    test('escape errors use JavaRosa messages', () {
      Matcher fails(String message) => throwsA(
        isA<FormatException>().having((e) => e.message, 'message', message),
      );
      expect(
        () => format(sunday, '%'),
        fails('date format string ends with %'),
      );
      expect(
        () => format(sunday, '%Z'),
        fails('unsupported escape in date format string [%Z]'),
      );
      expect(
        () => format(sunday, '%q'),
        fails('unrecognized escape in date format string [%q]'),
      );
    });

    test('week numbers follow the locale region (Calendar.WEEK_OF_YEAR)', () {
      const expected = {
        'en': '2',
        'es_ES': '1',
        'fr': '2',
        'de_DE': '1',
        'en_US': '2',
        'en_GB': '1',
      };
      expected.forEach((locale, week) {
        expect(format(sunday, '%W', locale: locale), week, reason: locale);
      });
      expect(format(sunday, '%b|%a', locale: 'de_DE'), 'Jan.|So.');
    });

    test('US week numbers vs ISO week numbers', () {
      const cases = [
        ((2017, 1, 1), '1', '52', 1),
        ((2017, 12, 31), '1', '52', 1),
        ((2018, 12, 30), '1', '52', 1),
        ((2020, 12, 29), '1', '53', 3),
        ((2021, 1, 3), '2', '53', 1),
        ((2016, 1, 1), '1', '53', 6),
      ];
      for (final ((y, m, d), us, iso, dow) in cases) {
        final date = getDate(y, m, d)!;
        expect(format(date, '%W', locale: 'en_US'), us, reason: '$y-$m-$d');
        expect(formatFields(DateFields.of(y, m, d, 0, 0, 0, 0), '%W'), iso);
        expect(getFields(date).dow, dow);
      }
    });

    test('days from today', () {
      withClock(Clock.fixed(DateTime(2020, 6, 15, 12)), () {
        String days(DateTime d) =>
            formatDate(d, DateFormatStyle.humanReadableDaysFromToday);
        expect(days(DateTime(2020, 6, 15, 8)), 'Today');
        expect(days(DateTime(2020, 6, 14)), 'Yesterday');
        expect(days(DateTime(2020, 6, 13)), '2 days ago');
        expect(days(DateTime(2020, 6, 10)), '5 days ago');
        expect(days(DateTime(2020, 6, 16)), 'Tomorrow');
        expect(days(DateTime(2020, 6, 19)), '4 days from now');
        expect(days(DateTime(2020, 5, 1)), '01/05/20');
        // JavaRosa prints "null" for the missing time part.
        expect(
          formatDateTime(
            DateTime(2020, 6, 15),
            DateFormatStyle.humanReadableDaysFromToday,
          ),
          'Today null',
        );
        expect(
          formatDate(
            DateTime(2020, 6, 13),
            DateFormatStyle.humanReadableDaysFromToday,
            localize: (key, args) => '$key:${args.join(',')}',
          ),
          'date.twoago:2',
        );
      });
    });
  });

  group('parseTimeWithFixedDate', () {
    final base = DateFields.of(2020, 1, 1, 0, 0, 0, 0);
    const cases = [
      ('10:00', (10, 0, 0, 0)),
      ('10:00:', null),
      ('10:00:5.', (10, 0, 5, 0)),
      ('10:00:.5', (10, 0, 0, 500)),
      ('10:00:05.244', (10, 0, 5, 244)),
      ('10:00:1.2.3', null),
      ('25:00', null),
      ('1٣:00', (13, 0, 0, 0)),
      ('10:00:0٣', null),
      ('+10:00', null),
      ('10:00:05Zjunk', (10, 0, 5, 0)),
    ];
    for (final (input, expected) in cases) {
      test(input, () {
        final parsed = parseTimeWithFixedDate(input, base);
        if (expected == null) {
          expect(parsed, isNull);
        } else {
          expect((
            parsed!.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
          ), expected);
          expect((parsed.year, parsed.month, parsed.day), (2020, 1, 1));
        }
      });
    }

    test('a malformed offset throws, as in Java', () {
      expect(
        () => parseTimeWithFixedDate('10:00+ab', base),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseDateTime', () {
    test('valid and invalid inputs', () {
      expect(parseDateTime('2020-01-01'), DateTime(2020));
      expect(parseDateTime('2020-1-1'), DateTime(2020));
      expect(parseDateTime('+2020-01-01'), DateTime(2020));
      expect(parseDateTime('2020-02-30'), isNull);
      expect(parseDateTime(' 2020-01-01'), isNull);
      expect(parseDateTime('2020-01-01-05'), isNull);
      expect(
        parseDateTime('2020-01-01T10:00:00Z')!.millisecondsSinceEpoch,
        DateTime.utc(2020, 1, 1, 10).millisecondsSinceEpoch,
      );
    });

    test('an empty time part throws, as in Java', () {
      expect(() => parseDateTime('2020-01-01T'), throwsA(isA<RangeError>()));
    });
  });

  group('date arithmetic', () {
    test('dateAdd, dateDiff, daysSinceEpoch', () {
      expect(dateAdd(DateTime(2020, 2, 28, 15), 2), DateTime(2020, 3, 1));
      expect(dateDiff(DateTime(2020, 1, 1, 23), DateTime(2020, 1, 2, 1)), 1);
      expect(dateDiff(DateTime(2020, 1, 2), DateTime(2020, 1, 1)), -1);
      expect(daysSinceEpoch(DateTime(1970, 1, 11, 18)), 10);
      expect(daysSinceEpoch(DateTime(1969, 12, 31)), -1);
      expect(fractionalDaysSinceEpoch(DateTime(1970, 1, 2, 12)), 1.5);
    });

    test('calendar helpers', () {
      expect(daysInMonth(1, 2020), 29);
      expect(daysInMonth(1, 1900), 28);
      expect(daysInMonth(3, 2021), 30);
      expect(isLeap(2000), isTrue);
      expect(getDate(2021, 2, 29), isNull);
      expect(roundDate(DateTime(2021, 5, 6, 7, 8)), DateTime(2021, 5, 6));
      expect(split('a--b', '-'), ['a', '', 'b']);
      expect(split('a--b', '-', combineMultipleDelimiters: true), ['a', 'b']);
    });

    test('getPastPeriodDate', () {
      // Wednesday 2021-06-16.
      final ref = DateTime(2021, 6, 16, 12);
      DateTime? past(
        String start, {
        bool beginning = true,
        bool includeToday = false,
        int nAgo = 1,
      }) => getPastPeriodDate(
        ref,
        'week',
        start,
        beginning: beginning,
        includeToday: includeToday,
        nAgo: nAgo,
      );
      expect(past('sun'), DateTime(2021, 6, 6, 12));
      expect(past('sun', beginning: false), DateTime(2021, 6, 12, 12));
      expect(
        past('wed', includeToday: true, nAgo: 0),
        DateTime(2021, 6, 16, 12),
      );
      expect(
        getPastPeriodDate(
          ref,
          'month',
          'sun',
          beginning: true,
          includeToday: true,
          nAgo: 0,
        ),
        isNull,
      );
    });

    test('decimalTimeOfLocalDay', () {
      withClock(Clock.fixed(DateTime(2020, 1, 1)), () {
        expect(decimalTimeOfLocalDay(DateTime(2020, 1, 1, 18)), 0.75);
      });
    });
  });

  group('DST (values from JavaRosa in the same zone)', () {
    // (wall time, Java instant, Java ISO string)
    test('America/New_York gap and overlap', () {
      const cases = [
        ((2021, 3, 14, 2, 30), 1615707000000, '2021-03-14T03:30:00.000-04:00'),
        ((2021, 11, 7, 1, 30), 1636263000000, '2021-11-07T01:30:00.000-05:00'),
        ((2021, 3, 28, 1, 30), 1616909400000, '2021-03-28T01:30:00.000-04:00'),
      ];
      for (final ((y, mo, d, h, mi), ms, iso) in cases) {
        final date = getDateFromFields(DateFields.of(y, mo, d, h, mi, 0, 0));
        expect(date.millisecondsSinceEpoch, ms);
        expect(formatDateTime(date, DateFormatStyle.iso8601), iso);
      }
    }, skip: isNewYork ? null : 'needs TZ=America/New_York');

    test('Europe/London gap and overlap', () {
      const cases = [
        ((2021, 3, 28, 1, 30), 1616895000000, '2021-03-28T02:30:00.000+01:00'),
        ((2021, 10, 31, 1, 30), 1635640200000, '2021-10-31T01:30:00.000Z'),
        ((2021, 10, 31, 2, 30), 1635647400000, '2021-10-31T02:30:00.000Z'),
      ];
      for (final ((y, mo, d, h, mi), ms, iso) in cases) {
        final date = getDateFromFields(DateFields.of(y, mo, d, h, mi, 0, 0));
        expect(date.millisecondsSinceEpoch, ms);
        expect(formatDateTime(date, DateFormatStyle.iso8601), iso);
      }
    }, skip: isLondon ? null : 'needs TZ=Europe/London');
  });
}
