// Port of JavaRosa v6.0.0 XPathEvalTest (cases generated from the Java
// source; setup statements translated by hand) and IFunctionHandlerHelpers.
import 'dart:math' as math;

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/utils/date_utils.dart' as date_utils;
import 'package:dartrosa/src/util/java_double.dart';
import 'package:dartrosa/src/xpath/conversions.dart' as conversions;
import 'package:dartrosa/src/xpath/nodeset.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// Marker for an expected exception of exactly type [T] (JavaRosa compares
/// exception classes exactly).
final class Throws<T> {
  const Throws();

  bool matches(Object error) => error.runtimeType == T;

  @override
  String toString() => '$T';
}

Throws<T> throws<T>() => Throws<T>();

late EvaluationContext ec;

void testEval(
  String expr,
  Object? expected, {
  FormInstance? model,
  EvaluationContext? context,
}) {
  final expression = parseXPath(expr);
  final evalContext = context ?? EvaluationContext(model);
  if (expected is Throws) {
    try {
      final result = expression.eval(model, evalContext);
      fail('expected $expected evaluating $expr, got $result');
    } on TestFailure {
      rethrow;
    } on Object catch (error) {
      expect(
        expected.matches(error),
        isTrue,
        reason: 'evaluating $expr threw ${error.runtimeType}: $error',
      );
    }
    return;
  }
  final result = expression.eval(model, evalContext);
  switch (expected) {
    case double():
      expect(result, isA<double>(), reason: expr);
      if (expected.isNaN) {
        expect((result as double).isNaN, isTrue, reason: expr);
      } else if (expected.isInfinite) {
        expect(result, expected, reason: expr);
      } else {
        expect(result, closeTo(expected, 1e-12), reason: expr);
      }
    case XPathNodeset():
      final actual = result as XPathNodeset;
      expect(actual.size, expected.size, reason: expr);
      expect(actual.refAt(0), expected.refAt(0), reason: expr);
      expect(actual.unpack(), expected.unpack(), reason: expr);
      expect(actual.toArgList(), expected.toArgList(), reason: expr);
    default:
      expect(result, expected, reason: expr);
  }
}

XPathNodeset createExpectedNodesetFromInstance(
  FormInstance instance,
  String nodeName,
  int index,
) {
  final ref = instance.root.childrenWithName(nodeName)[index].ref;
  return XPathNodeset(
    [ref],
    instance,
    EvaluationContext.withContext(EvaluationContext(instance), ref),
  );
}

XPathNodeset createExpectedNodesetFromIndexedRepeatFunction(
  FormInstance instance,
  int repeatIndex,
  String nodeName,
) {
  final ref = instance.root
      .childAt(repeatIndex)
      .childrenWithName(nodeName)
      .first
      .ref;
  return XPathNodeset(
    [ref],
    instance,
    EvaluationContext.withContext(EvaluationContext(instance), ref),
  );
}

/// Faithful to JavaRosa's test data: the three repeats all get
/// multiplicity 0 and `index1` is never attached, so both cases resolve to
/// the first repeat.
FormInstance createTestDataForIndexedRepeatFunction(int? indexNodeValue) {
  final root = TreeElement('data');
  for (final name in ['A', 'B', 'C']) {
    final child = TreeElement('name')..setAnswer(StringValue(name));
    root.addChild(TreeElement('repeat')..addChild(child));
  }
  final index = TreeElement('index1');
  if (indexNodeValue != null) index.value = const IntegerValue(1);
  return FormInstance(root);
}

FormInstance buildInstance() {
  final data = TreeElement('data')
    ..addChild(
      TreeElement('path', 0)
        ..addChild(TreeElement('child', 0))
        ..addChild(TreeElement('child', 1)),
    )
    ..addChild(TreeElement('path', 1))
    ..addChild(
      TreeElement('path', 2)..value = const StringValue('    some    value'),
    )
    ..addChild(TreeElement('path', 3)..addChild(TreeElement('child', 0)))
    ..addChild(TreeElement('path', 4))
    ..addChild(
      TreeElement('geoshape', 0)
        ..value = const StringValue('0 0 0 0;0 1 0 0;1 1 0 0;1 0 0 0;0 0 0 0'),
    );
  return FormInstance(data);
}

// ---------------------------------------------------------------- handlers

final class _Handler extends XPathFunctionHandler {
  _Handler(this.name, this._eval, this.prototypes, {this.rawArgs = false});

  @override
  final String name;

  @override
  final List<List<XPathArgType>> prototypes;

  @override
  final bool rawArgs;

