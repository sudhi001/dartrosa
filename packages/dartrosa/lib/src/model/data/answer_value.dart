import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../util/java_double.dart';
import '../../util/java_lang.dart';
import '../data_type.dart';
import '../select_choice.dart';
import '../utils/date_utils.dart' as date_utils;
import '../utils/date_utils.dart' show DateFormatStyle;

/// The value of an instance node: a typed answer.
///
/// Port of `org.javarosa.core.model.data.IAnswerData` and its
/// implementations. Unlike JavaRosa's mutable classes these are immutable
/// values; JavaRosa never compares answers for equality, so value equality
/// here is safe.
@immutable
sealed class AnswerValue {
  const AnswerValue();

  /// The underlying value (a `String`, `int`, `double`, [Selection], …).
  Object get value;

  /// Human-readable text, as JavaRosa's `getDisplayText()`.
  String get displayText;

  /// The value as its XML string form.
  UncastValue uncast();
}

/// Implemented by answers that XPath can convert to a boolean or number
/// directly (geo values). Port of `org.javarosa.xpath.IExprDataType`.
abstract interface class ExprDataType {
  /// The value as an XPath boolean.
  bool toBoolean();

  /// The value as an XPath number.
  double toNumeric();
}

/// A raw string that has not been parsed into a typed answer.
final class UncastValue extends AnswerValue {
  /// Wraps [string].
  const UncastValue(this.string);

  /// The raw string.
  final String string;

  @override
  String get value => string;

  @override
  String get displayText => string;

  @override
  UncastValue uncast() => this;

  @override
  bool operator ==(Object other) =>
      other is UncastValue && string == other.string;

  @override
  int get hashCode => string.hashCode;

  @override
  String toString() => 'UncastValue{$string}';
}

/// A text answer.
final class StringValue extends AnswerValue {
  /// Wraps [string].
  const StringValue(this.string);

  /// Parses [data] (any string is valid).
  StringValue.cast(UncastValue data) : string = data.string;

  /// The text.
  final String string;

  @override
  String get value => string;

  @override
  String get displayText => string;

  @override
  UncastValue uncast() => UncastValue(string);

  @override
  bool operator ==(Object other) =>
      other is StringValue && string == other.string;

  @override
  int get hashCode => string.hashCode;

  @override
  String toString() => "StringData{s='$string'}";
}

/// A 32-bit integer answer.
final class IntegerValue extends AnswerValue {
  /// Wraps [n].
  const IntegerValue(this.n);

  /// Parses [data] with Java `Integer.parseInt` rules.
  factory IntegerValue.cast(UncastValue data) {
    final n = javaParseInt(data.string);
    if (n == null) {
      // JavaRosa's message says "Decimal" here.
      throw ArgumentError(
        'Invalid cast of data [${data.string}] to type Decimal',
      );
    }
    return IntegerValue(n);
  }

  /// The number.
  final int n;

  @override
  int get value => n;

  @override
  String get displayText => '$n';

  @override
  UncastValue uncast() => UncastValue('$n');

  @override
  bool operator ==(Object other) => other is IntegerValue && n == other.n;

  @override
  int get hashCode => n.hashCode;

  @override
  String toString() => 'IntegerData{n=$n}';
}

/// A 64-bit integer answer. (On the web Dart integers are exact only up to
/// 2^53.)
final class LongValue extends AnswerValue {
  /// Wraps [n].
  const LongValue(this.n);

  /// Parses [data] with Java `Long.parseLong` rules.
  factory LongValue.cast(UncastValue data) {
    final n = javaParseInt(data.string, bits: 64);
    if (n == null) {
      throw ArgumentError('Invalid cast of data [${data.string}] to type Long');
    }
    return LongValue(n);
  }

  /// The number.
  final int n;

  @override
  int get value => n;

  @override
  String get displayText => '$n';

  @override
  UncastValue uncast() => UncastValue('$n');

  @override
  bool operator ==(Object other) => other is LongValue && n == other.n;

  @override
  int get hashCode => n.hashCode;

  @override
  String toString() => 'LongData{n=$n}';
}

