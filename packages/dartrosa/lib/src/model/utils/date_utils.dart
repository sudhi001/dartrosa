/// Date and time helpers with JavaRosa-identical behaviour.
///
/// Port of `org.javarosa.core.model.utils.DateUtils`. A Dart [DateTime] in
/// local time stands in for `java.util.Date`, and the local (device) time
/// zone stands in for Java's default `TimeZone`; "now" comes from
/// `package:clock`, so tests can fix it.
///
/// Java's default `Locale` affects month/day names (`%b`, `%a`) and week
/// numbering (`%W` on dates from [getFields]). Here the locale is an
/// optional parameter (an ICU/BCP 47 tag such as `en_US`, `es-ES` or `fr`)
/// defaulting to US English.
library;

import 'package:clock/clock.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';
import 'package:meta/meta.dart';

/// Output styles for [formatDateTime], [formatDate] and [formatTime].
///
/// Port of the `DateUtils.FORMAT_*` constants.
enum DateFormatStyle {
  /// `2018-01-07T10:20:30.400-05:00`
  iso8601,

  /// `07/01/18 10:20`
  humanReadableShort,

  /// `Today`, `Yesterday`, `3 days ago`, … (date part only).
  humanReadableDaysFromToday,

  /// `20180107102030`
  timestampSuffix,

  /// RFC 822, in UTC: `Sun, 07 Jan 2018 15:20:30 GMT`
  timestampHttp,
}

/// Milliseconds in a day.
const dayInMilliseconds = 86400000;

/// Calendar fields of a date-time.
///
/// Port of `DateUtils.DateFields`.
@immutable
final class DateFields {
  /// Creates fields; defaults are 1970-01-01 00:00:00.000, `dow` 0 and
  /// `week` 1, as in JavaRosa.
  const DateFields({
    this.year = 1970,
    this.month = 1,
    this.day = 1,
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
    this.secTicks = 0,
    this.dow = 0,
    this.week = 1,
  });

  /// Fields for a valid date-time, with `dow` (Sunday = 0 … Saturday = 6)
  /// and the ISO 8601 `week` computed from it.
  ///
  /// Throws [ArgumentError] for an invalid date-time, as Joda's
  /// `LocalDateTime` does.
  factory DateFields.of(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    int secTicks,
  ) {
    _validate(year, month, day, hour, minute, second, secTicks);
    final epochDay = _epochDay(year, month, day);
    final isoDow = _isoDayOfWeek(epochDay);
    return DateFields(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      secTicks: secTicks,
      dow: isoDow == 7 ? 0 : isoDow,
      week: _weekOfYear(year, epochDay, _WeekRules.iso),
    );
  }

  /// Year.
  final int year;

  /// Month, 1–12.
  final int month;

  /// Day of month, 1–31.
  final int day;

  /// Hour of day, 0–23.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// Second, 0–59.
  final int second;

  /// Milliseconds, 0–999.
  final int secTicks;

  /// Week of year, 1–53.
  final int week;

  /// Day of week. Not used to specify a date. Note JavaRosa's two
  /// conventions: [getFields] gives Sunday = 1 … Saturday = 7 (Java
  /// `Calendar`), [DateFields.of] gives Sunday = 0 … Saturday = 6.
  final int dow;

  /// Whether every field is in range.
  bool check() =>
      _inRange(month, 1, 12) &&
      _inRange(day, 1, daysInMonth(month - 1, year)) &&
      _inRange(hour, 0, 23) &&
      _inRange(minute, 0, 59) &&
      _inRange(second, 0, 59) &&
      _inRange(secTicks, 0, 999) &&
      _inRange(week, 1, 53);

  /// A copy with the given fields replaced.
  DateFields copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? secTicks,
    int? dow,
    int? week,
  }) => DateFields(
    year: year ?? this.year,
    month: month ?? this.month,
    day: day ?? this.day,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    second: second ?? this.second,
    secTicks: secTicks ?? this.secTicks,
    dow: dow ?? this.dow,
    week: week ?? this.week,
  );

  @override
  bool operator ==(Object other) =>
      other is DateFields &&
      year == other.year &&
      month == other.month &&
      day == other.day &&
      hour == other.hour &&
      minute == other.minute &&
      second == other.second &&
      secTicks == other.secTicks &&
      dow == other.dow &&
      week == other.week;

  @override
  int get hashCode =>
      Object.hash(year, month, day, hour, minute, second, secTicks, dow, week);

  @override
  String toString() =>
      'DateFields($year-$month-$day $hour:$minute:$second.$secTicks '
      'dow=$dow week=$week)';
}

