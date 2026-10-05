/// The XPath function library.
///
/// Port of `XPathFuncExpr.eval` and its helpers, including JavaRosa's
/// quirks (documented inline) so results match ODK Collect.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pinenacl/ed25519.dart' as ed25519;

import '../model/condition/evaluation_context.dart';
import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_reference.dart';
import '../model/utils/date_utils.dart' as date_utils;
import '../util/geo_utils.dart' as geo;
import '../util/java_base64.dart';
import '../util/java_double.dart';
import '../util/java_lang.dart';
import '../util/randomize.dart';
import '../util/uuid.dart';
import 'conversions.dart';
import 'exceptions.dart';
import 'expression.dart';
import 'nodeset.dart';

/// Evaluates the function call [call].
///
/// Built-in functions are checked first, then custom handlers registered on
/// [context], then its fallback handler; otherwise an
/// [XPathUnhandledException] is thrown. As in JavaRosa, a built-in called
/// with an unsupported number of arguments either throws (most functions)
/// or falls through to custom handlers (functions whose arity is part of
/// their match condition, e.g. `substr`).
Object evalFunction(
  XPathFuncExpr call,
  DataInstance? model,
  EvaluationContext context,
) {
  final name = call.id.toString();
  final exprs = call.args;
  final n = exprs.length;

  // Functions that evaluate their arguments lazily.
  switch (name) {
    case 'if':
      _assertArgsCount(name, n, 3);
      return toBoolean(exprs[0].eval(model, context))
          ? exprs[1].eval(model, context)
          : exprs[2].eval(model, context);
    case 'coalesce':
      _assertArgsCount(name, n, 2);
      final first = exprs[0].eval(model, context);
      return isNull(first) ? exprs[1].eval(model, context) : first;
    case 'indexed-repeat':
      if (n != 3 && n != 5 && n != 7 && n != 9 && n != 11) {
        throw XPathUnhandledException(
          "function '$name' requires 3, 5, 7, 9 or 11 arguments. Only $n "
          'provided.',
        );
      }
      return _indexedRepeat(model, context, exprs);
  }

  final args = [for (final expr in exprs) expr.eval(model, context)];

  switch (name) {
    case 'true':
      _assertArgsCount(name, n, 0);
      return true;
    case 'false':
      _assertArgsCount(name, n, 0);
      return false;
    case 'boolean':
      _assertArgsCount(name, n, 1);
      return toBoolean(args[0]);
    case 'number':
      _assertArgsCount(name, n, 1);
      return toNumeric(args[0]);
    case 'int':
      _assertArgsCount(name, n, 1);
      return toInt(args[0]);
    case 'round':
      final int places;
      if (n == 1) {
        places = 0;
      } else {
        _assertArgsCount(name, n, 2);
        places = javaIntCast(toNumeric(args[1]));
      }
      return _round(toNumeric(args[0]), places);
    case 'string':
      _assertArgsCount(name, n, 1);
      return toXPathString(args[0]);
    case 'date':
      _assertArgsCount(name, n, 1);
      return toDate(args[0], preserveTime: false);
    case 'date-time':
      _assertArgsCount(name, n, 1);
      return toDate(args[0], preserveTime: true);
    case 'decimal-date-time':
      _assertArgsCount(name, n, 1);
      return toDecimalDateTime(args[0], keepDate: true);
    case 'decimal-time':
      _assertArgsCount(name, n, 1);
      return toDecimalDateTime(args[0], keepDate: false);
    case 'not':
      _assertArgsCount(name, n, 1);
      return boolNot(args[0]);
    case 'boolean-from-string':
      _assertArgsCount(name, n, 1);
      return boolStr(args[0]);
    case 'format-date' || 'format-date-time':
      _assertArgsCount(name, n, 2);
      return _formatDateTime(args[0], args[1]);
    case 'abs':
      _checkArity(name, 1, n);
      return toDouble(args[0]).abs();
    case 'acos':
      _checkArity(name, 1, n);
      return math.acos(toDouble(args[0]));
    case 'asin':
      _checkArity(name, 1, n);
      return math.asin(toDouble(args[0]));
    case 'atan':
      _checkArity(name, 1, n);
      return math.atan(toDouble(args[0]));
    case 'atan2':
      _checkArity(name, 2, n);
      return math.atan2(toDouble(args[0]), toDouble(args[1]));
    case 'cos':
      _checkArity(name, 1, n);
      return math.cos(toDouble(args[0]));
    case 'exp':
      _checkArity(name, 1, n);
      return math.exp(toDouble(args[0]));
    case 'exp10':
      _checkArity(name, 1, n);
      return math.pow(10.0, toDouble(args[0])).toDouble();
    case 'log':
      _checkArity(name, 1, n);
      return math.log(toDouble(args[0]));
    case 'log10':
      _checkArity(name, 1, n);
      return _log10(toDouble(args[0]));
    case 'pi':
      _checkArity(name, 0, n);
      return math.pi;
    case 'sin':
      _checkArity(name, 1, n);
      return math.sin(toDouble(args[0]));
    case 'sqrt':
      _checkArity(name, 1, n);
      return math.sqrt(toDouble(args[0]));
    case 'tan':
      _checkArity(name, 1, n);
      return math.tan(toDouble(args[0]));
    case 'selected' || 'is-selected':
      _assertArgsCount(name, n, 2);
      return _multiSelected(args[0], args[1], name);
    case 'count-selected':
      _assertArgsCount(name, n, 1);
      return date_utils
          .split(
            unpack(args[0]) as String,
            ' ',
            combineMultipleDelimiters: true,
          )
          .length
          .toDouble();
    case 'selected-at':
      _assertArgsCount(name, n, 2);
      return _selectedAt(args[0], args[1]);
    case 'position':
      return _position(name, args, context);
    case 'count':
      _assertArgsCount(name, n, 1);
      return _nodesetArg(args[0]).size.toDouble();
    case 'count-non-empty':
      _assertArgsCount(name, n, 1);
      return _nodesetArg(args[0]).nonEmptySize.toDouble();
    case 'sum':
      _assertArgsCount(name, n, 1);
      var sum = 0.0;
      for (final value in _nodesetArg(args[0]).toArgList()) {
        final d = toNumeric(value);
        if (!d.isNaN) sum += d;
      }
      return sum;
    case 'max':
      return _max(_singleNodesetOr(args));
    case 'min':
      return _min(_singleNodesetOr(args));
    case 'today':
      _assertArgsCount(name, n, 0);
      return date_utils.roundDate(clock.now())!;
    case 'now':
      _assertArgsCount(name, n, 0);
      return clock.now();
    case 'concat':
      return _join('', _singleNodesetOr(args));
    case 'join' when n >= 1:
      final separator = args[0];
      if (args case [_, final XPathNodeset nodes]) {
        return _join(separator, nodes.toArgList());
      }
      return _join(separator, args.sublist(1));
    case 'substr' when n == 2 || n == 3:
      return _substring(args[0], args[1], n == 3 ? args[2] : null);
    case 'substring-before' when n == 2:
      final s = toXPathString(args[0]);
      final position = s.indexOf(toXPathString(args[1]));
      return position >= 0 ? s.substring(0, position) : '';
    case 'substring-after' when n == 2:
      final s = toXPathString(args[0]);
      final part = toXPathString(args[1]);
      final position = s.indexOf(part);
      return position >= 0 ? s.substring(position + part.length) : '';
    case 'translate' when n == 3:
      return _translate(
        toXPathString(args[0]),
        toXPathString(args[1]),
        toXPathString(args[2]),
      );
    case 'contains' when n == 2:
      return toXPathString(args[0]).contains(toXPathString(args[1]));
    case 'starts-with' when n == 2:
      return toXPathString(args[0]).startsWith(toXPathString(args[1]));
    case 'ends-with' when n == 2:
      return toXPathString(args[0]).endsWith(toXPathString(args[1]));
    case 'string-length' when n <= 1:
      return toXPathString(
        n == 1 ? args[0] : _currentNodeValue(model, context),
      ).length.toDouble();
    case 'normalize-space' when n <= 1:
      return _normalizeSpace(
        toXPathString(n == 1 ? args[0] : _currentNodeValue(model, context)),
      );
    case 'checklist' when n >= 2:
      final factors = switch (args) {
        [_, _, final XPathNodeset nodes] => nodes.toArgList(),
        _ => args.sublist(2),
      };
      return _checklist(args[0], args[1], factors);
    case 'weighted-checklist' when n >= 2 && n.isEven:
      final List<Object> factors;
      final List<Object> weights;
      if (args case [
        _,
        _,
        final XPathNodeset factorNodes,
        final XPathNodeset weightNodes,
      ]) {
        factors = factorNodes.toArgList();
        weights = weightNodes.toArgList();
        if (factors.length != weights.length) {
          throw XPathTypeMismatchException(
            'weighted-checklist: nodesets not same length',
          );
        }
      } else {
        factors = [for (var i = 2; i < n; i += 2) args[i]];
        weights = [for (var i = 3; i < n; i += 2) args[i]];
      }
      return _checklistWeighted(args[0], args[1], factors, weights);
    case 'regex':
      _assertArgsCount(name, n, 2);
      return javaRegexMatches(toXPathString(args[1]), toXPathString(args[0]));
    case 'depend' when n >= 1:
      return args[0];
    case 'random':
      _assertArgsCount(name, n, 0);
      return _random.nextDouble();
    case 'once':
      _assertArgsCount(name, n, 1);
      final current = _currentNodeValue(model, context);
      return toXPathString(current).isEmpty ? args[0] : current;
    case 'uuid' when n == 0 || n == 1:
      if (n == 0) return randomUuid();
      return _guid(javaIntCast(toInt(args[0])));
    case 'version':
      _assertArgsCount(name, n, 0);
      return (model is FormInstance ? model.formVersion : null) ?? '';
    case 'property':
      _assertArgsCount(name, n, 1);
      // JavaRosa returns null for an unknown property; see DEVIATIONS.md.
      return context.propertyLookup?.call(toXPathString(args[0])) ?? '';
    case 'pow' when n == 2:
      return math.pow(toDouble(args[0]), toDouble(args[1])).toDouble();
    case 'enclosed-area' || 'area':
      _assertArgsCount(name, n, 1);
      return geo.areaOfPolygon(_coordinatesFromNodeset(name, args[0]));
    case 'distance':
      return _distance(name, args);
    case 'geofence':
      _assertArgsCount(name, n, 2);
      final point = GeoPointValue.cast(UncastValue(toXPathString(args[0])));
      return geo.isPointInPolygon((
        latitude: point.part(0),
        longitude: point.part(1),
      ), _coordinatesFromNodeset(name, args[1]));
    case 'digest' when n == 2 || n == 3:
      return _digest(
        toXPathString(args[0]),
        toXPathString(args[1]),
        n == 3 ? toXPathString(args[2]) : 'base64',
      );
    case 'randomize':
      final nodes = args.isEmpty ? null : args[0];
      if (nodes is! XPathNodeset) {
        throw XPathTypeMismatchException(
          'First argument to randomize must be a nodeset',
        );
      }
      if (n == 1) return shuffleNodeset(nodes);
      if (n == 2) return shuffleNodeset(nodes, toNumericWithLongHash(args[1]));
      throw XPathUnhandledException(
        "function 'randomize' requires 1 or 2 arguments. $n provided.",
      );
    case 'base64-decode':
      _assertArgsCount(name, n, 1);
      return utf8.decode(
        javaBase64DecodeString(toXPathString(args[0])),
        allowMalformed: true,
      );
    case 'extract-signed':
      _assertArgsCount(name, n, 2);
      return _extractSigned(toXPathString(args[0]), toXPathString(args[1]));
  }

  final handler = context.functionHandlers[name];
  if (handler != null) return _evalCustom(handler, args, context);
  final fallback = context.fallbackFunctionHandler;
  if (fallback != null) return fallback.eval(name, args, context);
  throw XPathUnhandledException("function '$name'");
}

