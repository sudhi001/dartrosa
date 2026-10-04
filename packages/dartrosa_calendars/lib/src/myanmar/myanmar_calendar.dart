/// Port of the parts of the `mmcalendar` library (myanmar-calendar
/// 1.1.1.RELEASE, github.com/chanmratekoko/myanmar-calendar, MIT; itself
/// a port of Yan Naing Aye's Myanmar calendar algorithm,
/// yan9a.github.io/mcal) that ODK Collect's `myanmar` appearance uses.
///
/// Java semantics are kept exactly: `Math.round(x)` is `floor(x + 0.5)`,
/// `%` is the truncating remainder and integer `/` truncates.
library;

import '../gregorian.dart';

/// `Constants.SY`: solar year (days).
const _sy = 365.2587564814815;

/// `Constants.LM`: lunar month (days).
const _lm = 29.53058794607172;

/// `Constants.MO`: beginning of the Myanmar era (Julian day).
const _mo = 1954168.050623;

/// `Constants.SG`: the default Gregorian start (1752-09-14).
const _sg = 2361222.0;

/// Java's `Math.round(double)`.
int _round(double x) => (x + 0.5).floor();

/// `Constants.EMA`: English month names, by month index.
const myanmarEnglishMonthNames = [
  'First Waso', 'Tagu', 'Kason', 'Nayon', 'Waso', 'Wagaung', 'Tawthalin', //
  'Thadingyut', 'Tazaungmon', 'Nadaw', 'Pyatho', 'Tabodwe', 'Tabaung',
  'Late Tagu', 'Late Kason',
];

/// The `Language.MYANMAR` month names, by month index, as
/// `LanguageTranslator.translateSentence` translates [myanmarEnglishMonthNames].
const _myanmarMonthNames = [
  'ပ ဝါဆို', 'တန်ခူး', 'ကဆုန်', 'နယုန်', 'ဝါဆို', 'ဝါခေါင်', //
  'တော်သလင်း', 'သီတင်းကျွတ်', 'တန်ဆောင်မုန်း', 'နတ်တော်', 'ပြာသို',
  'တပို့တွဲ', 'တပေါင်း', 'နှောင်းတန်ခူး', 'နှောင်းကဆုန်',
];

/// `translateSentence("Second Waso")` / `translate("Second") + " " +
/// translateSentence("Waso")`.
const _myanmarSecondWaso = 'ဒု ဝါဆို';

/// The Myanmar-language name of month [monthIndex] in a year of
/// [yearType] (`MyanmarDate.getMonthName(Language.MYANMAR)`).
String myanmarMonthName(int monthIndex, int yearType) =>
    monthIndex == 4 && yearType > 0
    ? _myanmarSecondWaso
    : _myanmarMonthNames[monthIndex];

/// A Myanmar date (`mmcalendar.MyanmarDate`), with the fields Collect uses.
final class MyanmarDate {
  /// Creates the date.
  const MyanmarDate({
    required this.year,
    required this.yearType,
    required this.month,
    required this.monthLength,
    required this.dayOfMonth,
    required this.julianDayNumber,
  });

  /// `getYearValue()`: the Myanmar year.
  final int year;

  /// `getYearType()`: 0 common, 1 little watat, 2 big watat.
  final int yearType;

  /// `getMonth()`: the month index (Tagu=1, ..., Tabaung=12, First Waso=0,
  /// (Second) Waso=4, Late Tagu=13, Late Kason=14).
  final int month;

  /// `lengthOfMonth()`.
  final int monthLength;

  /// `getDayOfMonth()`: 1-30.
  final int dayOfMonth;

  /// `getJulianDayNumber()`: the Julian date it was created from.
  final double julianDayNumber;

  /// `getMonthName(Language.MYANMAR)`.
  String get monthName => myanmarMonthName(month, yearType);

  @override
  String toString() => 'MyanmarDate($year, $monthName, $dayOfMonth)';
}

