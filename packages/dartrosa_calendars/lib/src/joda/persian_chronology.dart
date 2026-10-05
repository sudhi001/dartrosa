import '../gregorian.dart';
import 'basic_chronology.dart';

/// Port of `org.joda.time.chrono.PersianChronologyKhayyamBorkowski` (and
/// its base `PersianChronology`) from persianjodatime 1.2
/// (github.com/mohamadian/persianjodatime, Apache 2.0), the Persian
/// (Solar Hijri) chronology ODK Collect's `persian` appearance uses: the
/// 33-year-cycle arithmetic of Kazimierz Borkowski with Khayyam's break
/// years.
final class PersianChronologyKhayyamBorkowski extends BasicChronology {
  /// The Khayyam-Borkowski Persian chronology.
  const PersianChronologyKhayyamBorkowski();

  static const _averageDaysPerYear = 365.24219858156;

  static const _breakYears = [
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, //
    1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
  ];

  static const _farvardinToShahrivarMonthDays = 31;
  static const _mehrToBahmanMonthDays = 30;

  /// `breakYearCalculations`: `(jump, differenceToNextBreakYear,
  /// jalaaliLeaps)`.
  (int, int, int) _breakYearCalculations(int persianYear, bool calcLeaps) {
    var jalaaliLeaps = -14;
    var jump = 0;
    var breakYear = _breakYears[0];
    for (var i = 1; i < _breakYears.length; i++) {
      final nextBreakYear = _breakYears[i];
      jump = nextBreakYear - breakYear;
      if (persianYear < nextBreakYear) break;
      if (calcLeaps) {
        jalaaliLeaps = jalaaliLeaps + jump ~/ 33 * 8 + jump.remainder(33) ~/ 4;
      }
      breakYear = nextBreakYear;
    }
    return (jump, persianYear - breakYear, jalaaliLeaps);
  }

  @override
  int yearMillis(int year) {
    final (jump, difference, leaps) = _breakYearCalculations(year, true);
    var leapJ =
        leaps + difference ~/ 33 * 8 + (difference.remainder(33) + 3) ~/ 4;
    if (jump.remainder(33) == 4 && jump - difference == 4) leapJ = leapJ + 1;
    final isoYear = year + 621;
    final gregorianLeaps = isoYear ~/ 4 - (isoYear ~/ 100 + 1) * 3 ~/ 4 - 150;
    final dayInISOMarch = 20 + leapJ - gregorianLeaps;
    // new DateTime(isoYear, 3, dayInISOMarch, ..., ISOChronology UTC)
    return epochDayOf(isoYear, 3, dayInISOMarch) * millisPerDay;
  }

  @override
  bool isLeapYear(int year) {
    final (jump, difference0, _) = _breakYearCalculations(year, false);
    var difference = difference0;
    if (jump - difference < 6) {
      difference = difference - jump + (jump + 4) ~/ 33 * 33;
    }
    final sinceLastLeap = ((difference + 1).remainder(33) - 1).remainder(4);
    return sinceLastLeap == 0;
  }

  int get _averageMillisPerYear => (_averageDaysPerYear * millisPerDay).toInt();

  @override
  int get averageMillisPerYearDividedByTwo => _averageMillisPerYear ~/ 2;

  @override
  int get approxMillisAtEpochDividedByTwo =>
      (1348 * _averageMillisPerYear) ~/ 2;

  @override
  int daysInYearMonth(int year, int month) {
    if (month < 7) return _farvardinToShahrivarMonthDays;
    if (month < 12 || isLeapYear(year)) return _mehrToBahmanMonthDays;
    return 29;
  }

  @override
  int monthOfYearIn(int millis, int year) {
    // Joda compares (millis - yearStart) >> 10 against multiples of 84375
    // (a day in 1024 ms units); local midnights are whole days.
    final i = (millis - yearMillis(year)) ~/ millisPerDay;
    if (i < 186) {
      if (i < 93) return i < 31 ? 1 : (i < 62 ? 2 : 3);
      return i < 124 ? 4 : (i < 155 ? 5 : 6);
    }
    if (i < 276) return i < 216 ? 7 : (i < 246 ? 8 : 9);
    return i < 306 ? 10 : (i < 336 ? 11 : 12);
  }

  @override
  int totalMillisByYearMonth(int year, int month) {
    final m = month - 1;
    final days = m <= 6 ? m * 31 : 186 + (m - 6) * 30;
    return days * millisPerDay;
  }
}
