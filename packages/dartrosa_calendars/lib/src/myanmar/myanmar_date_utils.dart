import '../gregorian.dart';
import 'myanmar_calendar.dart';

/// Port of ODK Collect's `org.odk.collect.android.utilities.MyanmarDateUtils`:
/// the glue between Collect's Myanmar date picker and the `mmcalendar`
/// library. Gregorian dates are days since 1970-01-01.
abstract final class MyanmarDateUtils {
  /// `gregorianDateToMyanmarDate`.
  static MyanmarDate gregorianDateToMyanmarDate(int epochDay) {
    final c = civilOf(epochDay);
    return myanmarDateOfWestern(c.year, c.month, c.day);
  }

  /// `myanmarDateToGregorianDate`: the Gregorian day of [myanmarDate].
  static int myanmarDateToGregorianDate(MyanmarDate myanmarDate) {
    final w = julianToWestern(myanmarDate.julianDayNumber);
    return epochDayOf(w.year, w.month, w.day);
  }

  /// `createMyanmarDate`.
  static MyanmarDate createMyanmarDate(
    int myanmarYear,
    int myanmarMonthIndex,
    int myanmarMonthDay,
  ) => julianToMyanmarDate(
    myanmarDateToJulian(
      myanmarYear,
      myanmarMonthIndex,
      myanmarMonthDay,
    ).toDouble(),
  );

  /// `getMyanmarMonthsArray`: the month names Collect's picker shows for
  /// [myanmarYear].
  static List<String> getMyanmarMonthsArray(int myanmarYear) =>
      relatedMyanmarMonths(myanmarYear).names;

  /// The month indexes of [myanmarYear], in picker order
  /// (`MyanmarCalendarKernel.calculateRelatedMyanmarMonths(year, 1)
  /// .getMonthList()`).
  static List<int> getMonthIndexes(int myanmarYear) =>
      relatedMyanmarMonths(myanmarYear).months;

  /// `getFirstMonthDay(MyanmarDate)`: the first day the day picker offers.
  static int getFirstMonthDay(MyanmarDate myanmarDate) =>
      _isFirstYearMonth(myanmarDate) ? _getNewYearsDay(myanmarDate.year) : 1;

  /// `getFirstMonthDay(int, int)`.
  static int getFirstMonthDayOf(int myanmarYear, int monthIndex) =>
      _isFirstYearMonthOf(myanmarYear, monthIndex)
      ? _getNewYearsDay(myanmarYear)
      : 1;

  /// `getMonthId`: the position of [myanmarDate]'s month in its year's
  /// month list (-1 if absent).
  static int getMonthId(MyanmarDate myanmarDate) =>
      getMyanmarMonthsArray(myanmarDate.year).indexOf(myanmarDate.monthName);

  /// `getMonthLength(MyanmarDate)`: the last day the day picker offers.
  static int getMonthLength(MyanmarDate myanmarDate) {
    final newYearsDayOfNextYear = _getNewYearsDay(myanmarDate.year + 1);
    return _isLastMonthInYear(myanmarDate) && newYearsDayOfNextYear > 1
        ? newYearsDayOfNextYear - 1
        : myanmarDate.monthLength;
  }

  /// `getMonthLength(int, int)`.
  static int getMonthLengthOf(int myanmarYear, int monthIndex) =>
      getMonthLength(
        createMyanmarDate(
          myanmarYear,
          monthIndex,
          getFirstMonthDayOf(myanmarYear, monthIndex),
        ),
      );

  static int _getNewYearsDay(int myanmarYear) =>
      julianToMyanmarDate(myanmarNewYearDay(myanmarYear)).dayOfMonth;

  static bool _isLastMonthInYear(MyanmarDate myanmarDate) =>
      getMonthId(myanmarDate) ==
      getMyanmarMonthsArray(myanmarDate.year).length - 1;

  static bool _isFirstYearMonth(MyanmarDate myanmarDate) =>
      getMonthId(myanmarDate) == 0;

  static bool _isFirstYearMonthOf(int myanmarYear, int monthIndex) =>
      monthIndex == getMonthIndexes(myanmarYear).first;
}