/// The calendar fields of [d] in the local zone, or in [timeZone] (`UTC`,
/// `GMT` or a fixed offset such as `GMT+02:00`). `dow` follows Java's
/// `Calendar` (Sunday = 1) and `week` the week rules of [locale].
DateFields getFields(DateTime d, {String? timeZone, String? locale}) {
  final DateTime wall;
  if (timeZone == null) {
    wall = d.toLocal();
  } else {
    final offset = _fixedOffset(timeZone);
    wall = d.toUtc().add(Duration(milliseconds: offset));
  }
  // java.util.Calendar's hybrid calendar: Julian dates before the
  // Gregorian cutover, and the year of the era (1 BC is year 1).
  final (year, month, day) = _hybridDate(
    _floorDiv(
      DateTime.utc(wall.year, wall.month, wall.day).millisecondsSinceEpoch,
      dayInMilliseconds,
    ),
  );
  return DateFields(
    year: year > 0 ? year : 1 - year,
    month: month,
    day: day,
    hour: wall.hour,
    minute: wall.minute,
    second: wall.second,
    secTicks: wall.millisecond,
    dow: wall.weekday % 7 + 1,
    week: _weekOfYear(
      wall.year,
      _epochDay(wall.year, wall.month, wall.day),
      _WeekRules.forLocale(locale),
    ),
  );
}

/// The instant whose wall-clock time is [f] in the local zone (or in
/// [timeZone]).
///
/// Mirrors Joda's `LocalDateTime.toDate()`: a wall time skipped by a DST
/// gap is read with the offset before the gap (02:30 becomes 03:30), and a
/// wall time repeated by a DST overlap resolves to its earlier occurrence.
/// Throws [ArgumentError] for invalid fields.
DateTime getDateFromFields(DateFields f, {String? timeZone}) {
  _validate(f.year, f.month, f.day, f.hour, f.minute, f.second, f.secTicks);
  final wall = _hybridWallMillis(f);
  if (timeZone != null) {
    return DateTime.fromMillisecondsSinceEpoch(wall - _fixedOffset(timeZone));
  }
  return DateTime.fromMillisecondsSinceEpoch(_localWallToInstant(wall));
}

// ==== FORMATTING DATES/TIMES TO STANDARD STRINGS ====

/// Formats [d] with [style] (date and time); `''` for `null`.
///
/// [localize] supplies the texts for [DateFormatStyle.humanReadableDaysFromToday]
/// (see [formatDate]).
String formatDateTime(
  DateTime? d,
  DateFormatStyle style, {
  String? locale,
  DaysFromTodayLocalizer? localize,
}) {
  if (d == null) return '';
  final fields = getFields(
    d,
    timeZone: style == DateFormatStyle.timestampHttp ? 'UTC' : null,
    locale: locale,
  );
  final delimiter = switch (style) {
    DateFormatStyle.iso8601 => 'T',
    DateFormatStyle.timestampSuffix => '',
    _ => ' ',
  };
  // JavaRosa has no time part for humanReadableDaysFromToday and prints
  // "null" there; kept for identical output.
  return '${_formatDate(fields, style, locale, localize)}$delimiter'
      '${_formatTime(fields, style, locale)}';
}

/// Formats the date part of [d] with [style]; `''` for `null`.
///
/// For [DateFormatStyle.humanReadableDaysFromToday], [localize] maps
/// JavaRosa's message keys (`date.today`, `date.yesterday`, `date.twoago`,
/// `date.nago`, `date.tomorrow`, `date.nfromnow`) and their arguments to
/// text. JavaRosa reads them from its global `Localization` and fails when
/// none are registered; DartRosa falls back to English.
String formatDate(
  DateTime? d,
  DateFormatStyle style, {
  String? locale,
  DaysFromTodayLocalizer? localize,
}) => d == null
    ? ''
    : _formatDate(
        getFields(
          d,
          timeZone: style == DateFormatStyle.timestampHttp ? 'UTC' : null,
          locale: locale,
        ),
        style,
        locale,
        localize,
      );

/// Formats the time part of [d] with [style]; `''` for `null` and for
/// [DateFormatStyle.humanReadableDaysFromToday], which has no time part.
String formatTime(DateTime? d, DateFormatStyle style, {String? locale}) =>
    d == null
    ? ''
    : _formatTime(
            getFields(
              d,
              timeZone: style == DateFormatStyle.timestampHttp ? 'UTC' : null,
              locale: locale,
            ),
            style,
            locale,
          ) ??
          '';