final _random = math.Random();

void _assertArgsCount(String name, int n, int count) {
  if (n != count) {
    throw XPathUnhandledException(
      "function '$name'. Requires $count arguments but $n provided.",
    );
  }
}

void _checkArity(String name, int expected, int provided) {
  if (expected != provided) {
    throw XPathArityException(name, expected, provided);
  }
}

/// [value] as a nodeset; throws when it is another kind of value.
XPathNodeset _nodesetArg(Object value) => value is XPathNodeset
    ? value
    : throw XPathTypeMismatchException('not a nodeset');

/// The values of a single nodeset argument, or the arguments themselves.
List<Object> _singleNodesetOr(List<Object> args) => switch (args) {
  [final XPathNodeset nodes] => nodes.toArgList(),
  _ => args,
};

/// The value of the context node (for `string-length()`, `once()` …).
Object _currentNodeValue(DataInstance? model, EvaluationContext context) =>
    XPathPathExpr.fromRef(context.contextRef).eval(model, context).unpack();

/// Java `Math.log10`, which is exact for powers of ten (`log(x) / ln10`
/// alone isn't, e.g. for 1000).
double _log10(double x) {
  final result = math.log(x) / math.ln10;
  final rounded = result.roundToDouble();
  if ((result - rounded).abs() < 1e-12 &&
      math.pow(10, rounded).toDouble() == x) {
    return rounded;
  }
  return result;
}

