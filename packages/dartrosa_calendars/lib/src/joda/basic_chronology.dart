import '../gregorian.dart';

/// A date in a Joda-Time chronology: the `year`, `monthOfYear` and
/// `dayOfMonth` fields of a `LocalDateTime`.
typedef JodaFields = ({int year, int month, int day});

/// Port of the date arithmetic of Joda-Time 2.14's
/// `org.joda.time.chrono.BasicChronology` that ODK Collect's date pickers
/// reach (through `LocalDateTime` and `DateTime.withChronology`), for
/// local-midnight instants.
///
/// Instants are milliseconds of local time since 1970-01-01 (the local
/// millis of a `LocalDateTime`). Field values are computed with the same
/// estimate-and-correct algorithm as Joda, so the results match Joda's
/// (including any quirk) rather than an idealised calendar.
abstract class BasicChronology {
  /// Const constructor for subclasses.
  const BasicChronology();

  /// `calculateFirstDayOfYearMillis`: the first instant of [year].
  int yearMillis(int year);

  /// `isLeapYear`.
  bool isLeapYear(int year);

  /// `getAverageMillisPerYearDividedByTwo`.
  int get averageMillisPerYearDividedByTwo;

  /// `getApproxMillisAtEpochDividedByTwo`.
  int get approxMillisAtEpochDividedByTwo;

  /// `getMonthOfYear(long millis, int year)`.
  int monthOfYearIn(int millis, int year);

  /// `getTotalMillisByYearMonth`: the millis from the start of [year] to
  /// the start of [month].
  int totalMillisByYearMonth(int year, int month);

  /// `getDaysInYearMonth`.
  int daysInYearMonth(int year, int month);

  /// `getYear(long instant)`.
  int yearOf(int instant) {
    // Initial estimate uses values divided by two to avoid overflow.
    final unitMillis = averageMillisPerYearDividedByTwo;
    var i2 = floorDiv(instant, 2) + approxMillisAtEpochDividedByTwo;
    if (i2 < 0) i2 = i2 - unitMillis + 1;
    var year = i2 ~/ unitMillis;

    var yearStart = yearMillis(year);
    final diff = instant - yearStart;

    if (diff < 0) {
      year--;
    } else if (diff >= millisPerDay * 365) {
      // One year may need to be added to fix estimate.
      final oneYear = isLeapYear(year)
          ? millisPerDay * 366
          : millisPerDay * 365;
      yearStart += oneYear;
      if (yearStart <= instant) year++;
    }
    return year;
  }

  /// `getMonthOfYear(long millis)`.
  int monthOfYear(int millis) => monthOfYearIn(millis, yearOf(millis));

  /// `getDayOfMonth(long millis)`.
  int dayOfMonth(int millis) {
    final year = yearOf(millis);
    final month = monthOfYearIn(millis, year);
    return dayOfMonthIn(millis, year, month);
  }

  /// `getDayOfMonth(long millis, int year, int month)`.
  int dayOfMonthIn(int millis, int year, int month) {
    final dateMillis = yearMillis(year) + totalMillisByYearMonth(year, month);
    return (millis - dateMillis) ~/ millisPerDay + 1;
  }

  /// `getDayOfYear(long instant)`.
  int dayOfYear(int instant) => dayOfYearIn(instant, yearOf(instant));

  /// `getDayOfYear(long instant, int year)`.
  int dayOfYearIn(int instant, int year) =>
      (instant - yearMillis(year)) ~/ millisPerDay + 1;

  /// `getYearMonthDayMillis`.
  int yearMonthDayMillis(int year, int month, int dayOfMonth) =>
      yearMillis(year) +
      totalMillisByYearMonth(year, month) +
      (dayOfMonth - 1) * millisPerDay;

  /// `getDaysInMonthMax(long instant)`: what
  /// `localDateTime.dayOfMonth().getMaximumValue()` returns.
  int daysInMonthMaxAt(int instant) {
    final year = yearOf(instant);
    return daysInYearMonth(year, monthOfYearIn(instant, year));
  }

  /// The fields of the local-midnight date [epochDay] days after
  /// 1970-01-01, as `new DateTime(date).withChronology(this)` gives them.
  JodaFields fieldsOf(int epochDay) {
    final millis = epochDay * millisPerDay;
    return (
      year: yearOf(millis),
      month: monthOfYear(millis),
      day: dayOfMonth(millis),
    );
  }