/// Looks up the text for a JavaRosa message [key] with [args].
typedef DaysFromTodayLocalizer = String Function(String key, List<String> args);

String _formatDate(
  DateFields f,
  DateFormatStyle style,
  String? locale,
  DaysFromTodayLocalizer? localize,
) => switch (style) {
  DateFormatStyle.iso8601 =>
    '${f.year}-${intPad(f.month, 2)}-${intPad(f.day, 2)}',
  DateFormatStyle.humanReadableShort => _formatDateColloquial(f),
  DateFormatStyle.humanReadableDaysFromToday => _formatDaysFromToday(
    f,
    localize ?? _englishDaysFromToday,
  ),
  DateFormatStyle.timestampSuffix =>
    '${f.year}${intPad(f.month, 2)}${intPad(f.day, 2)}',
  DateFormatStyle.timestampHttp => formatFields(
    f,
    '%a, %d %b %Y',
    locale: locale,
  ),
};

String? _formatTime(DateFields f, DateFormatStyle style, String? locale) =>
    switch (style) {
      DateFormatStyle.iso8601 => _formatTimeIso8601(f),
      DateFormatStyle.humanReadableShort =>
        '${intPad(f.hour, 2)}:${intPad(f.minute, 2)}',
      DateFormatStyle.timestampSuffix =>
        '${intPad(f.hour, 2)}${intPad(f.minute, 2)}${intPad(f.second, 2)}',
      DateFormatStyle.timestampHttp => formatFields(
        f,
        '%H:%M:%S GMT',
        locale: locale,
      ),
      DateFormatStyle.humanReadableDaysFromToday => null,
    };

String _formatDateColloquial(DateFields f) {
  var year = '${f.year}';
  // Only shorten normal 4-digit years.
  if (year.length == 4) year = year.substring(2, 4);
  return '${intPad(f.day, 2)}/${intPad(f.month, 2)}/$year';
}

String _formatTimeIso8601(DateFields f) {
  var time =
      '${intPad(f.hour, 2)}:${intPad(f.minute, 2)}:${intPad(f.second, 2)}'
      '.${intPad(f.secTicks, 3)}';
  final offset = _offsetForWallTime(_hybridWallMillis(f), f.year);
  if (offset == 0) {
    time += 'Z';
  } else {
    final minutes = offset.abs() ~/ 1000 ~/ 60;
    time +=
        '${offset > 0 ? '+' : '-'}${intPad(minutes ~/ 60, 2)}'
        ':${intPad(minutes % 60, 2)}';
  }
  return time;
}

/// Formats [d] (as local fields) with a `%`-escape [pattern]; see
/// [formatFields].
String format(DateTime d, String pattern, {String? locale}) =>
    formatFields(getFields(d, locale: locale), pattern, locale: locale);

/// Formats [f] with a [pattern] of `%` escapes: `%Y` 4-digit year, `%y`
/// 2-digit year, `%m` 0-padded month, `%n` month, `%b` short month name,
/// `%d` 0-padded day, `%e` day, `%H` 0-padded hour, `%h` hour, `%M`
/// 0-padded minute, `%S` 0-padded second, `%3` 0-padded milliseconds, `%a`
/// short day name, `%W` week of year, `%%` a literal `%`.
///
/// Names use [locale] (default US English). Throws [FormatException] with
/// JavaRosa's message for a trailing `%` or an unknown escape.
String formatFields(DateFields f, String pattern, {String? locale}) {
  final sb = StringBuffer();
  for (var i = 0; i < pattern.length; i++) {
    var c = pattern[i];
    if (c != '%') {
      sb.write(c);
      continue;
    }
    i++;
    if (i >= pattern.length) {
      throw const FormatException('date format string ends with %');
    }
    c = pattern[i];
    sb.write(switch (c) {
      '%' => '%',
      'Y' => intPad(f.year, 4),
      'y' => intPad(f.year, 4).substring(2),
      'm' => intPad(f.month, 2),
      'n' => '${f.month}',
      'b' => _symbols(locale).SHORTMONTHS[f.month - 1],
      'd' => intPad(f.day, 2),
      'e' => '${f.day}',
      'H' => intPad(f.hour, 2),
      'h' => '${f.hour}',
      'M' => intPad(f.minute, 2),
      'S' => intPad(f.second, 2),
      '3' => intPad(f.secTicks, 3),
      'a' => _symbols(
        locale,
      ).SHORTWEEKDAYS[_isoDayOfWeek(_epochDay(f.year, f.month, f.day)) % 7],
      'W' => '${f.week}',
      'Z' || 'A' || 'B' => throw FormatException(
        'unsupported escape in date format string [%$c]',
      ),
      _ => throw FormatException(
        'unrecognized escape in date format string [%$c]',
      ),
    });
  }
  return sb.toString();
}

