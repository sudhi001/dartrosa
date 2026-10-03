/// XPath type conversions and value unpacking.
///
/// Port of the conversion helpers in `XPathFuncExpr` (`toBoolean`,
/// `toNumeric`, `toString`, `toInt`, `unpack`, …) and of
/// `XPathPathExpr.getRefValue`/`unpackValue`. XPath values are `bool`,
/// `double`, `String`, `DateTime`, [ExprDataType] or [XPathNodeset].
library;

import '../model/condition/evaluation_context.dart';
import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_reference.dart';
import '../model/utils/date_utils.dart' as date_utils;
import '../model/utils/date_utils.dart' show DateFormatStyle;
import '../util/java_double.dart';
import '../util/java_lang.dart';
import 'exceptions.dart';
import 'nodeset.dart';

/// The single value of a nodeset; other values unchanged.
Object unpack(Object value) => value is XPathNodeset ? value.unpack() : value;

/// Whether [value] is XPath's "empty": `''` or `NaN`.
bool isNull(Object? value) {
  if (value == null) return true;
  final unpacked = unpack(value);
  return (unpacked is String && unpacked.isEmpty) ||
      (unpacked is double && unpacked.isNaN);
}

/// XPath `boolean()`.
bool toBoolean(Object value) {
  final o = unpack(value);
  return switch (o) {
    bool() => o,
    double() => o.abs() > 1.0e-12 && !o.isNaN,
    String() => o.isNotEmpty,
    DateTime() => true,
    ExprDataType() => o.toBoolean(),
    _ => throw XPathTypeMismatchException('converting to boolean'),
  };
}

/// XPath `number()`. Strings may use `,` as decimal separator; scientific
/// notation and `Infinity` are not numbers.
double toNumeric(Object value) {
  final o = unpack(value);
  return switch (o) {
    bool() => o ? 1 : 0,
    double() => o,
    String() => _stringToNumber(o),
    DateTime() => date_utils.daysSinceEpoch(o).toDouble(),
    ExprDataType() => o.toNumeric(),
    _ => throw XPathTypeMismatchException('converting to numeric'),
  };
}

double _stringToNumber(String s) {
  final trimmed = _javaTrim(s.replaceAll(',', '.'));
  for (final c in trimmed.codeUnits) {
    if (c != 0x2D && c != 0x2E && (c < 0x30 || c > 0x39)) return double.nan;
  }
  return javaParseDouble(trimmed) ?? double.nan;
}