/// The constants of a Myanmar year (`MyanmarYearConstants.getMyConst`).
({double ei, double wo, double nm, double ew}) _myConst(int my) {
  double eraId, watatOffset, numberOfMonths;
  var exceptionInWatatYear = 0.0;
  List<List<int>> fme;
  List<int> wte;
  if (my >= 1312) {
    eraId = 3;
    watatOffset = -0.5;
    numberOfMonths = 8;
    fme = [
      [1377, 1],
    ];
    wte = [1344, 1345];
  } else if (my >= 1217) {
    eraId = 2;
    watatOffset = -1;
    numberOfMonths = 4;
    fme = [
      [1234, 1],
      [1261, -1],
    ];
    wte = [1263, 1264];
  } else if (my >= 1100) {
    eraId = 1.3;
    watatOffset = -0.85;
    numberOfMonths = -1;
    fme = [
      [1120, 1],
      [1126, -1],
      [1150, 1],
      [1172, -1],
      [1207, 1],
    ];
    wte = [1201, 1202];
  } else if (my >= 798) {
    eraId = 1.2;
    watatOffset = -1.1;
    numberOfMonths = -1;
    fme = [
      for (final y in [813, 849, 851, 854, 927, 933, 936, 938, 949, 952])
        [y, -1],
      for (final y in [963, 968, 1039]) [y, -1],
    ];
    wte = [];
  } else {
    eraId = 1.1;
    watatOffset = -1.1;
    numberOfMonths = -1;
    fme = [
      [205, 1],
      [246, 1],
      [471, 1],
      [572, -1],
      [651, 1],
      [653, 2],
      [656, 1],
      [672, 1],
      [729, 1],
      [767, -1],
    ];
    wte = [];
  }
  for (final e in fme) {
    if (e[0] == my) watatOffset += e[1];
  }
  if (wte.contains(my)) exceptionInWatatYear = 1;
  return (
    ei: eraId,
    wo: watatOffset,
    nm: numberOfMonths,
    ew: exceptionInWatatYear,
  );
}

/// `MyanmarDateKernel.checkWatat`: the full moon day of the second Waso
/// and whether [my] is a watat (leap) year.
({int fm, int watat}) _checkWatat(int my) {
  final c = _myConst(my);
  final threshold = (_sy / 12 - _lm) * (12 - c.nm);
  var ed = (_sy * (my + 3739)).remainder(_lm);
  if (ed < threshold) ed += _lm;
  final fm = _round(_sy * my + _mo - ed + 4.5 * _lm + c.wo);
  int watat;
  if (c.ei >= 2) {
    final tw = _lm - (_sy / 12 - _lm) * c.nm;
    watat = ed >= tw ? 1 : 0;
  } else {
    watat = (my * 7 + 2).remainder(19);
    if (watat < 0) watat += 19;
    watat = (watat / 12.0).floor();
  }
  watat ^= c.ew.toInt();
  return (fm: fm, watat: watat);
}

/// `MyanmarDateKernel.checkMyanmarYear`: year type (`myt`), first day of
/// Tagu (`tg1`) and full moon day of the second Waso (`fm`).
({int myt, int tg1, int fm}) _checkMyanmarYear(int myear) {
  final y2 = _checkWatat(myear);
  var myt = y2.watat;
  var yd = 0;
  ({int fm, int watat}) y1;
  do {
    yd++;
    y1 = _checkWatat(myear - yd);
  } while (y1.watat == 0 && yd < 3);
  int fm;
  if (myt > 0) {
    final nd = (y2.fm - y1.fm).remainder(354).toDouble();
    myt = (nd / 31).floor() + 1;
    fm = y2.fm;
  } else {
    fm = y1.fm + 354 * yd;
  }
  final tg1 = y1.fm + 354 * yd - 102;
  return (myt: myt, tg1: tg1, fm: fm);
}

/// `MyanmarDateKernel.julianToMyanmarDate`.
MyanmarDate julianToMyanmarDate(double jd) {
  if (jd < 0) {
    throw ArgumentError.value(jd, 'jd', 'Julian day number cannot be negative');
  }
  final jdn = _round(jd);
  final myear = ((jdn - 0.5 - _mo) / _sy).floor();
  final yearInfo = _checkMyanmarYear(myear);
  final myt = yearInfo.myt;
  var dd = jdn - yearInfo.tg1 + 1;
  final b = myt ~/ 2;
  final c = 1 ~/ (myt + 1);
  final yearLength = 354 + (1 - c) * 30 + b;
  final monthType = (dd - 1) ~/ yearLength;
  dd -= monthType * yearLength;
  final a = (dd + 423) ~/ 512;
  var mmonth = ((dd - b * a + c * a * 30 + 29.26) / 29.544).floor();
  final e = (mmonth + 12) ~/ 16;
  final f = (mmonth + 11) ~/ 16;
  final monthDay =
      (dd - (29.544 * mmonth - 29.26).floor() - b * e + c * f * 30);
  mmonth += f * 3 - e * 4 + 12 * monthType;
  var monthLength = 30 - mmonth.remainder(2);
  if (mmonth == 3) monthLength += myt ~/ 2;
  return MyanmarDate(
    year: myear,
    yearType: myt,
    month: mmonth,
    monthLength: monthLength,
    dayOfMonth: monthDay,
    julianDayNumber: jd,
  );
}