// ==== PARSING DATES/TIMES FROM STANDARD STRINGS ====

/// Parses `yyyy-mm-dd` optionally followed by `T` and a time (see
/// [parseTime]); `null` if invalid.
///
/// As in JavaRosa, an empty time part (`2020-01-01T`) throws ([RangeError])
/// and a malformed offset throws [FormatException].
DateTime? parseDateTime(String s) {
  var fields = const DateFields();
  final i = s.indexOf('T');
  if (i != -1) {
    final date = _parseDate(s.substring(0, i), fields);
    if (date == null) return null;
    final time = _parseTime(s.substring(i + 1), date);
    if (time == null) return null;
    fields = time;
  } else {
    final date = _parseDate(s, fields);
    if (date == null) return null;
    fields = date;
  }
  return getDateFromFields(fields);
}

/// Parses `yyyy-mm-dd` as local midnight; `null` if invalid.
DateTime? parseDate(String s) {
  final fields = _parseDate(s, const DateFields());
  return fields == null ? null : getDateFromFields(fields);
}

/// Parses `hh:mm[:ss[.sss]]` with an optional `Z` or `±hh[:mm]` offset,
/// on today's local date; `null` if invalid.
DateTime? parseTime(String s) {
  final now = getFields(clock.now());
  return parseTimeWithFixedDate(s, now.copyWith(second: 0, secTicks: 0));
}

/// Like [parseTime], on the date given by [fields].
DateTime? parseTimeWithFixedDate(String s, DateFields fields) {
  final parsed = _parseTime(s, fields);
  return parsed == null ? null : getDateFromFields(parsed);
}

DateFields? _parseDate(String dateStr, DateFields f) {
  final pieces = split(dateStr, '-');
  if (pieces.length != 3) return null;
  final year = _javaParseInt(pieces[0]);
  final month = _javaParseInt(pieces[1]);
  final day = _javaParseInt(pieces[2]);
  if (year == null || month == null || day == null) return null;
  final result = f.copyWith(year: year, month: month, day: day);
  return result.check() ? result : null;
}

DateFields? _parseTime(String timeStr, DateFields f) {
  // Offset to add to get UTC (the sign of the written offset is inverted).
  int? offsetHours;
  var offsetMinutes = 0;
  if (timeStr[timeStr.length - 1] == 'Z') {
    timeStr = timeStr.substring(0, timeStr.length - 1);
    offsetHours = 0;
  } else if (timeStr.contains('+') || timeStr.contains('-')) {
    var pieces = split(timeStr, '+');
    var sign = -1;
    if (pieces.length == 1) {
      pieces = split(timeStr, '-');
      sign = 1;
    }
    timeStr = pieces[0];
    final offset = pieces[1];
    var hours = offset;
    if (offset.contains(':')) {
      final tzPieces = split(offset, ':');
      hours = tzPieces[0];
      offsetMinutes = _javaParseIntOrThrow(tzPieces[1]) * sign;
    }
    offsetHours = _javaParseIntOrThrow(hours) * sign;
  }

  final raw = _parseRawTime(timeStr, f);
  if (raw == null || !raw.check()) return null;
  if (offsetHours == null) return raw;

  // Read the fields as UTC, apply the offset, then express in local time.
  final utc = _hybridWallMillis(raw);
  final instant = DateTime.fromMillisecondsSinceEpoch(
    utc + (60 * offsetHours + offsetMinutes) * 60 * 1000,
  );
  final adjusted = getFields(instant);
  // JavaRosa copies everything except the week.
  final result = raw.copyWith(
    year: adjusted.year,
    month: adjusted.month,
    day: adjusted.day,
    dow: adjusted.dow,
    hour: adjusted.hour,
    minute: adjusted.minute,
    second: adjusted.second,
    secTicks: adjusted.secTicks,
  );
  return result.check() ? result : null;
}