/// Java `String.trim()`: strips characters `<= ' '`.
String _javaTrim(String s) {
  var start = 0;
  var end = s.length;
  while (start < end && s.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && s.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  return s.substring(start, end);
}

/// Like [toNumeric], but a date becomes fractional days since the epoch.
double toDouble(Object value) => value is DateTime
    ? date_utils.fractionalDaysSinceEpoch(value)
    : toNumeric(value);

/// The non-standard `int()`: truncates toward zero (keeping `-0.0` for
/// small negatives); NaN, infinities and values outside the 64-bit range
/// are returned unchanged.
double toInt(Object value) {
  final d = toNumeric(value);
  if (d.isInfinite || d.isNaN) return d;
  if (d >= 9223372036854775807.0 || d <= -9223372036854775808.0) return d;
  final truncated = d.truncateToDouble();
  if (truncated == 0 && (d < 0 || (d == 0 && d.isNegative))) return -0.0;
  return truncated == 0 ? 0.0 : truncated;
}

/// Java's `(int) d` cast: truncates and saturates at the 32-bit range;
/// NaN becomes 0.
int javaIntCast(double d) {
  if (d.isNaN) return 0;
  if (d >= 2147483647) return 2147483647;
  if (d <= -2147483648) return -2147483648;
  return d.truncate();
}

/// XPath `string()`.
///
/// Numbers print as integers when within 1e-12 of `(int) d`; because
/// Java's cast saturates at 2^31, larger whole numbers print in Java
/// notation (`string(10000000000)` is `1.0E10`).
String toXPathString(Object value) {
  final o = unpack(value);
  return switch (o) {
    bool() => o ? 'true' : 'false',
    double() => _numberToString(o),
    String() => o,
    DateTime() => date_utils.formatDate(o, DateFormatStyle.iso8601),
    ExprDataType() => o.toString(),
    _ => throw XPathTypeMismatchException('converting to string'),
  };
}

String _numberToString(double d) {
  if (d.isNaN) return 'NaN';
  if (d.abs() < 1.0e-12) return '0';
  if (d.isInfinite) return d < 0 ? '-Infinity' : 'Infinity';
  final asInt = javaIntCast(d);
  if ((d - asInt).abs() < 1.0e-12) return '$asInt';
  return javaDoubleToString(d);
}

/// The non-standard `date()` (or, with [preserveTime], `date-time()`):
/// converts an ISO 8601 string, a number of days since the epoch or a
/// date. `''` and `NaN` are returned unchanged.
Object toDate(Object input, {required bool preserveTime}) {
  final o = unpack(input);
  switch (o) {
    case double():
      final n = preserveTime ? o : toInt(o);
      if (n.isNaN) return n;
      if (n.isInfinite || n > 2147483647 || n < -2147483648) {
        throw XPathTypeMismatchException(
          'The value "${javaDoubleToString(n)}" is out of range for '
          'representing a date.',
        );
      }
      if (preserveTime) {
        return DateTime.fromMillisecondsSinceEpoch((n * _dayInMs).truncate());
      }
      return date_utils.dateAdd(date_utils.getDate(1970, 1, 1)!, n.toInt());
    case String():
      if (o.isEmpty) return o;
      final date = date_utils.parseDateTime(o);
      if (date == null) {
        throw XPathTypeMismatchException(
          'The value "$o" can\'t be converted to a date.',
        );
      }
      return date;
    case DateTime():
      return preserveTime ? o : date_utils.roundDate(o)!;
    default:
      throw XPathTypeMismatchException(
        'The value "$o" can\'t be converted to a date.',
      );
  }
}

const _dayInMs = 86400000;

/// `decimal-date-time()` (fractional days since the epoch, [keepDate]) or
/// `decimal-time()` (fraction of the local day).
Object toDecimalDateTime(Object input, {required bool keepDate}) {
  final o = unpack(input);
  double fromDate(DateTime d) => keepDate
      ? d.millisecondsSinceEpoch / _dayInMs
      : date_utils.decimalTimeOfLocalDay(d);
  switch (o) {
    case double():
      if (o.isNaN) return o;
      if (o.isInfinite || o > 2147483647 || o < -2147483648) {
        throw XPathTypeMismatchException(
          'The value "${javaDoubleToString(o)}" is out of range for '
          'representing a date.',
        );
      }
      return keepDate ? o : o - o.floorToDouble();
    case String():
      if (o.isEmpty) return o;
      final date = date_utils.parseDateTime(o);
      if (date == null) {
        throw XPathTypeMismatchException(
          'The value "$o" can\'t be converted to a date.',
        );
      }
      return fromDate(date);
    case DateTime():
      return fromDate(o);
    default:
      throw XPathTypeMismatchException(
        'The value "$o" can\'t be converted to a date.',
      );
  }
}

/// XPath `not()`.
bool boolNot(Object value) => !toBoolean(value);

/// `boolean-from-string()`: true for `true` (any case) or `1`.
bool boolStr(Object value) {
  final s = toXPathString(value);
  return s.toLowerCase() == 'true' || s == '1';
}

/// The XPath value of an answer: `''` for none, numbers as `double`,
/// selections as their values, geo values as text.
///
/// Port of `XPathPathExpr.unpackValue`.
Object unpackValue(AnswerValue? value) => switch (value) {
  null => '',
  UncastValue() => value.string,
  IntegerValue() => value.n.toDouble(),
  LongValue() => value.n.toDouble(),
  DecimalValue() => value.d,
  StringValue() => value.string,
  SelectOneValue() => value.selection.value,
  MultipleItemsValue() => value.uncast().string,
  BooleanValue() => value.b,
  GeoPointValue() || GeoTraceValue() || GeoShapeValue() => value.displayText,
  _ => value.value,
};

/// The XPath value of the node at [ref]: the candidate value when it is
/// the node being validated, `''` for a non-relevant or empty node.
///
/// Port of `XPathPathExpr.getRefValue`.
Object getRefValue(
  DataInstance model,
  EvaluationContext context,
  TreeReference ref,
) {
  if (context.isConstraint && ref == context.contextRef) {
    return unpackValue(context.candidateValue);
  }
  final node = model.resolveReference(ref);
  if (node == null) {
    // Shouldn't happen: only existing nodes are in a nodeset.
    throw XPathTypeMismatchException('Node $ref does not exist!');
  }
  return unpackValue(node.isRelevant ? node.value : null);
}