Object _indexedRepeat(
  DataInstance? model,
  EvaluationContext context,
  List<XPathExpression> exprs,
) {
  final target = exprs[0];
  if (target is! XPathPathExpr) {
    throw XPathTypeMismatchException(
      'indexed-repeat(): first parameter must be XPath field reference',
    );
  }
  final targetRef = target.toTreeReference().contextualize(context.contextRef)!;
  var contextRef = targetRef;
  for (
    var pathArg = 1, indexArg = 2;
    indexArg < exprs.length;
    pathArg += 2, indexArg += 2
  ) {
    final group = exprs[pathArg];
    if (group is! XPathPathExpr) {
      throw XPathTypeMismatchException(
        'indexed-repeat(): parameter ${pathArg + 1} must be a reference to a '
        'repeat',
      );
    }
    final groupRef = group.toTreeReference().contextualize(context.contextRef)!;
    if (!groupRef.isAncestorOf(targetRef, proper: true)) {
      throw XPathTypeMismatchException(
        'indexed-repeat(): parameter ${pathArg + 1} must be a parent of the '
        'field in parameter 1',
      );
    }
    var index = javaIntCast(toInt(exprs[indexArg].eval(model, context)));
    // An empty or invalid index (e.g. while a repeat is being added) means
    // the first instance.
    if (index <= 0) index = 1;
    contextRef = contextRef.withMultiplicity(groupRef.size - 1, index - 1);
  }
  return XPathPathExpr.fromRef(
    targetRef,
  ).evalIn(EvaluationContext.withContext(context, contextRef));
}