/// Parses `hh:mm[:ss[.sss]]` without offset into [f].
DateFields? _parseRawTime(String timeStr, DateFields f) {
  final pieces = split(timeStr, ':');
  if (pieces.length != 2 && pieces.length != 3) return null;
  final hour = _javaParseInt(pieces[0]);
  final minute = _javaParseInt(pieces[1]);
  if (hour == null || minute == null) return null;
  var second = f.second;
  var secTicks = f.secTicks;
  if (pieces.length == 3) {
    var secStr = pieces[2];
    var i = 0;
    for (; i < secStr.length; i++) {
      final c = secStr.codeUnitAt(i);
      if (!_isJavaDigit(c) && c != 0x2E) break;
    }
    secStr = secStr.substring(0, i);
    // JavaRosa first parses the parts as integers (failing on e.g.
    // "1.2.3"), then recomputes both from the decimal value.
    final point = secStr.indexOf('.');
    final secPart = point == -1 ? secStr : secStr.substring(0, point);
    final tickPart = point == -1 ? '' : secStr.substring(point + 1);
    if (secPart.isNotEmpty && _javaParseInt(secPart) == null) return null;
    if (tickPart.isNotEmpty && _javaParseInt(tickPart) == null) return null;
    final fsec = _javaParseDouble(secStr);
    if (fsec == null) return null;
    second = fsec.toInt();
    secTicks = (1000.0 * fsec - 1000.0 * second).toInt();
  }
  final result = f.copyWith(
    hour: hour,
    minute: minute,
    second: second,
    secTicks: secTicks,
  );
  return result.check() ? result : null;
}

// ==== DATE UTILITY FUNCTIONS ====

/// Local midnight of [year]-[month]-[day], or `null` if invalid.
DateTime? getDate(int year, int month, int day) {
  final f = DateFields(year: year, month: month, day: day);
  return f.check() ? getDateFromFields(f) : null;
}

/// Local midnight of the day of [d]; `null` for `null`.
DateTime? roundDate(DateTime? d) {
  if (d == null) return null;
  final f = getFields(d);
  return getDate(f.year, f.month, f.day);
}

/// Local midnight today.
DateTime today() => roundDate(clock.now())!;

/// The fraction of the local day elapsed at [d].
///
/// As in JavaRosa, the zone offset used is the one in effect *now*, not at
/// [d].
double decimalTimeOfLocalDay(DateTime d) {
  final milli =
      d.millisecondsSinceEpoch + clock.now().timeZoneOffset.inMilliseconds;
  final v = milli / dayInMilliseconds;
  return v - v.floorToDouble();
}

/// Days in [month0] (Java `Calendar` month: January = 0) of [year].
int daysInMonth(int month0, int year) {
  if (month0 == 3 || month0 == 5 || month0 == 8 || month0 == 10) return 30;
  if (month0 == 1) return 28 + (isLeap(year) ? 1 : 0);
  return 31;
}