  /// The Gregorian day (days since 1970-01-01) of
  /// `new LocalDateTime(year, month, day, 0, 0, 0, 0, this)`, as
  /// `DateTimeUtils.getDateAsGregorian` converts it. The day must be valid
  /// (`1 <= day <= daysInYearMonth(year, month)`).
  int epochDayOf(int year, int month, int day) {
    RangeError.checkValueInInterval(month, 1, maxMonth, 'month');
    RangeError.checkValueInInterval(
      day,
      1,
      daysInYearMonth(year, month),
      'day',
    );
    return yearMonthDayMillis(year, month, day) ~/ millisPerDay;
  }

  /// `getMaxMonth()`.
  int get maxMonth => 12;

  /// `localDateTime.dayOfMonth().getMaximumValue()` for
  /// `new LocalDateTime(year, month, 1, 0, 0, 0, 0, this)`.
  int maximumDayOfMonth(int year, int month) =>
      daysInMonthMaxAt(yearMonthDayMillis(year, month, 1));
}

/// Port of Joda-Time's `BasicFixedMonthChronology`: twelve 30-day months
/// and a short thirteenth month (Coptic, Ethiopic).
abstract class BasicFixedMonthChronology extends BasicChronology {
  /// Const constructor for subclasses.
  const BasicFixedMonthChronology();

  /// `MONTH_LENGTH`.
  static const monthLength = 30;

  /// `MILLIS_PER_YEAR`: `(long) (365.25 * MILLIS_PER_DAY)`.
  static const millisPerYear = 31557600000;

  /// `MILLIS_PER_MONTH`.
  static const millisPerMonth = monthLength * millisPerDay;

  @override
  int totalMillisByYearMonth(int year, int month) =>
      (month - 1) * millisPerMonth;

  @override
  int dayOfMonth(int millis) => (dayOfYear(millis) - 1) % monthLength + 1;

  @override
  bool isLeapYear(int year) => year % 4 == 3; // (year & 3) == 3

  @override
  int daysInYearMonth(int year, int month) =>
      month != 13 ? monthLength : (isLeapYear(year) ? 6 : 5);

  @override
  int monthOfYear(int millis) => (dayOfYear(millis) - 1) ~/ monthLength + 1;

  @override
  int monthOfYearIn(int millis, int year) =>
      (millis - yearMillis(year)) ~/ millisPerMonth + 1;

  @override
  int get maxMonth => 13;

  @override
  int get averageMillisPerYearDividedByTwo => millisPerYear ~/ 2;
}

/// Port of Joda-Time's `CopticChronology`.
final class CopticChronology extends BasicFixedMonthChronology {
  /// The Coptic chronology (`CopticChronology.getInstance()`).
  const CopticChronology();

  @override
  int yearMillis(int year) => _fixedMonthYearMillis(year, 1687, isLeapYear);

  @override
  int get approxMillisAtEpochDividedByTwo =>
      (1686 * BasicFixedMonthChronology.millisPerYear + 112 * millisPerDay) ~/
      2;
}

/// Port of Joda-Time's `EthiopicChronology`.
final class EthiopicChronology extends BasicFixedMonthChronology {
  /// The Ethiopic chronology (`EthiopicChronology.getInstance()`).
  const EthiopicChronology();

  @override
  int yearMillis(int year) => _fixedMonthYearMillis(year, 1963, isLeapYear);

  @override
  int get approxMillisAtEpochDividedByTwo =>
      (1962 * BasicFixedMonthChronology.millisPerYear + 112 * millisPerDay) ~/
      2;
}

/// `calculateFirstDayOfYearMillis` of `CopticChronology` (base 1687) and
/// `EthiopicChronology` (base 1963).
int _fixedMonthYearMillis(
  int year,
  int baseYear,
  bool Function(int) isLeapYear,
) {
  // Java epoch is 1970-01-01 Gregorian which is 1686-04-23 Coptic
  // (1962-04-23 Ethiopic). Calculate relative to the nearest leap year
  // and account for the difference later.
  final relativeYear = year - baseYear;
  int leapYears;
  if (relativeYear <= 0) {
    // (relativeYear + 3) >> 2
    leapYears = floorDiv(relativeYear + 3, 4);
  } else {
    leapYears = floorDiv(relativeYear, 4);
    // For post base-year an adjustment is needed as jan1st is before leap day
    if (!isLeapYear(year)) leapYears++;
  }
  final millis = (relativeYear * 365 + leapYears) * millisPerDay;
  // Adjust to account for difference between 1687-01-01 and 1686-04-23.
  return millis + (365 - 112) * millisPerDay;
}