/// `MyanmarDateKernel.myanmarDateToJulian`.
int myanmarDateToJulian(int myear, int mmonth, int mmday) {
  final yo = _checkMyanmarYear(myear);
  final mmt = mmonth ~/ 13;
  var month = mmonth.remainder(13) + mmt;
  final b = yo.myt ~/ 2;
  final c = 1 - ((yo.myt + 1.0) / 2.0).floor();
  month +=
      4 - ((month + 15) / 16.0).floor() * 4 + ((month + 12) / 16.0).floor();
  var dd =
      mmday +
      (29.544 * month - 29.26).floor() -
      c * ((month + 11) / 16.0).floor() * 30 +
      b * ((month + 12) / 16.0).floor();
  final myl = 354 + (1 - c) * 30 + b;
  dd += mmt * myl;
  return dd + yo.tg1 - 1;
}

/// `Thingyan.of(myear).getMyanmarNewYearDay()`: the Julian day of the
/// Myanmar new year's day.
double myanmarNewYearDay(int myear) {
  if (myear < 1100) {
    throw ArgumentError.value(myear, 'myear', 'Thingyan starts from 1100');
  }
  // Atat time; the new year's day is the day after the atat day.
  final ja = _sy * myear + _mo;
  return _round(ja).toDouble() + 1;
}

/// `MyanmarCalendarKernel.calculateRelatedMyanmarMonths(myear, 1)`: the
/// month indexes and Myanmar names of [myear], in order.
({List<int> months, List<String> names}) relatedMyanmarMonths(int myear) {
  final j1 = _round(_sy * myear + _mo) + 1.0;
  final j2 = _round(_sy * (myear + 1) + _mo).toDouble();
  final m1 = julianToMyanmarDate(j1);
  final m2 = julianToMyanmarDate(j2);
  var si = m1.month;
  final ei = m2.month;
  if (si == 0) si = 4;
  final months = <int>[];
  final names = <String>[];
  for (var i = si; i <= ei; i++) {
    if (i == 4 && m1.yearType != 0) {
      months.add(0);
      names.add(_myanmarMonthNames[0]);
    }
    months.add(i);
    names.add(
      i == 4 && m1.yearType != 0 ? _myanmarSecondWaso : _myanmarMonthNames[i],
    );
  }
  return (months: months, names: names);
}

/// `WesternDateKernel.westernToJulian(year, month, day, ENGLISH, 0)`: the
/// Julian day number of a Western date (Julian calendar before
/// 1752-09-14, Gregorian after, as the British calendar).
double westernToJulian(int year, int month, int day) {
  final a = ((14 - month) / 12.0).floor();
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  var jd =
      day + ((153 * m + 2) / 5.0).floor() + 365 * y + (y / 4.0).floor() + 0.0;
  jd = jd - (y / 100.0).floor() + (y / 400.0).floor() - 32045;
  if (jd < _sg) {
    jd =
        day +
        ((153.0 * m + 2) / 5).floorToDouble() +
        365 * y +
        (y / 4.0).floor() -
        32083;
    if (jd > _sg) jd = _sg;
  }
  return jd;
}

/// `WesternDateKernel.julianToWestern(jd, ENGLISH, 0)`: the Western date
/// of a Julian date.
({int year, int month, int day}) julianToWestern(double julianDate) {
  double y, m, d;
  if (julianDate < _sg) {
    final j = (julianDate + 0.5).floorToDouble();
    final b = j + 1524;
    final c = ((b - 122.1) / 365.25).floorToDouble();
    final f = (365.25 * c).floorToDouble();
    final e = ((b - f) / 30.6001).floorToDouble();
    m = e > 13 ? e - 13 : e - 1;
    d = b - f - (30.6001 * e).floorToDouble();
    y = m < 3 ? c - 4715 : c - 4716;
  } else {
    var j = (julianDate + 0.5).floorToDouble();
    j -= 1721119;
    y = ((4 * j - 1) / 146097.0).floorToDouble();
    j = 4 * j - 1 - 146097 * y;
    d = (j / 4).floorToDouble();
    j = ((4 * d + 3) / 1461.0).floorToDouble();
    d = 4 * d + 3 - 1461 * j;
    d = ((d + 4) / 4.0).floorToDouble();
    m = ((5 * d - 3) / 153.0).floorToDouble();
    d = 5 * d - 3 - 153 * m;
    d = ((d + 5) / 5.0).floorToDouble();
    y = 100 * y + j;
    if (m < 10) {
      m += 3;
    } else {
      m -= 9;
      y = y + 1;
    }
  }
  return (year: y.toInt(), month: m.toInt(), day: d.toInt());
}

/// `MyanmarDate.of(year, month, day, hour, minute, second)` for a Western
/// (Gregorian) date: any time of day gives the same Myanmar date.
MyanmarDate myanmarDateOfWestern(int year, int month, int day) =>
    // westernToJulian(...) + (0 - 12) / 24 at midnight.
    julianToMyanmarDate(westernToJulian(year, month, day) - 0.5);

/// The Julian day number of the Gregorian day [epochDay].
double julianDayOfEpochDay(int epochDay) {
  final c = civilOf(epochDay);
  return westernToJulian(c.year, c.month, c.day);
}