/// A decimal answer.
final class DecimalValue extends AnswerValue {
  /// Wraps [d].
  const DecimalValue(this.d);

  /// Parses [data] with Java `Double.parseDouble` rules.
  factory DecimalValue.cast(UncastValue data) {
    final d = javaParseDouble(data.string);
    if (d == null) {
      throw ArgumentError(
        'Invalid cast of data [${data.string}] to type Decimal',
      );
    }
    return DecimalValue(d);
  }

  /// The number.
  final double d;

  @override
  double get value => d;

  /// Java's `Double.toString`, e.g. `10.0` or `1.0E10`.
  @override
  String get displayText => javaDoubleToString(d);

  @override
  UncastValue uncast() => UncastValue(javaDoubleToString(d));

  /// Equal when Java's `Double.compare` is 0 (so `NaN == NaN` and
  /// `0.0 != -0.0`).
  @override
  bool operator ==(Object other) =>
      other is DecimalValue &&
      (d.isNaN
          ? other.d.isNaN
          : d == other.d && d.isNegative == other.d.isNegative);

  @override
  int get hashCode => d.isNaN ? double.nan.hashCode : d.hashCode;

  @override
  String toString() => 'DecimalData{d=${javaDoubleToString(d)}}';
}

/// A boolean answer, serialized as `1`/`0`.
final class BooleanValue extends AnswerValue {
  /// Wraps [b].
  const BooleanValue(this.b);

  /// JavaRosa's `BooleanData.cast` compares the string `"1"` with the
  /// `UncastData` object rather than its value, so it always fails. Ported
  /// as is; instance loading uses `XFormAnswerDataParser` instead.
  factory BooleanValue.cast(UncastValue data) => throw ArgumentError(
    'Invalid cast of data [${data.string}] to type Boolean',
  );

  /// The boolean.
  final bool b;

  @override
  bool get value => b;

  @override
  String get displayText => b ? 'True' : 'False';

  @override
  UncastValue uncast() => UncastValue(b ? '1' : '0');

  @override
  bool operator ==(Object other) => other is BooleanValue && b == other.b;

  @override
  int get hashCode => b.hashCode;

  @override
  String toString() => 'BooleanData{data=$b}';
}

/// One selected choice: its XML value and, once known, its index and
/// [SelectChoice].
///
/// Port of `org.javarosa.core.model.data.helper.Selection`.
@immutable
final class Selection {
  /// A selection by XML value; the choice is attached later.
  const Selection(String this.xmlValue) : index = -1, choice = null;

  /// A selection by choice index; the choice is attached later.
  const Selection.atIndex(this.index) : xmlValue = null, choice = null;

  /// A selection of [choice].
  Selection.ofChoice(SelectChoice this.choice)
    : xmlValue = choice.value,
      index = choice.index;

  /// The selected value, if known.
  final String? xmlValue;

  /// The selected choice's index, or -1.
  final int index;

  /// The selected choice, once attached.
  final SelectChoice? choice;