bool _multiSelected(Object list, Object choice, String functionName) {
  final value = unpack(choice);
  if (value is! String) {
    throw XPathTypeMismatchException(
      'The second parameter to the $functionName() function must be in '
      "quotes (like '1').",
    );
  }
  final selections = unpack(list) as String;
  return ' $selections '.contains(' ${javaTrim(value)} ');
}

String _selectedAt(Object list, Object index) {
  final selections = unpack(list) as String;
  final i = javaIntCast(toInt(index));
  final pieces = date_utils.split(
    selections,
    ' ',
    combineMultipleDelimiters: true,
  );
  return i >= 0 && i < pieces.length ? pieces[i] : '';
}

double _position(String name, List<Object> args, EvaluationContext context) {
  if (args.length == 1) {
    final nodes = args[0] as XPathNodeset;
    if (nodes.size == 0) return 1.0 + TreeReference.indexUnbound;
    // JavaRosa returns the first node's position.
    return 1.0 + nodes.refAt(0).lastMultiplicity;
  }
  if (args.isEmpty) {
    if (context.contextPosition != -1) return 1.0 + context.contextPosition;
    return 1.0 + context.contextRef.lastMultiplicity;
  }
  throw XPathUnhandledException(
    "function '$name' requires either exactly one argument or no arguments. "
    'Only ${args.length} provided.',
  );
}

