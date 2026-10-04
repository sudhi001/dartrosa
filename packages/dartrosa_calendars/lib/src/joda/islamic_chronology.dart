import '../gregorian.dart';
import 'basic_chronology.dart';

/// Port of Joda-Time 2.14's `org.joda.time.chrono.IslamicChronology` with
/// the leap year pattern ODK Collect uses: `IslamicChronology.getInstance()`
/// is `LEAP_YEAR_16_BASED` (years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and
/// 29 of each 30-year cycle have 355 days). Days start at midnight.
final class IslamicChronology extends BasicChronology {
  /// The Islamic chronology with the 16-based leap year pattern.
  const IslamicChronology();

  static const _monthPairLength = 59;
  static const _longMonthLength = 30;
  static const _shortMonthLength = 29;
  static const _millisPerMonthPair = 59 * millisPerDay;
  static const _millisPerLongMonth = 30 * millisPerDay;
  static const _millisPerShortYear = 354 * millisPerDay;
  static const _millisPerLongYear = 355 * millisPerDay;
  static const _millisYear1 = -42521587200000;
  static const _cycle = 30;
  static const _millisPerCycle = (19 * 354 + 11 * 355) * millisPerDay;

  /// `LEAP_YEAR_16_BASED`: bit `year % 30` set for leap years.
  static const _pattern16Based = 623191204;

  @override
  bool isLeapYear(int year) {
    // (pattern & (1 << (year % 30))) > 0; the pattern fits in 31 bits.
    final r = year.remainder(_cycle);
    return r >= 0 && (_pattern16Based >> r) & 1 == 1;
  }

  @override
  int yearOf(int instant) {
    final millisIslamic = instant - _millisYear1;
    final cycles = millisIslamic ~/ _millisPerCycle;
    var cycleRemainder = millisIslamic.remainder(_millisPerCycle);
    var year = cycles * _cycle + 1;
    var yearMillis = isLeapYear(year) ? _millisPerLongYear : _millisPerShortYear;
    while (cycleRemainder >= yearMillis) {
      cycleRemainder -= yearMillis;
      yearMillis = isLeapYear(++year) ? _millisPerLongYear : _millisPerShortYear;
    }
    return year;
  }

  @override
  int totalMillisByYearMonth(int year, int month) {
    final m = month - 1;
    if (m.remainder(2) == 1) {
      return (m ~/ 2) * _millisPerMonthPair + _millisPerLongMonth;
    }
    return (m ~/ 2) * _millisPerMonthPair;
  }

  @override
  int dayOfMonth(int millis) {
    final doy = dayOfYear(millis) - 1;
    if (doy == 354) return 30;
    return (doy % _monthPairLength) % _longMonthLength + 1;
  }

  @override
  int daysInYearMonth(int year, int month) {
    if (month == 12 && isLeapYear(year)) return _longMonthLength;
    return (month - 1).remainder(2) == 0 ? _longMonthLength : _shortMonthLength;
  }

  @override
  int monthOfYearIn(int millis, int year) {
    final doyZeroBased = (millis - yearMillis(year)) ~/ millisPerDay;
    if (doyZeroBased == 354) return 12;
    return (doyZeroBased * 2) ~/ _monthPairLength + 1;
  }

  @override
  int get averageMillisPerYearDividedByTwo =>
      (354.36667 * millisPerDay).toInt() ~/ 2; // unused: yearOf overridden

  @override
  int get approxMillisAtEpochDividedByTwo => 0; // unused: yearOf overridden

  @override
  int yearMillis(int year) {
    final y = year - 1;
    final cycle = y ~/ _cycle;
    var millis = _millisYear1 + cycle * _millisPerCycle;
    final cycleRemainder = y.remainder(_cycle) + 1;
    for (var i = 1; i < cycleRemainder; i++) {
      millis += isLeapYear(i) ? _millisPerLongYear : _millisPerShortYear;
    }
    return millis;
  }
}