/// Whether [year] is a leap year in the proleptic Gregorian calendar.
bool isLeap(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

/// Default English texts for [DateFormatStyle.humanReadableDaysFromToday].
String _englishDaysFromToday(String key, List<String> args) => switch (key) {
  'date.today' => 'Today',
  'date.yesterday' => 'Yesterday',
  'date.twoago' => '${args.first} days ago',
  'date.nago' => '${args.first} days ago',
  'date.tomorrow' => 'Tomorrow',
  'date.nfromnow' => '${args.first} days from now',
  _ => key,
};

String _formatDaysFromToday(DateFields f, DaysFromTodayLocalizer localize) {
  final daysAgo =
      daysSinceEpoch(clock.now()) - daysSinceEpoch(getDateFromFields(f));
  if (daysAgo == 0) return localize('date.today', const []);
  if (daysAgo == 1) return localize('date.yesterday', const []);
  if (daysAgo == 2) return localize('date.twoago', ['$daysAgo']);
  if (daysAgo > 2 && daysAgo <= 6) return localize('date.nago', ['$daysAgo']);
  if (daysAgo == -1) return localize('date.tomorrow', const []);
  if (daysAgo < -1 && daysAgo >= -6) {
    return localize('date.nfromnow', ['${-daysAgo}']);
  }
  return _formatDate(f, DateFormatStyle.humanReadableShort, null, null);
}

// ==== DATE OPERATIONS ====

/// The first (or, unless [beginning], last) day of a period before [ref].
///
/// [type] must be `week` (or `month`, which JavaRosa doesn't support and
/// returns `null` for); [start] is the period's first weekday (`sun` …
/// `sat`); [includeToday] lets [ref] count as the period's last day; [nAgo]
/// is how many periods back (0 = the period in progress).
DateTime? getPastPeriodDate(
  DateTime ref,
  String type,
  String start, {
  required bool beginning,
  required bool includeToday,
  required int nAgo,
}) {
  if (type == 'month') return null;
  if (type != 'week') throw ArgumentError.value(type, 'type');
  const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  final targetDow = days.indexOf(start);
  if (targetDow == -1) throw ArgumentError.value(start, 'start');
  final offset = includeToday ? 1 : 0;
  final currentDow = ref.toLocal().weekday % 7;
  final diff =
      (((currentDow - targetDow) + (7 + offset)) % 7 - offset) +
      (7 * nAgo) -
      (beginning ? 0 : 6);
  return DateTime.fromMillisecondsSinceEpoch(
    ref.millisecondsSinceEpoch - diff * dayInMilliseconds,
  );
}

/// Months between two dates, computed as JavaRosa does: the year/month of
/// the duration read as a local date after the epoch.
int getMonthsDifference(DateTime earlier, DateTime later) {
  final span = DateTime.fromMillisecondsSinceEpoch(
    later.millisecondsSinceEpoch - earlier.millisecondsSinceEpoch,
  );
  final first = DateTime.fromMillisecondsSinceEpoch(0);
  return (span.year - first.year) * 12 + (span.month - first.month);
}

/// Whole local days from 1970-01-01 to [d].
int daysSinceEpoch(DateTime d) => dateDiff(getDate(1970, 1, 1)!, d);

/// Fractional days from local midnight 1970-01-01 to [d].
double fractionalDaysSinceEpoch(DateTime d) =>
    (d.millisecondsSinceEpoch - getDate(1970, 1, 1)!.millisecondsSinceEpoch) /
    dayInMilliseconds;

/// Local midnight [n] days after the day of [d].
DateTime dateAdd(DateTime d, int n) => roundDate(
  DateTime.fromMillisecondsSinceEpoch(
    roundDate(d)!.millisecondsSinceEpoch +
        dayInMilliseconds * n +
        dayInMilliseconds ~/ 2, // handles differing DST offsets
  ),
)!;

/// Days from the day of [a] to the day of [b] (positive if [b] is later).
int dateDiff(DateTime a, DateTime b) {
  final ms =
      roundDate(b)!.millisecondsSinceEpoch -
      roundDate(a)!.millisecondsSinceEpoch +
      dayInMilliseconds ~/ 2; // handles differing DST offsets
  return (ms - ms % dayInMilliseconds) ~/ dayInMilliseconds;
}

// ==== UTILITY ====

/// Splits [s] at every [delimiter]; with [combineMultipleDelimiters],
/// empty pieces are dropped.
List<String> split(
  String s,
  String delimiter, {
  bool combineMultipleDelimiters = false,
}) {
  if (delimiter.isEmpty) throw ArgumentError.value(delimiter, 'delimiter');
  final pieces = s.split(delimiter);
  return combineMultipleDelimiters
      ? pieces.where((p) => p.isNotEmpty).toList()
      : pieces;
}

/// [n] as a string left-padded with `0` to [pad] characters (JavaRosa pads
/// the sign too: `intPad(-5, 3)` is `0-5`).
String intPad(int n, int pad) => '$n'.padLeft(pad, '0');

/// `formatDateTime(date, DateFormatStyle.iso8601)`.
String formatDateToTimeStamp(DateTime d) =>
    formatDateTime(d, DateFormatStyle.iso8601);

/// `formatDate(d, DateFormatStyle.humanReadableShort)`.
String getShortStringValue(DateTime d) =>
    formatDate(d, DateFormatStyle.humanReadableShort);

/// `formatDate(d, DateFormatStyle.iso8601)`, e.g. `2018-01-07`.
String getXmlStringValue(DateTime d) => formatDate(d, DateFormatStyle.iso8601);

/// `formatTime(d, DateFormatStyle.humanReadableShort)`, e.g. `10:20`.
String get24HourTimeFromDate(DateTime d) =>
    formatTime(d, DateFormatStyle.humanReadableShort);

/// [parseDate].
DateTime? getDateFromString(String value) => parseDate(value);

/// [parseDateTime].
DateTime? getDateTimeFromString(String value) => parseDateTime(value);

/// Whether [string] contains [substring] (`false` if either is `null`).
bool stringContains(String? string, String? substring) =>
    string != null && substring != null && string.contains(substring);

// ==== INTERNALS ====

bool _inRange(int x, int min, int max) => x >= min && x <= max;

/// Joda `LocalDateTime` field validation.
void _validate(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  int millis,
) {
  if (!_inRange(month, 1, 12) ||
      !_inRange(day, 1, daysInMonth(month - 1, year)) ||
      !_inRange(hour, 0, 23) ||
      !_inRange(minute, 0, 59) ||
      !_inRange(second, 0, 59) ||
      !_inRange(millis, 0, 999)) {
    throw ArgumentError(
      'Invalid date-time: $year-$month-$day $hour:$minute:$second.$millis',
    );
  }
}

/// The first day of the Gregorian calendar in `java.util.GregorianCalendar`
/// (1582-10-15), as days since 1970-01-01.
const _gregorianCutoverEpochDay = -141427;

/// Wall-clock milliseconds since 1970-01-01 for [f] read like Java's
/// hybrid calendar (`new Date(y - 1900, …)`, as Joda's
/// `LocalDateTime.toDate()` does): dates before the Gregorian cutover —
/// including the ten skipped days, leniently — are Julian; year 0 is 1 BC.
int _hybridWallMillis(DateFields f) {
  final gregorian = _epochDay(f.year, f.month, f.day);
  final day = gregorian >= _gregorianCutoverEpochDay
      ? gregorian
      : _julianEpochDay(f.year, f.month, f.day);
  return day * dayInMilliseconds +
      ((f.hour * 60 + f.minute) * 60 + f.second) * 1000 +
      f.secTicks;
}

/// Days since 1970-01-01 of the Julian-calendar date (astronomical year).
int _julianEpochDay(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  final julianDayNumber =
      day + (153 * m + 2) ~/ 5 + 365 * y + _floorDiv(y, 4) - 32083;
  return julianDayNumber - 2440588;
}

/// The (astronomical year, month, day) of [epochDay] in Java's hybrid
/// calendar: Gregorian from the cutover, Julian before.
(int, int, int) _hybridDate(int epochDay) {
  if (epochDay >= _gregorianCutoverEpochDay) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochDay * dayInMilliseconds,
      isUtc: true,
    );
    return (d.year, d.month, d.day);
  }
  final c = epochDay + 2440588 + 32082;
  final d = _floorDiv(4 * c + 3, 1461);
  final e = c - _floorDiv(1461 * d, 4);
  final m = (5 * e + 2) ~/ 153;
  return (
    d - 4800 + m ~/ 10,
    m + 3 - 12 * (m ~/ 10),
    e - (153 * m + 2) ~/ 5 + 1,
  );
}