/// JavaRosa starts from `Double.MIN_VALUE` (the smallest *positive*
/// double), so the maximum of only negative numbers is `4.9E-324`.
double _max(List<Object> values) {
  var max = 5e-324;
  var none = true;
  for (final value in values) {
    final d = toNumeric(value);
    if (!d.isNaN) {
      max = math.max(max, d);
      none = false;
    }
  }
  return none ? double.nan : max;
}

double _min(List<Object> values) {
  var min = double.maxFinite;
  var none = true;
  for (final value in values) {
    final d = toNumeric(value);
    if (!d.isNaN) {
      min = math.min(min, d);
      none = false;
    }
  }
  return none ? double.nan : min;
}

String _join(Object separator, List<Object> values) =>
    values.map(toXPathString).join(toXPathString(separator));

String _substring(Object string, Object startArg, Object? endArg) {
  final s = toXPathString(string);
  final length = s.length;
  var start = javaIntCast(toInt(startArg));
  var end = endArg != null ? javaIntCast(toInt(endArg)) : length;
  if (start < 0) start = length + start;
  if (end < 0) end = length + end;
  end = math.min(math.max(0, end), length);
  start = math.min(math.max(0, start), length);
  return start <= end ? s.substring(start, end) : '';
}

String _translate(String s, String from, String to) {
  final result = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final index = from.indexOf(c);
    if (index == -1) {
      result.write(c);
    } else if (index < to.length) {
      result.write(to[index]);
    }
  }
  return result.toString();
}

final _javaWhitespace = RegExp('[ \t\n\x0B\f\r]+');