  final Object Function(List<Object> args) _eval;

  @override
  Object eval(List<Object> args, EvaluationContext context) => _eval(args);
}

final class _Convertible implements ExprDataType {
  @override
  bool toBoolean() => true;

  @override
  double toNumeric() => 5.0;

  @override
  String toString() => 'hi';
}

@immutable
class CustomType {
  @override
  String toString() => '';

  @override
  bool operator ==(Object other) => other is CustomType;

  @override
  int get hashCode => 0;
}

class CustomSubType extends CustomType {}

/// Java class names as JavaRosa's printArgs shows them.
String printArgs(List<Object> args) =>
    '[${args.map((a) {
      final (type, text) = switch (a) {
        double() => ('Double', javaDoubleToString(a)),
        String() => ('String', a),
        bool() => ('Boolean', '$a'),
        DateTime() => ('Date', date_utils.formatDate(a, date_utils.DateFormatStyle.iso8601)),
        CustomSubType() => ('CustomSubType', '$a'),
        CustomType() => ('CustomType', '$a'),
        _ => ('${a.runtimeType}', '$a'),
      };
      return '$type:$text';
    }).join(',')}]';

final handlerRegex = _Handler('regex', (_) => true, [
  [XPathArgType.string, XPathArgType.string],
]);
final handlerTestfunc = _Handler('testfunc', (_) => true, [[]]);
final handlerInconvertible = _Handler('inconvertible', (_) => Object(), [[]]);
final handlerConvertible = _Handler('convertible', (_) => _Convertible(), [[]]);
final handlerAdd = _Handler(
  'add',
  (args) => (args[0] as double) + (args[1] as double),
  [
    [XPathArgType.number, XPathArgType.number],
  ],
);
final handlerProto = _Handler('proto', printArgs, [
  [XPathArgType.number, XPathArgType.number],
  [XPathArgType.number],
  [XPathArgType.string, XPathArgType.string],
  [XPathArgType.number, XPathArgType.string, XPathArgType.boolean],
]);
final handlerNullProto = _Handler('null-proto', (_) => false, []);
final handlerRaw = _Handler('raw', printArgs, [
  [XPathArgType.number, XPathArgType.string, XPathArgType.boolean],
], rawArgs: true);
final handlerGetCustom = _Handler(
  'get-custom',
  (args) => (args[0] as bool) ? CustomSubType() : CustomType(),
  [
    [XPathArgType.boolean],
  ],
);
final handlerConcat = _Handler(
  'concat',
  (args) => args.map(conversions.toXPathString).join(),
  [[]],
  rawArgs: true,
);
final handlerCheckTypes = _Handler(
  'check-types',
  (args) {
    if (args.length != 5 ||
        args[0] is! bool ||
        args[1] is! double ||
        args[2] is! String ||
        args[3] is! DateTime ||
        args[4] is! CustomType) {
      throw StateError('Types in custom function handler not converted');
    }
    return true;
  },
  [
    [
      XPathArgType.boolean,
      XPathArgType.number,
      XPathArgType.string,
      XPathArgType.date,
      XPathArgType.ofType<CustomType>(),
    ],
  ],
);

final class _Stateful extends XPathFunctionHandler {
  _Stateful(this.name, this._eval, this.prototypes);

  @override
  final String name;

  @override
  final List<List<XPathArgType>> prototypes;

  final Object Function(_Stateful self, List<Object> args) _eval;

  String? value;

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      _eval(this, args);
}

final handlerStatefulRead = _Stateful('read', (self, _) => self.value!, [[]]);
final handlerStatefulWrite = _Stateful(
  'write',
  (self, args) {
    self.value = args[0] as String;
    return true;
  },
  [
    [XPathArgType.string],
  ],
);

final class _Fallback implements XPathFallbackFunctionHandler {
  _Fallback(this._eval);

  final Object Function(String name) _eval;

  @override
  Object eval(String name, List<Object> args, EvaluationContext context) =>
      _eval(name);
}