int _floorDiv(int a, int b) => (a - (a % b)) ~/ b;

/// Days since 1970-01-01 of a proleptic Gregorian date.
int _epochDay(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ dayInMilliseconds;

/// ISO day of week (Monday = 1 … Sunday = 7) of an epoch day.
int _isoDayOfWeek(int epochDay) => (epochDay + 3) % 7 + 1;

/// Week-numbering rules: the first day of the week (ISO numbering) and the
/// minimum number of days of the year in week 1.
final class _WeekRules {
  const _WeekRules(this.firstDayOfWeek, this.minimalDays);

  /// ISO 8601: weeks start Monday; week 1 contains January 4th.
  static const iso = _WeekRules(1, 4);

  /// Java's rules for a locale without a region (and the US).
  static const us = _WeekRules(7, 1);

  final int firstDayOfWeek;
  final int minimalDays;

  /// Java's `Calendar` week data depends only on the locale's region; a
  /// language-only locale gets the US rules.
  static _WeekRules forLocale(String? locale) {
    if (locale == null) return us;
    final normalized = locale.replaceAll('-', '_');
    if (!normalized.contains('_')) return us;
    final symbols = _symbols(normalized);
    // intl: FIRSTDAYOFWEEK 0 = Monday; week 1 is the week containing the
    // first FIRSTWEEKCUTOFFDAY of the year.
    final first = symbols.FIRSTDAYOFWEEK;
    final position = (symbols.FIRSTWEEKCUTOFFDAY - first + 7) % 7;
    return _WeekRules(first + 1, 7 - position);
  }
}

/// `Calendar.WEEK_OF_YEAR` of the date [epochDay] in [year].
int _weekOfYear(int year, int epochDay, _WeekRules rules) {
  final start = _week1Start(year, rules);
  if (epochDay < start) {
    return (epochDay - _week1Start(year - 1, rules)) ~/ 7 + 1;
  }
  if (epochDay >= _week1Start(year + 1, rules)) return 1;
  return (epochDay - start) ~/ 7 + 1;
}

int _week1Start(int year, _WeekRules rules) {
  final jan1 = _epochDay(year, 1, 1);
  final intoWeek = (_isoDayOfWeek(jan1) - rules.firstDayOfWeek + 7) % 7;
  final weekStart = jan1 - intoWeek;
  return 7 - intoWeek >= rules.minimalDays ? weekStart : weekStart + 7;
}

final Map<String, DateSymbols> _symbolMap = dateTimeSymbolMap();

/// CLDR date symbols for [locale]: exact match, then language, then `en`.
DateSymbols _symbols(String? locale) {
  if (locale == null) return _symbolMap['en_US']!;
  final normalized = locale.replaceAll('-', '_');
  return _symbolMap[normalized] ??
      _symbolMap[normalized.split('_').first] ??
      _symbolMap['en']!;
}

/// Offset in milliseconds of a supported time zone name.
int _fixedOffset(String timeZone) {
  if (timeZone == 'UTC' || timeZone == 'GMT' || timeZone == 'Z') return 0;
  final match = RegExp(
    r'^GMT([+-])(\d{1,2})(?::?(\d{2}))?$',
  ).firstMatch(timeZone);
  if (match == null) {
    throw ArgumentError.value(timeZone, 'timeZone', 'unsupported time zone');
  }
  final minutes = int.parse(match[2]!) * 60 + int.parse(match[3] ?? '0');
  return (match[1] == '-' ? -minutes : minutes) * 60 * 1000;
}

int _offsetAt(int instantMs) => DateTime.fromMillisecondsSinceEpoch(
  instantMs,
).timeZoneOffset.inMilliseconds;

/// The instant for a local wall time (milliseconds as if UTC), resolving
/// DST gaps and overlaps like Joda's `LocalDateTime.toDate()`.
int _localWallToInstant(int wall) {
  final before = _offsetAt(wall - dayInMilliseconds);
  final after = _offsetAt(wall + dayInMilliseconds);
  final candidates = <int>{
    for (final offset in [before, after])
      if (_offsetAt(wall - offset) == offset) wall - offset,
  };
  if (candidates.isEmpty) return wall - before; // gap
  return candidates.reduce((a, b) => a < b ? a : b); // overlap → earlier
}

/// Java `TimeZone.getOffset(era, year, month, day, dow, millis)`: the
/// offset in effect when the wall time is read as local *standard* time.
int _offsetForWallTime(int wall, int year) {
  final raw = [
    DateTime(year, 1, 1).timeZoneOffset.inMilliseconds,
    DateTime(year, 7, 1).timeZoneOffset.inMilliseconds,
  ].reduce((a, b) => a < b ? a : b);
  return _offsetAt(wall - raw);
}

/// Java `Character.isDigit(char)`.
bool _isJavaDigit(int c) => _javaDigitValue(c) != null;

final _unicodeDigit = RegExp(r'^\p{Nd}$', unicode: true);

/// Java `Character.digit(c, 10)`, or `null` if [c] is not a decimal digit.
int? _javaDigitValue(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c < 0x80 || !_unicodeDigit.hasMatch(String.fromCharCode(c))) {
    return null;
  }
  // Unicode decimal digits come in runs of ten, 0 to 9.
  var value = 0;
  while (value < 9 &&
      _unicodeDigit.hasMatch(String.fromCharCode(c - value - 1))) {
    value++;
  }
  return value;
}

/// Java `Integer.parseInt`: optional sign, decimal digits (any Unicode
/// digits), 32-bit range; `null` where Java throws.
int? _javaParseInt(String s) {
  if (s.isEmpty) return null;
  var i = 0;
  var negative = false;
  if (s[0] == '-' || s[0] == '+') {
    negative = s[0] == '-';
    i = 1;
    if (s.length == 1) return null;
  }
  var value = 0;
  for (; i < s.length; i++) {
    final digit = _javaDigitValue(s.codeUnitAt(i));
    if (digit == null) return null;
    value = value * 10 + digit;
    if (value > 2147483648) return null;
  }
  if (negative) value = -value;
  return value < -2147483648 || value > 2147483647 ? null : value;
}

int _javaParseIntOrThrow(String s) =>
    _javaParseInt(s) ?? (throw FormatException('For input string: "$s"'));

/// Java `Double.parseDouble` for strings of ASCII digits and dots.
double? _javaParseDouble(String s) {
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(s)) return null;
  return double.parse(s.endsWith('.') ? '${s}0' : s);
}