/// Java's `s.trim().replaceAll("\\s+", " ")`.
String _normalizeSpace(String s) {
  var start = 0;
  var end = s.length;
  while (start < end && s.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && s.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  return s.substring(start, end).replaceAll(_javaWhitespace, ' ');
}

bool _checklist(Object minArg, Object maxArg, List<Object> factors) {
  final min = javaIntCast(toNumeric(minArg));
  final max = javaIntCast(toNumeric(maxArg));
  final count = factors.where(toBoolean).length;
  return (min < 0 || count >= min) && (max < 0 || count <= max);
}

bool _checklistWeighted(
  Object minArg,
  Object maxArg,
  List<Object> flags,
  List<Object> weights,
) {
  final min = toNumeric(minArg);
  final max = toNumeric(maxArg);
  var sum = 0.0;
  for (var i = 0; i < flags.length; i++) {
    final flag = toBoolean(flags[i]);
    final weight = toNumeric(weights[i]);
    if (flag) sum += weight;
  }
  return sum >= min && sum <= max;
}

final _javaInlineFlags = RegExp(r'^\(\?([ism]+)\)');

/// Java `Pattern.matches(regex, input)`: the whole input must match.
///
/// Leading inline flags `(?i)`, `(?s)`, `(?m)` are translated; other Java
/// regex features Dart lacks (possessive quantifiers, `\p{Alpha}`-style
/// classes) fail to compile. See DEVIATIONS.md.
bool javaRegexMatches(String regex, String input) {
  var pattern = regex;
  var caseSensitive = true;
  var dotAll = false;
  var multiLine = false;
  final flags = _javaInlineFlags.firstMatch(pattern);
  if (flags != null) {
    final f = flags.group(1)!;
    caseSensitive = !f.contains('i');
    dotAll = f.contains('s');
    multiLine = f.contains('m');
    pattern = pattern.substring(flags.end);
  }
  return RegExp(
    '^(?:$pattern)\$',
    caseSensitive: caseSensitive,
    dotAll: dotAll,
    multiLine: multiLine,
  ).hasMatch(input);
}

String _formatDateTime(Object value, Object format) {
  final date = toDate(value, preserveTime: true);
  return date is DateTime ? date_utils.format(date, toXPathString(format)) : '';
}

/// Port of `BigDecimal(Double.toString(n)).setScale(places, HALF_UP)`
/// (HALF_DOWN for negatives), and the negative-places branch.
double _round(double number, int places) {
  if (number.isNaN || number.isInfinite) return number;
  if (places > 30 || places < -30) return double.nan;
  final decimal = _Decimal.parse(javaDoubleToString(number));
  if (places >= 0) {
    return decimal.setScale(places, halfUp: number >= 0).toDouble();
  }
  // round(33.33, -1) == 30.0: scale, add 0.5, truncate to long, unscale.
  final scaled = decimal.scaleByPowerOfTen(places).toDouble();
  final rounded = javaLongValue(scaled + 0.5);
  return _Decimal.parse(
    javaDoubleToString(rounded),
  ).scaleByPowerOfTen(-places).toDouble();
}

/// A minimal exact decimal: `unscaled * 10^-scale`.
final class _Decimal {
  _Decimal(this.unscaled, this.scale);

  /// Parses Java's double notation, e.g. `-1.25` or `1.0E-5`.
  factory _Decimal.parse(String text) {
    final e = text.indexOf('E');
    final mantissa = e < 0 ? text : text.substring(0, e);
    final exponent = e < 0 ? 0 : int.parse(text.substring(e + 1));
    final point = mantissa.indexOf('.');
    final digits = mantissa.replaceFirst('.', '');
    final fractionDigits = point < 0 ? 0 : mantissa.length - point - 1;
    return _Decimal(BigInt.parse(digits), fractionDigits - exponent);
  }

  final BigInt unscaled;
  final int scale;

  _Decimal scaleByPowerOfTen(int n) => _Decimal(unscaled, scale - n);

  /// Rounds to [newScale] digits: ties away from zero when [halfUp], ties
  /// toward zero otherwise (BigDecimal HALF_UP / HALF_DOWN).
  _Decimal setScale(int newScale, {required bool halfUp}) {
    if (newScale >= scale) {
      return _Decimal(
        unscaled * BigInt.from(10).pow(newScale - scale),
        newScale,
      );
    }
    final divisor = BigInt.from(10).pow(scale - newScale);
    final negative = unscaled.isNegative;
    final magnitude = unscaled.abs();
    var quotient = magnitude ~/ divisor;
    final twiceRemainder = (magnitude % divisor) * BigInt.two;
    final cmp = twiceRemainder.compareTo(divisor);
    if (cmp > 0 || (cmp == 0 && halfUp)) quotient += BigInt.one;
    return _Decimal(negative ? -quotient : quotient, newScale);
  }

  /// Correctly rounded conversion, like `BigDecimal.doubleValue()`.
  double toDouble() {
    final digits = unscaled.abs().toString();
    final sign = unscaled.isNegative ? '-' : '';
    return double.parse('$sign${digits}e${-scale}');
  }
}

List<geo.LatLong> _coordinatesFromNodeset(String name, Object value) {
  if (value is! XPathNodeset) {
    throw XPathUnhandledException(
      "function '$name' requires a field as the parameter.",
    );
  }
  final values = value.toArgList();
  if (values.length == 1) {
    try {
      return [
        for (final point in GeoShapeValue.cast(
          UncastValue(toXPathString(values[0])),
        ).points)
          (latitude: point.part(0), longitude: point.part(1)),
      ];
    } on Object {
      throw _geoMismatch(name);
    }
  }
  if (values.length >= 2) return _geopointsToLatLongs(name, values);
  return [];
}

List<geo.LatLong> _geopointsToLatLongs(String name, List<Object> values) => [
  for (final value in values) _toLatLong(name, value),
];

geo.LatLong _toLatLong(String name, Object value) {
  try {
    final point = GeoPointValue.cast(UncastValue(toXPathString(value)));
    return (latitude: point.part(0), longitude: point.part(1));
  } on Object {
    throw _geoMismatch(name);
  }
}

XPathTypeMismatchException _geoMismatch(String name) =>
    XPathTypeMismatchException(
      "The function '$name' received a value that does not represent GPS "
      'coordinates',
    );

double _distance(String name, List<Object> args) {
  if (args.length == 1) {
    final arg = args[0];
    if (arg is XPathNodeset) {
      return geo.distance(_coordinatesFromNodeset(name, arg));
    }
    if (arg is String) {
      return geo.distance(_geopointsToLatLongs(name, javaSplit(arg, ';')));
    }
    throw XPathUnhandledException(
      "function 'distance' requires a field or text as the parameter.",
    );
  }
  if (args.length > 1) return geo.distance(_geopointsToLatLongs(name, args));
  throw XPathUnhandledException(
    "function 'distance' requires at least one parameter.",
  );
}

String _digest(String payload, String algorithmName, String encodingName) {
  final hash = switch (algorithmName.toUpperCase().replaceAll('-', '')) {
    'MD5' => crypto.md5,
    'SHA1' => crypto.sha1,
    'SHA256' => crypto.sha256,
    'SHA384' => crypto.sha384,
    'SHA512' => crypto.sha512,
    _ => throw XPathUnsupportedException("digest(..., '$algorithmName', ...)"),
  };
  final bytes = hash.convert(utf8.encode(payload)).bytes;
  return switch (encodingName.toUpperCase()) {
    'BASE64' => javaBase64Encode(bytes),
    'HEX' => hexEncode(bytes),
    _ => throw XPathUnsupportedException("digest(..., ..., '$encodingName')"),
  };
}

/// The seed for `randomize(nodes, seed)`: the number (as a Java `long`),
/// or a hash of the text when it isn't a number.
double toNumericWithLongHash(Object value) {
  final d = toNumeric(value);
  if (d.isNaN) return longHash(unpack(value) as String);
  return javaLongValue(d);
}

/// A shuffled copy of [nodes], seeded when [seed] is given.
XPathNodeset shuffleNodeset(XPathNodeset nodes, [double? seed]) => XPathNodeset(
  shuffle(nodes.references!, seed),
  nodes.instance,
  nodes.context,
);

/// Verifies an Ed25519 signature (the first 64 bytes of [contents]) over
/// the rest and returns the signed text, or `''`.
String _extractSigned(String contents, String publicKey) {
  final contentBytes = javaBase64DecodeString(contents);
  final keyBytes = javaBase64DecodeString(publicKey);
  if (contentBytes.length < 64) return '';
  final signature = contentBytes.sublist(0, 64);
  final message = contentBytes.sublist(64);
  try {
    final verifyKey = ed25519.VerifyKey(keyBytes);
    final valid = verifyKey.verify(
      signature: ed25519.Signature(signature),
      message: message,
    );
    return valid ? utf8.decode(message, allowMalformed: true) : '';
  } on Object {
    // Too short or invalid key: JavaRosa returns "".
    return '';
  }
}

/// `uuid(n)`: [length] random base-36 characters, upper case.
String _guid(int length) => [
  for (var i = 0; i < length; i++) _random.nextInt(36).toRadixString(36),
].join().toUpperCase();

/// Matches [args] to the handler's prototypes (converting types), falling
/// back to the raw arguments when the handler accepts them.
Object _evalCustom(
  XPathFunctionHandler handler,
  List<Object> args,
  EvaluationContext context,
) {
  for (final prototype in handler.prototypes) {
    final typed = _matchPrototype(args, prototype);
    if (typed != null) return handler.eval(typed, context);
  }
  if (handler.rawArgs) return handler.eval(args, context);
  throw XPathTypeMismatchException("for function '${handler.name}'");
}

List<Object>? _matchPrototype(List<Object> args, List<XPathArgType> types) {
  if (types.length != args.length) return null;
  final typed = <Object>[];
  for (var i = 0; i < types.length; i++) {
    final arg = args[i];
    final type = types[i];
    if (type.accepts(arg)) {
      typed.add(arg);
      continue;
    }
    try {
      final converted = switch (type) {
        XPathArgType.boolean => toBoolean(arg),
        XPathArgType.number => toNumeric(arg),
        XPathArgType.string => toXPathString(arg),
        XPathArgType.date => toDate(arg, preserveTime: false),
        _ => null,
      };
      if (converted == null) return null;
      typed.add(converted);
    } on XPathTypeMismatchException {
      return null;
    }
  }
  return typed;
}