  /// The XML value. Throws if it is missing or empty.
  String get value {
    final xmlValue = this.xmlValue;
    if (xmlValue != null && xmlValue.isNotEmpty) return xmlValue;
    throw StateError(
      'This choice is not valid. If you are using an external file, please '
      'make sure it has the expected columns (usually name and label).',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Selection &&
      index == other.index &&
      xmlValue == other.xmlValue &&
      identical(choice, other.choice);

  @override
  int get hashCode => Object.hash(xmlValue, index, choice);
}

/// A `select1` answer.
final class SelectOneValue extends AnswerValue {
  /// Wraps [selection].
  const SelectOneValue(this.selection);

  /// Parses [data] as a selection by value.
  SelectOneValue.cast(UncastValue data) : selection = Selection(data.string);

  /// The selection.
  final Selection selection;

  @override
  Selection get value => selection;

  @override
  String get displayText => selection.value;

  @override
  UncastValue uncast() => UncastValue(selection.value);

  @override
  bool operator ==(Object other) =>
      other is SelectOneValue && selection == other.selection;

  @override
  int get hashCode => selection.hashCode;
}

/// A multiple-selection answer (`select`, `odk:rank`), serialized as
/// space-separated values.
base class MultipleItemsValue extends AnswerValue {
  /// Wraps [selections].
  MultipleItemsValue(List<Selection> selections)
    : selections = List.unmodifiable(selections);

  /// Parses [data]: space-separated values, empty pieces skipped.
  MultipleItemsValue.cast(UncastValue data)
    : selections = List.unmodifiable([
        for (final value in _splitOnSpaces(data.string)) Selection(value),
      ]);

  /// The selections, in order.
  final List<Selection> selections;

  @override
  List<Selection> get value => selections;

  @override
  String get displayText => selections.map((s) => s.value).join(', ');

  @override
  UncastValue uncast() => UncastValue(selections.map((s) => s.value).join(' '));

  @override
  bool operator ==(Object other) =>
      other is MultipleItemsValue &&
      other.runtimeType == runtimeType &&
      const ListEquality<Selection>().equals(selections, other.selections);

  @override
  int get hashCode => Object.hashAll(selections);
}

/// A `select` answer. Port of `SelectMultiData`.
final class SelectMultiValue extends MultipleItemsValue {
  /// Wraps [selections].
  SelectMultiValue(super.selections);
}

/// JavaRosa's `DateUtils.split(value, " ", true)`.
List<String> _splitOnSpaces(String value) =>
    value.split(' ').where((piece) => piece.isNotEmpty).toList();

/// A `geopoint`: latitude, longitude, altitude and accuracy.
final class GeoPointValue extends AnswerValue implements ExprDataType {
  /// A point from 2–4 [parts] (latitude, longitude, altitude, accuracy);
  /// missing parts are 0.
  GeoPointValue(List<double> parts)
    : _parts = List.unmodifiable([
        ...parts,
        for (var i = parts.length; i < 4; i++) missingValue,
      ]),
      length = parts.length {
    if (parts.length > 4) throw RangeError.range(parts.length, 0, 4, 'parts');
  }

  /// The empty point (0 0), as JavaRosa's default `GeoPointData()`.
  GeoPointValue.empty() : _parts = const [0, 0, 0, 0], length = requiredParts;

  /// Parses space-separated numbers. As in JavaRosa the result always has
  /// four parts (missing ones are 0).
  factory GeoPointValue.cast(UncastValue data) {
    final parts = [0.0, 0.0, missingValue, missingValue];
    var i = 0;
    for (final piece in _splitOnSpaces(data.string)) {
      final d = javaParseDouble(piece);
      if (d == null) throw FormatException('For input string: "$piece"');
      if (i >= 4) throw RangeError.index(i, parts);
      parts[i++] = d;
    }
    return GeoPointValue(parts);
  }

  /// Minimum number of parts (latitude and longitude).
  static const requiredParts = 2;

  /// Value of a missing part.
  static const missingValue = 0.0;

  /// Accuracy reported for an empty point.
  static const noAccuracyValue = 9999999.0;

  final List<double> _parts;

  /// How many parts were given (2–4).
  final int length;

  /// All four parts.
  @override
  List<double> get value => _parts;

  /// Part [i] (0 = latitude, 1 = longitude, 2 = altitude, 3 = accuracy).
  double part(int i) {
    if (i < length) return _parts[i];
    throw RangeError('Cannot find coordinates part with index $i');
  }

  /// `""` for the empty point, otherwise the given parts separated by
  /// spaces in Java number format.
  @override
  String get displayText =>
      !toBoolean() ? '' : _parts.take(length).map(javaDoubleToString).join(' ');

  @override
  UncastValue uncast() => UncastValue(displayText);

  /// Whether any part is non-zero.
  @override
  bool toBoolean() => _parts.any((p) => p != 0.0);

  /// The accuracy, or [noAccuracyValue] for the empty point.
  @override
  double toNumeric() => toBoolean() ? _parts[3] : noAccuracyValue;

  @override
  bool operator ==(Object other) =>
      other is GeoPointValue &&
      length == other.length &&
      const ListEquality<double>().equals(_parts, other._parts);

  @override
  int get hashCode => Object.hash(length, Object.hashAll(_parts));

  @override
  String toString() => displayText;
}

/// Shared behaviour of [GeoTraceValue] and [GeoShapeValue].
sealed class _GeoPointsValue extends AnswerValue implements ExprDataType {
  _GeoPointsValue(List<GeoPointValue> points)
    : points = List.unmodifiable(points);

  /// The points, in order.
  final List<GeoPointValue> points;

  @override
  List<GeoPointValue> get value => points;

  /// Points separated by `;`.
  @override
  String get displayText => points.map((p) => p.displayText).join(';');

  @override
  UncastValue uncast() => UncastValue(displayText);

  /// Whether there is at least one point.
  @override
  bool toBoolean() => points.isNotEmpty;

  /// The largest accuracy, or [GeoPointValue.noAccuracyValue] when empty.
  @override
  double toNumeric() {
    if (points.isEmpty) return GeoPointValue.noAccuracyValue;
    var max = 0.0;
    for (final p in points) {
      final accuracy = p.toNumeric();
      if (accuracy > max) max = accuracy;
    }
    return max;
  }

  static List<GeoPointValue> _castPoints(UncastValue data) => [
    for (final part in javaSplit(data.string, ';'))
      GeoPointValue.cast(UncastValue(javaTrim(part))),
  ];

  @override
  bool operator ==(Object other) =>
      other is _GeoPointsValue &&
      other.runtimeType == runtimeType &&
      const ListEquality<GeoPointValue>().equals(points, other.points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => displayText;
}

/// A `geotrace`: an open sequence of points.
final class GeoTraceValue extends _GeoPointsValue {
  /// Wraps [points].
  GeoTraceValue(super.points);

  /// Parses `;`-separated points.
  GeoTraceValue.cast(UncastValue data)
    : super(_GeoPointsValue._castPoints(data));
}

/// A `geoshape`: a closed sequence of points.
final class GeoShapeValue extends _GeoPointsValue {
  /// Wraps [points].
  GeoShapeValue(super.points);

  /// Parses `;`-separated points.
  GeoShapeValue.cast(UncastValue data)
    : super(_GeoPointsValue._castPoints(data));
}

/// A `date` answer: a local date at midnight.
final class DateValue extends AnswerValue {
  /// Wraps [date], rounded to local midnight.
  DateValue(DateTime date) : date = date_utils.roundDate(date)!;

  /// Parses an ISO 8601 date (`yyyy-mm-dd`).
  factory DateValue.cast(UncastValue data) {
    final date = date_utils.parseDate(data.string);
    if (date == null) {
      throw ArgumentError('Invalid cast of data [${data.string}] to type Date');
    }
    return DateValue(date);
  }

  /// The date (local midnight).
  final DateTime date;

  @override
  DateTime get value => date;

  /// `dd/mm/yy`.
  @override
  String get displayText =>
      date_utils.formatDate(date, DateFormatStyle.humanReadableShort);

  @override
  UncastValue uncast() =>
      UncastValue(date_utils.formatDate(date, DateFormatStyle.iso8601));

  @override
  bool operator ==(Object other) => other is DateValue && date == other.date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() =>
      "StringData{d='${date_utils.formatDate(date, DateFormatStyle.iso8601)}'}";
}

/// A `dateTime` answer.
final class DateTimeValue extends AnswerValue {
  /// Wraps [dateTime].
  const DateTimeValue(this.dateTime);

  /// Parses an ISO 8601 date-time.
  factory DateTimeValue.cast(UncastValue data) {
    final dateTime = date_utils.parseDateTime(data.string);
    if (dateTime == null) {
      throw ArgumentError(
        'Invalid cast of data [${data.string}] to type DateTime',
      );
    }
    return DateTimeValue(dateTime);
  }

  /// The instant.
  final DateTime dateTime;

  @override
  DateTime get value => dateTime;

  /// `dd/mm/yy hh:mm`.
  @override
  String get displayText =>
      date_utils.formatDateTime(dateTime, DateFormatStyle.humanReadableShort);

  /// ISO 8601 with the local offset, e.g. `2018-01-01T10:20:30.400+05:30`.
  @override
  UncastValue uncast() =>
      UncastValue(date_utils.formatDateTime(dateTime, DateFormatStyle.iso8601));

  @override
  bool operator ==(Object other) =>
      other is DateTimeValue && dateTime == other.dateTime;

  @override
  int get hashCode => dateTime.hashCode;
}

/// A `time` answer (stored on some date, as in JavaRosa).
final class TimeValue extends AnswerValue {
  /// Wraps [time].
  const TimeValue(this.time);

  /// Parses an ISO 8601 time, on today's date.
  factory TimeValue.cast(UncastValue data) {
    final time = date_utils.parseTime(data.string);
    if (time == null) {
      throw ArgumentError('Invalid cast of data [${data.string}] to type Time');
    }
    return TimeValue(time);
  }

  /// The time (with a date part).
  final DateTime time;

  @override
  DateTime get value => time;

  /// `hh:mm`.
  @override
  String get displayText =>
      date_utils.formatTime(time, DateFormatStyle.humanReadableShort);

  /// ISO 8601 with the local offset, e.g. `10:20:30.400+05:30`.
  @override
  UncastValue uncast() =>
      UncastValue(date_utils.formatTime(time, DateFormatStyle.iso8601));

  @override
  bool operator ==(Object other) => other is TimeValue && time == other.time;

  @override
  int get hashCode => time.hashCode;
}

/// Turns an XPath result into an answer for a node of [dataType], as when
/// storing a `calculate` result. Returns `null` for `''` and `NaN`.
///
/// Port of `IAnswerData.wrapData`:
/// * boolean nodes (or boolean results) become [BooleanValue] (numbers are
///   true unless zero, strings unless empty);
/// * numbers become [IntegerValue] for integer nodes or integral values in
///   the 32-bit range, else [LongValue] for long nodes or integral values,
///   else [DecimalValue];
/// * geo, select and date/time nodes parse the result's string form;
/// * other `DateTime`s become [DateTimeValue]; other strings [StringValue].
AnswerValue? wrapData(Object value, DataType dataType) {
  if ((value is String && value.isEmpty) || (value is double && value.isNaN)) {
    return null;
  }
  if (dataType == DataType.boolean || value is bool) {
    return BooleanValue(switch (value) {
      bool() => value,
      double() => value.abs() > 1.0e-12 && !value.isNaN,
      String() => value.isNotEmpty,
      _ => throw StateError(
        'unrecognized data representation while trying to convert to BOOLEAN',
      ),
    });
  }
  if (value is double) {
    final asLong = _javaLongCast(value);
    final isIntegral = (value - asLong).abs() < 1.0e-9;
    if (dataType == DataType.integer ||
        (isIntegral && asLong <= 2147483647 && asLong >= -2147483648)) {
      return IntegerValue(_javaIntCast(value));
    }
    if (dataType == DataType.long || isIntegral) return LongValue(asLong);
    return DecimalValue(value);
  }
  String text() => value is double ? javaDoubleToString(value) : '$value';
  switch (dataType) {
    case DataType.geopoint:
      return GeoPointValue.cast(UncastValue(text()));
    case DataType.geoshape:
      return GeoShapeValue.cast(UncastValue(text()));
    case DataType.geotrace:
      return GeoTraceValue.cast(UncastValue(text()));
    case DataType.choice:
      return SelectOneValue.cast(UncastValue(text()));
    case DataType.multipleItems:
      return MultipleItemsValue.cast(UncastValue(text()));
    case DataType.time:
      if (value is String) {
        final time = date_utils.parseTime(value);
        return time == null ? null : TimeValue(time);
      }
      return TimeValue(value as DateTime);
    case DataType.date:
      if (value is String) {
        final date = date_utils.parseDate(value);
        return date == null ? null : DateValue(date);
      }
      return DateValue(value as DateTime);
    case DataType.dateTime:
      if (value is String) {
        final dateTime = date_utils.parseDateTime(value);
        return dateTime == null ? null : DateTimeValue(dateTime);
      }
      return DateTimeValue(value as DateTime);
    default:
      if (value is DateTime) return DateTimeValue(value);
      if (value is String) return StringValue(value);
      throw StateError(
        "unrecognized data type in 'calculate' expression: "
        '${value.runtimeType}',
      );
  }
}

// Java Long.MAX_VALUE / MIN_VALUE. Parsed at runtime because dart2js can't
// compile integer literals beyond 2^53 (on the web they become the nearest
// double).
final int _maxLong = int.parse('9223372036854775807');
final int _minLong = int.parse('-9223372036854775808');

/// Java `(long) d`: truncates, saturating at the 64-bit range.
int _javaLongCast(double d) {
  if (d.isNaN) return 0;
  if (d >= 9223372036854775807.0) return _maxLong;
  if (d <= -9223372036854775808.0) return _minLong;
  return d.truncate();
}

/// Java `(int) d`: truncates, saturating at the 32-bit range.
int _javaIntCast(double d) {
  if (d.isNaN) return 0;
  if (d >= 2147483647) return 2147483647;
  if (d <= -2147483648) return -2147483648;
  return d.truncate();
}

/// Reference to binary data such as an attached file.
///
/// Port of `org.javarosa.core.model.data.IDataPointer`.
abstract interface class DataPointer {
  /// Text identifying the data, typically a file name.
  String get displayText;
}

/// An answer that points at binary data. Port of `PointerAnswerData`.
final class PointerValue extends AnswerValue {
  /// Wraps [pointer].
  const PointerValue(this.pointer);

  /// The pointer.
  final DataPointer pointer;

  @override
  DataPointer get value => pointer;

  @override
  String get displayText => pointer.displayText;

  @override
  UncastValue uncast() => UncastValue(pointer.displayText);

  @override
  bool operator ==(Object other) =>
      other is PointerValue && pointer == other.pointer;

  @override
  int get hashCode => pointer.hashCode;
}

/// An answer that points at several pieces of binary data. Port of
/// `MultiPointerAnswerData`.
final class MultiPointerValue extends AnswerValue {
  /// Wraps [pointers].
  MultiPointerValue(List<DataPointer> pointers)
    : pointers = List.unmodifiable(pointers);

  /// The pointers.
  final List<DataPointer> pointers;

  @override
  List<DataPointer> get value => pointers;

  @override
  String get displayText => pointers.map((p) => p.displayText).join(', ');

  @override
  UncastValue uncast() =>
      UncastValue(javaTrim(pointers.map((p) => '${p.displayText} ').join()));

  @override
  bool operator ==(Object other) =>
      other is MultiPointerValue &&
      const ListEquality<DataPointer>().equals(pointers, other.pointers);

  @override
  int get hashCode => Object.hashAll(pointers);
}

/// Parses [data] into the answer type for a node of [dataType].
///
/// Port of `AnswerDataFactory.templateByDataType(dataType).cast(data)`.
/// Barcode, binary, unsupported and untyped nodes keep [UncastValue].
/// Note that, as in JavaRosa, boolean nodes always fail
/// (see [BooleanValue.cast]).
AnswerValue castToDataType(UncastValue data, DataType dataType) =>
    switch (dataType) {
      DataType.choice => SelectOneValue.cast(data),
      DataType.multipleItems => MultipleItemsValue.cast(data),
      DataType.boolean => BooleanValue.cast(data),
      DataType.date => DateValue.cast(data),
      DataType.dateTime => DateTimeValue.cast(data),
      DataType.decimal => DecimalValue.cast(data),
      DataType.geopoint => GeoPointValue.cast(data),
      DataType.geoshape => GeoShapeValue.cast(data),
      DataType.geotrace => GeoTraceValue.cast(data),
      DataType.integer => IntegerValue.cast(data),
      DataType.long => LongValue.cast(data),
      DataType.text => StringValue.cast(data),
      DataType.time => TimeValue.cast(data),
      DataType.barcode ||
      DataType.binary ||
      DataType.unsupported ||
      DataType.nullType => UncastValue(data.string),
    };