void main() {
  setUp(() => ec = EvaluationContext(null));

  test('counting_functions', () {
    testEval('count(/data/path)', 5.0, model: buildInstance(), context: null);
    testEval(
      'count-non-empty(/data/path)',
      3.0,
      model: buildInstance(),
      context: null,
    );
  });

  test('unsupported_functions', () {
    testEval('/union | /expr', throws<XPathUnsupportedException>());
    testEval('/descendant::blah', throws<XPathUnsupportedException>());
    testEval('/cant//support', throws<XPathUnsupportedException>());
    testEval('/text()', throws<XPathUnsupportedException>());
    testEval('/namespace:*', throws<XPathUnsupportedException>());
    testEval(
      '(filter-expr)[5]',
      throws<XPathUnsupportedException>(),
      model: buildInstance(),
      context: null,
    );
    testEval(
      '(filter-expr)/data',
      throws<XPathUnsupportedException>(),
      model: buildInstance(),
      context: null,
    );
  });

  test('numeric_literals', () {
    testEval('5', 5.0);
    testEval('555555.555', 555555.555);
    testEval('.000555', 0.000555);
    testEval('0', 0.0);
    testEval('-5', -5.0);
    testEval('-0', -0.0);
    testEval('1230000000000000000000', 1.23e21);
    testEval('0.00000000000000000123', 1.23e-18);
  });

  test('string_literals', () {
    testEval("''", '');
    testEval("'\"'", '"');
    testEval('"test string"', 'test string');
    testEval("'   '", '   ');
  });

  test('type_conversions', () {
    ec.addFunctionHandler(handlerConvertible);
    ec.addFunctionHandler(handlerInconvertible);
    testEval('true()', true);
    testEval('false()', false);
    testEval('boolean(true())', true);
    testEval('boolean(false())', false);
    testEval('boolean(1)', true);
    testEval('boolean(-1)', true);
    testEval('boolean(0.0001)', true);
    testEval('boolean(0)', false);
    testEval('boolean(-0)', false);
    testEval("boolean(number('NaN'))", false);
    testEval('boolean(1 div 0)', true);
    testEval('boolean(-1 div 0)', true);
    testEval("boolean('')", false);
    testEval("boolean('asdf')", true);
    testEval("boolean('  ')", true);
    testEval("boolean('false')", true);
    testEval("boolean(date('2000-01-01'))", true);
    testEval('boolean(convertible())', true, model: null, context: ec);
    testEval(
      'boolean(inconvertible())',
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval('number(true())', 1.0);
    testEval('number(false())', 0.0);
    testEval("number('100')", 100.0);
    testEval("number('100.001')", 100.001);
    testEval("number('.1001')", 0.1001);
    testEval("number('1230000000000000000000')", 1.23e21);
    testEval("number('0.00000000000000000123')", 1.23e-18);
    testEval("number('0')", 0.0);
    testEval("number('-0')", -0.0);
    testEval("number(' -12345.6789  ')", -12345.6789);
    testEval("number('NaN')", double.nan);
    testEval("number('not a number')", double.nan);
    testEval("number('- 17')", double.nan);
    testEval("number('  ')", double.nan);
    testEval("number('')", double.nan);
    testEval("number('Infinity')", double.nan);
    testEval("number('1.1e6')", double.nan);
    testEval("number('34.56.7')", double.nan);
    testEval('number(10)', 10.0);
    testEval('number(0)', 0.0);
    testEval('number(-0)', -0.0);
    testEval('number(-123.5)', -123.5);
    testEval("number(number('NaN'))", double.nan);
    testEval('number(1 div 0)', double.infinity);
    testEval('number(-1 div 0)', double.negativeInfinity);
    testEval("number(date('1970-01-01'))", 0.0);
    testEval("number(date('1970-01-02'))", 1.0);
    testEval("number(date('1969-12-31'))", -1.0);
    testEval("number(date('2008-09-05'))", 14127.0);
    testEval("number(date('1941-12-07'))", -10252.0);
    testEval('number(convertible())', 5.0, model: null, context: ec);
    testEval(
      'number(inconvertible())',
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval('string(true())', 'true');
    testEval('string(false())', 'false');
    testEval("string(number('NaN'))", 'NaN');
    testEval('string(1 div 0)', 'Infinity');
    testEval('string(-1 div 0)', '-Infinity');
    testEval('string(0)', '0');
    testEval('string(-0)', '0');
    testEval('string(123456.0000)', '123456');
    testEval('string(-123456)', '-123456');
    testEval('string(1)', '1');
    testEval('string(-1)', '-1');
    testEval('string(.557586)', '0.557586');
    testEval("string('')", '');
    testEval("string('  ')", '  ');
    testEval("string('a string')", 'a string');
    testEval("string(date('1989-11-09'))", '1989-11-09');
    testEval('string(convertible())', 'hi', model: null, context: ec);
    testEval(
      'string(inconvertible())',
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval("int('100')", 100.0);
    testEval("int('100.001')", 100.0);
    testEval("int('.1001')", 0.0);
    testEval("int('1230000000000000000000')", 1.23e21);
    testEval("int('0.00000000000000000123')", 1.23e-18);
    testEval("int('0')", 0.0);
    testEval("int('-0')", -0.0);
    testEval("int(' -12345.6789  ')", -12345.0);
    testEval("int('NaN')", double.nan);
    testEval("int('not a number')", double.nan);
    testEval("int('- 17')", double.nan);
    testEval("int('  ')", double.nan);
    testEval("int('')", double.nan);
    testEval("int('Infinity')", double.nan);
    testEval("int('1.1e6')", double.nan);
    testEval("int('34.56.7')", double.nan);
  });

  test('substring_functions', () {
    testEval("substr('hello',0)", 'hello');
    testEval("substr('hello',0,5)", 'hello');
    testEval("substr('hello',1)", 'ello');
    testEval("substr('hello',1,5)", 'ello');
    testEval("substr('hello',1,4)", 'ell');
    testEval("substr('hello',-2)", 'lo');
    testEval("substr('hello',0,-1)", 'hell');
    testEval("substring-before('hello','l')", 'he');
    testEval("substring-before('hello','q')", '');
    testEval("substring-before('hello','')", '');
    testEval("substring-before('','')", '');
    testEval("substring-before('','q')", '');
    testEval("substring-after('hello','l')", 'lo');
    testEval("substring-after('hello','q')", '');
    testEval("substring-after('hello','')", 'hello');
    testEval("substring-after('','')", '');
    testEval("substring-after('','q')", '');
    testEval("translate('hello','l','L')", 'heLLo');
    testEval("translate('hello','q','Q')", 'hello');
    testEval("translate('hello','','L')", 'hello');
    testEval("translate('hello','l','')", 'heo');
    testEval("translate('','l','L')", '');
    testEval("translate('hello','lo','LO')", 'heLLO');
    testEval("translate('hello world','hello','')", ' wrd');
    testEval("translate('hello wor,ld',' ,',', ')", 'hello,wor ld');
    testEval("translate('2019/01/02','/','-')", '2019-01-02');
    testEval("contains('a', 'a')", true);
    testEval("contains('a', 'b')", false);
    testEval("contains('abc', 'b')", true);
    testEval("contains('abc', 'bcd')", false);
    testEval("not(contains('a', 'b'))", true);
    testEval("starts-with('abc', 'a')", true);
    testEval("starts-with('', 'a')", false);
    testEval("starts-with('', '')", true);
    testEval("ends-with('abc', 'a')", false);
    testEval("ends-with('abc', 'c')", true);
    testEval("ends-with('', '')", true);
  });

  test('geo_functions', () {
    testEval("geofence('')", throws<XPathUnhandledException>());
    testEval("geofence('', '')", throws<XPathUnhandledException>());
    testEval("geofence('0 0 0 0', '')", throws<XPathUnhandledException>());
    testEval(
      "geofence('0.5 0.5 0 0', /data/geoshape)",
      true,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('-1 0.5 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('2 0.5 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('0.5 2 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('0.5 -1 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('-1 0 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('-1 1 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
    testEval(
      "geofence('0 -1 0 0', /data/geoshape)",
      false,
      model: buildInstance(),
      context: null,
    );
  });

  test('other_string_functions', () {
    testEval("normalize-space('')", '');
    testEval("normalize-space('  ')", '');
    testEval("normalize-space(' \t\n ')", '');
    testEval("normalize-space(' a')", 'a');
    testEval("normalize-space(' a   ')", 'a');
    testEval("normalize-space(' ab ')", 'ab');
    testEval("normalize-space(' a    b ')", 'a b');
    testEval("normalize-space(' a\nb\n')", 'a b');
    testEval("normalize-space('\na\nb\n')", 'a b');
    testEval("normalize-space('\nab')", 'ab');
    testEval("normalize-space(' \ta\n\t  b \n\t c   \n')", 'a b c');
    testEval('normalize-space()', throws<XPathException>());
    testEval("string-length('cocotero')", 8.0);
    testEval('string-length()', throws<XPathException>());
  });

  test('other_string_functions_with_context', () {
    final instance1 = buildInstance();
    testEval(
      "/data/path[normalize-space()='some value']",
      createExpectedNodesetFromInstance(instance1, 'path', 2),
      model: instance1,
      context: null,
    );
    testEval(
      '/data/path[string-length()=17]',
      createExpectedNodesetFromInstance(instance1, 'path', 2),
      model: instance1,
      context: null,
    );
  });

  test('date_functions', () {
    // JavaRosa runs these with the default zone set to GMT.
    if (DateTime.now().timeZoneOffset != Duration.zero) {
      markTestSkipped('needs TZ=UTC');
      return;
    }
    ec.addFunctionHandler(handlerConvertible);
    testEval("date('2000-01-01')", date_utils.getDate(2000, 1, 1));
    testEval("date('1945-04-26')", date_utils.getDate(1945, 4, 26));
    testEval("date('1996-02-29')", date_utils.getDate(1996, 2, 29));
    testEval("date('1983-09-31')", throws<XPathTypeMismatchException>());
    testEval("date('not a date')", throws<XPathTypeMismatchException>());
    testEval('date(0)', date_utils.getDate(1970, 1, 1));
    testEval('date(6.5)', date_utils.getDate(1970, 1, 7));
    testEval('date(1)', date_utils.getDate(1970, 1, 2));
    testEval('date(-1)', date_utils.getDate(1969, 12, 31));
    testEval('date(14127)', date_utils.getDate(2008, 9, 5));
    testEval('date(-10252)', date_utils.getDate(1941, 12, 7));
    testEval("date(date('1989-11-09'))", date_utils.getDate(1989, 11, 9));
    testEval('date(true())', throws<XPathTypeMismatchException>());
    testEval(
      'date(convertible())',
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval(
      "format-date('2018-01-02T10:20:30.123', \"%Y-%m-%e %H:%M:%S\")",
      '2018-01-2 10:20:30',
    );
    testEval(
      "date-time('2000-01-01T10:20:30.000')",
      date_utils.getDateTimeFromString('2000-01-01T10:20:30.000'),
    );
    testEval(
      "decimal-date-time('2000-01-01T10:20:30.000')",
      10957.430902777778,
    );
    testEval(
      "decimal-time('2000-01-01T10:20:30.000+03:00')",
      0.30590277777810115,
    );
    testEval(
      "decimal-date-time('-1000')",
      throws<XPathTypeMismatchException>(),
    );
    testEval(
      "decimal-date-time('-01-2019')",
      throws<XPathTypeMismatchException>(),
    );
  });

  test('boolean_functions', () {
    testEval('not(true())', false);
    testEval('not(false())', true);
    testEval("not('')", true);
    testEval("boolean-from-string('true')", true);
    testEval("boolean-from-string('false')", false);
    testEval("boolean-from-string('whatever')", false);
    testEval("boolean-from-string('1')", true);
    testEval("boolean-from-string('0')", false);
    testEval('boolean-from-string(1)', true);
    testEval('boolean-from-string(1.0)', true);
    testEval('boolean-from-string(1.0001)', false);
    testEval('boolean-from-string(true())', true);
    testEval("if(true(), 5, 'abc')", 5.0);
    testEval("if(false(), 5, 'abc')", 'abc');
    testEval("if(6 > 7, 5, 'abc')", 'abc');
    testEval("if('', 5, 'abc')", 'abc');
    testEval("selected('apple baby crimson', 'apple')", true);
    testEval("selected('apple baby crimson', 'baby')", true);
    testEval("selected('apple baby crimson', 'crimson')", true);
    testEval("selected('apple baby crimson', '  baby  ')", true);
    testEval("selected('apple baby crimson', 'babby')", false);
    testEval("selected('apple baby crimson', 'bab')", false);
    testEval("selected('apple', 'apple')", true);
    testEval("selected('apple', 'ovoid')", false);
    testEval("selected('', 'apple')", false);
    testEval("count-selected('apple baby crimson')", 3.0);
    testEval("count-selected('')", 0.0);
    testEval("selected-at('apple baby crimson', 2)", 'crimson');
    testEval("selected-at('apple baby', 2)", '');
    testEval("checklist(1, 3, 'foo', 'bar')", true);
    testEval("checklist(-1, 1, 'foo', 'bar')", false);
    testEval("checklist(3, -1, 'foo', 'bar')", false);
    testEval("checklist(3, 5, 'foo', 'bar')", false);
    testEval("checklist(1, 2, 'foo', 'bar', 'baz')", false);
  });

  test('math_operators', () {
    testEval('5.5 + 5.5', 11.0);
    testEval('0 + 0', 0.0);
    testEval('6.1 - 7.8', -1.7);
    testEval('-3 + 4', 1.0);
    testEval('3 + -4', -1.0);
    testEval('1 - 2 - 3', -4.0);
    testEval('1 - (2 - 3)', 2.0);
    testEval('-(8*5)', -40.0);
    testEval("-'19'", -19.0);
    testEval('1.1 * -1.1', -1.21);
    testEval('-10 div -4', 2.5);
    testEval('2 * 3 div 8 * 2', 1.5);
    testEval('3 + 3 * 3', 12.0);
    testEval('1 div 0', double.infinity);
    testEval('-1 div 0', double.negativeInfinity);
    testEval('0 div 0', double.nan);
    testEval('3.1 mod 3.1', 0.0);
    testEval('5 mod 3.1', 1.9);
    testEval('2 mod 3.1', 2.0);
    testEval('0 mod 3.1', 0.0);
    testEval('5 mod -3', 2.0);
    testEval('-5 mod 3', -2.0);
    testEval('-5 mod -3', -2.0);
    testEval('5 mod 0', double.nan);
    testEval('5 * (6 + 7)', 65.0);
    testEval("'123' * '456'", 56088.0);
  });

  test('math_functions', () {
    testEval('abs(-3.5)', 3.5);
    testEval("round('14.29123456789')", 14.0);
    testEval("round('14.6')", 15.0);
    testEval("round('14.29123456789', 0)", 14.0);
    testEval("round('14.29123456789', 1)", 14.3);
    testEval("round('14.29123456789', 1.5)", 14.3);
    testEval("round('14.29123456789', 2)", 14.29);
    testEval("round('14.29123456789', 3)", 14.291);
    testEval("round('14.29123456789', 4)", 14.2912);
    testEval("round('12345.14', 1)", 12345.1);
    testEval("round('-12345.14', 1)", -12345.1);
    testEval("round('12345.12345', 0)", 12345.0);
    testEval("round('12345.12345', -1)", 12350.0);
    testEval("round('12345.12345', -2)", 12300.0);
    testEval("round('12350.12345', -2)", 12400.0);
    testEval("round('12345.12345', -3)", 12000.0);
    testEval("round('4,6')", 5.0);
    testEval("round('1 div 0', 0)", double.nan);
    testEval("round('14.5')", 15.0);
    testEval("round('NaN')", double.nan);
    testEval("round('-NaN')", double.nan);
    testEval("round('0')", 0.0);
    testEval("round('-0')", -0.0);
    testEval("round('-0.5')", -0.0);
    testEval("round('14,6')", 15.0);
    testEval("round('12345.15', 1)", 12345.2);
    testEval("round('-12345.15', 1)", -12345.1);
    testEval('pow(2, 2)', 4.0);
    testEval('pow(2, 0)', 1.0);
    testEval('pow(0, 4)', 0.0);
    testEval('pow(2.5, 2)', 6.25);
    testEval('pow(0.5, 2)', 0.25);
    testEval('pow(-1, 2)', 1.0);
    testEval('pow(-1, 3)', -1.0);
    testEval('pow(4, 0.5)', 2.0);
    testEval('pow(16, 0.25)', 2.0);
    testEval('cos(0)', 1.0);
    testEval('cos(${javaDoubleToString(math.pi / 2)})', 0.0);
    testEval('acos(0)', math.pi / 2);
    testEval('acos(1)', 0.0);
    testEval('sin(0)', 0.0);
    testEval('sin(${javaDoubleToString(math.pi / 2)})', 1.0);
    testEval('asin(0)', 0.0);
    testEval('asin(1)', math.pi / 2);
    testEval('tan(0)', 0.0);
    testEval('atan(0)', 0.0);
    testEval('atan2(0, 0)', 0.0);
    testEval('exp(1)', math.e);
    testEval('exp10(2)', 100.0);
    testEval('log(${javaDoubleToString(math.exp(2))})', 2.0);
    testEval('log10(100)', 2.0);
    testEval('pi()', math.pi);
    testEval('sqrt(9)', 3.0);
  });

  test('strange_operators', () {
    testEval('true() + 8', 9.0);
    testEval("date('2008-09-08') - date('1983-10-06')", 9104.0);
    testEval('true() and true()', true);
    testEval('true() and false()', false);
    testEval('false() and false()', false);
    testEval('true() or true()', true);
    testEval('true() or false()', true);
    testEval('false() or false()', false);
    testEval('true() or true() and false()', true);
    testEval('(true() or true()) and false()', false);
    testEval("true() or date('')", true);
    testEval("false() and date('')", false);
    testEval("'' or 17", true);
    testEval('false() or 0 + 2', true);
    testEval('(false() or 0) + 2', 2.0);
    testEval('4 < 5', true);
    testEval('5 < 5', false);
    testEval('6 < 5', false);
    testEval('4 <= 5', true);
    testEval('5 <= 5', true);
    testEval('6 <= 5', false);
    testEval('4 > 5', false);
    testEval('5 > 5', false);
    testEval('6 > 5', true);
    testEval('4 >= 5', false);
    testEval('5 >= 5', true);
    testEval('6 >= 5', true);
    testEval('-3 > -6', true);
  });

  test('odd_comparisons', () {
    testEval('true() > 0.9999', true);
    testEval("'-17' > '-172'", true);
    testEval("'abc' < 'abcd'", false);
    testEval("date('2001-12-26') > date('2001-12-25')", true);
    testEval("date('1969-07-20') < date('1969-07-21')", true);
    testEval('false() and false() < true()', false);
    testEval('(false() and false()) < true()', true);
    testEval('6 < 7 - 4', false);
    testEval('(6 < 7) - 4', -3.0);
    testEval('3 < 4 < 5', true);
    testEval('3 < (4 < 5)', false);
    testEval('true() = true()', true);
    testEval('true() = false()', false);
    testEval('true() != true()', false);
    testEval('true() != false()', true);
    testEval('3 = 3', true);
    testEval('3 = 4', false);
    testEval('3 != 3', false);
    testEval('3 != 4', true);
    testEval('6.1 - 7.8 = -1.7', true);
    testEval("'abc' = 'abc'", true);
    testEval("'abc' = 'def'", false);
    testEval("'abc' != 'abc'", false);
    testEval("'abc' != 'def'", true);
    testEval("'' = ''", true);
    testEval('true() = 17', true);
    testEval('0 = false()', true);
    testEval("true() = 'true'", true);
    testEval("17 = '17.0000000'", true);
    testEval("'0017.' = 17", true);
    testEval("'017.' = '17.000'", false);
    testEval("date('2004-05-01') = date('2004-05-01')", true);
    testEval("true() != date('1999-09-09')", false);
    testEval('false() and true() != true()', false);
    testEval('(false() and true()) != true()', true);
    testEval('-3 < 3 = 6 >= 6', true);
  });

  test('functions_and_custom_function_handlers', () {
    ec.addFunctionHandler(handlerTestfunc);
    ec.addFunctionHandler(handlerAdd);
    testEval('true(5)', throws<XPathUnhandledException>());
    testEval('number()', throws<XPathUnhandledException>());
    testEval(
      "string('too', 'many', 'args')",
      throws<XPathUnhandledException>(),
    );
    testEval('not-a-function()', throws<XPathUnhandledException>());
    testEval('testfunc()', true, model: null, context: ec);
    testEval('add(3, 5)', 8.0, model: null, context: ec);
    testEval("add('17', '-14')", 3.0, model: null, context: ec);
  });

  test('proto', () {
    ec.addFunctionHandler(handlerInconvertible);
    ec.addFunctionHandler(handlerProto);
    ec.addFunctionHandler(handlerNullProto);
    testEval(
      'proto()',
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval(
      'proto(5, 5)',
      '[Double:5.0,Double:5.0]',
      model: null,
      context: ec,
    );
    testEval('proto(6)', '[Double:6.0]', model: null, context: ec);
    testEval("proto('asdf')", '[Double:NaN]', model: null, context: ec);
    testEval(
      "proto('7', '7')",
      '[Double:7.0,Double:7.0]',
      model: null,
      context: ec,
    );
    testEval(
      "proto(1.1, 'asdf', true())",
      '[Double:1.1,String:asdf,Boolean:true]',
      model: null,
      context: ec,
    );
    testEval(
      'proto(false(), false(), false())',
      '[Double:0.0,String:false,Boolean:false]',
      model: null,
      context: ec,
    );
    testEval(
      "proto(1.1, 'asdf', inconvertible())",
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    testEval(
      "proto(1.1, 'asdf', true(), 16)",
      throws<XPathTypeMismatchException>(),
      model: null,
      context: ec,
    );
    // JavaRosa: a handler with null prototypes throws NullPointerException.
    // Not representable in Dart (prototypes are non-nullable).
  });

  test('raw', () {
    ec.addFunctionHandler(handlerRaw);
    ec.addFunctionHandler(handlerGetCustom);
    testEval('raw()', '[]', model: null, context: ec);
    testEval('raw(5, 5)', '[Double:5.0,Double:5.0]', model: null, context: ec);
    testEval("raw('7', '7')", '[String:7,String:7]', model: null, context: ec);
    testEval(
      "raw('1.1', 'asdf', 17)",
      '[Double:1.1,String:asdf,Boolean:true]',
      model: null,
      context: ec,
    );
    testEval(
      'raw(get-custom(false()), get-custom(true()))',
      '[CustomType:,CustomSubType:]',
      model: null,
      context: ec,
    );
  });

  test('concat', () {
    ec.addFunctionHandler(handlerConcat);
    ec.addFunctionHandler(handlerCheckTypes);
    ec.addFunctionHandler(handlerGetCustom);
    testEval('concat()', '', model: null, context: ec);
    testEval("concat('a')", 'a', model: null, context: ec);
    testEval("concat('a','b','')", 'ab', model: null, context: ec);
    testEval(
      "concat('ab','cde','','fgh',1,false(),'ijklmnop')",
      'abcdefgh1falseijklmnop',
      model: null,
      context: ec,
    );
    testEval(
      "check-types(55, '55', false(), '1999-09-09', get-custom(false()))",
      true,
      model: null,
      context: ec,
    );
    testEval(
      "check-types(55, '55', false(), '1999-09-09', get-custom(true()))",
      true,
      model: null,
      context: ec,
    );
  });

  test('regex', () {
    ec.addFunctionHandler(handlerRegex);
    testEval("regex('12345','[0-9]+')", true, model: null, context: ec);
  });

  test('variable_refs', () {
    ec.setVariable('var_float_five', 5.0);
    testEval('\$var_float_five', 5.0, model: null, context: ec);
    ec.setVariable('var_string_five', 'five');
    testEval('\$var_string_five', 'five', model: null, context: ec);
    ec.setVariable('var_int_five', 5);
    testEval('\$var_int_five', 5.0, model: null, context: ec);
    ec.setVariable('var_double_five', 5.0);
    testEval('\$var_double_five', 5.0, model: null, context: ec);
  });

  test('node_referencing', () {
    final instance1 = createTestDataForIndexedRepeatFunction(1);
    testEval(
      'indexed-repeat( /data/repeat/name , /data/repeat , /data/index1 )',
      createExpectedNodesetFromIndexedRepeatFunction(instance1, 1, 'name'),
      model: instance1,
      context: null,
    );
    final instance2 = createTestDataForIndexedRepeatFunction(null);
    testEval(
      'indexed-repeat( /data/repeat/name , /data/repeat , /data/index1 )',
      createExpectedNodesetFromIndexedRepeatFunction(instance2, 0, 'name'),
      model: instance2,
      context: null,
    );
  });

  test('crypto_functions', () {
    testEval(
      "digest('some text', 'MD5', 'base64')",
      'VS4hzUzZkYZ448Gg30kbww==',
    );
    testEval(
      "digest('some text', 'SHA-1', 'base64')",
      'N6pjx3OY2VRHMmLhoAV8HmMu2nc=',
    );
    testEval(
      "digest('some text', 'SHA-256', 'base64')",
      'uU9vElx546X/qoJvWEwQ1SraZp5nYgUbgmtVd20FrtI=',
    );
    testEval(
      "digest('some text', 'SHA-384', 'base64')",
      'zJTsPphzwLmnJIZEKVj2cQZ833e5QnQW0DFEDMYgQeLuE0RJhEfsDO2fcENGG9Hz',
    );
    testEval(
      "digest('some text', 'SHA-512', 'base64')",
      '4nMrrtyj6sFAeChjfeHbynAsP8ns4Wz1Nt241hOc2F3+dGS4I1spgm9gjM9KxkPimxnGN4WKPYcQpZER30LdtQ==',
    );
    testEval(
      "digest('some text', 'MD5', 'hex')",
      '552e21cd4cd9918678e3c1a0df491bc3',
    );
    testEval("digest('some text', 'MD5')", 'VS4hzUzZkYZ448Gg30kbww==');
  });

  test('read_write_function_handlers', () {
    ec.addFunctionHandler(handlerStatefulRead);
    ec.addFunctionHandler(handlerStatefulWrite);
    handlerStatefulRead.value = 'testing-read';
    testEval('read()', 'testing-read', model: null, context: ec);
    testEval("write('testing-write')", true, model: null, context: ec);
    expect(handlerStatefulWrite.value, 'testing-write');
  });

  test('fallback_function_handler', () {
    final unknownFunctions = <String>[];
    ec.fallbackFunctionHandler = _Fallback((name) {
      unknownFunctions.add(name);
      return '';
    });
    testEval('foo(bar(33))', '', model: null, context: ec);
    expect(unknownFunctions, contains('foo'));
    expect(unknownFunctions, contains('bar'));
  });
}
