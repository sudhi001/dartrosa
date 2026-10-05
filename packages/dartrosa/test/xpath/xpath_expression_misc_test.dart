// Port of JavaRosa v6.0.0 EncodingEncodeTest, EncodingDecodeTest,
// XPathFuncAsSomethingTest, XPathBinaryOpExprTest, XPathUnaryOpExprTest,
// XPathPathExprTest, XPathFilterExprTest and XPathFuncExprTest.
import 'dart:convert';

import 'package:dartrosa/src/util/java_base64.dart';
import 'package:dartrosa/src/util/randomize.dart';
import 'package:dartrosa/src/xpath/conversions.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/src/xpath/qname.dart';
import 'package:test/test.dart';

XPathFuncExpr fn(String name, [List<XPathExpression> args = const []]) =>
    XPathFuncExpr(XPathQName.parse(name), args);

void main() {
  group('Encoding', () {
    test('hex encode', () {
      expect(hexEncode(utf8.encode('some text')), '736f6d652074657874');
      expect(hexEncode(utf8.encode('')), '');
    });
    test('base64 encode', () {
      expect(javaBase64Encode(utf8.encode('some text')), 'c29tZSB0ZXh0');
      expect(javaBase64Encode(utf8.encode('')), '');
    });
    test('hex decode', () {
      expect(
        utf8.decode(hexDecode(utf8.encode('736f6d652074657874'))),
        'some text',
      );
      expect(utf8.decode(hexDecode(utf8.encode(''))), '');
    });
    test('base64 decode', () {
      expect(utf8.decode(javaBase64DecodeString('c29tZSB0ZXh0')), 'some text');
      expect(utf8.decode(javaBase64DecodeString('')), '');
    });
  });

  group('XPathFuncAsSomething', () {
    test('toLongHash hashes well', () {
      expect(longHash('Hello'), 1756278180214341157.0);
      // The empty string would hash to -2039914840885289964; JavaRosa keeps
      // 0 for backward compatibility.
      expect(longHash(''), 0.0);
    });
    test('toNumeric handles booleans', () {
      expect(toNumeric(true), 1.0);
      expect(toNumeric(false), 0.0);
    });
    test('toNumeric handles strings', () {
      expect(toNumeric('  123  '), 123.0);
      expect(toNumeric('  123.0  '), 123.0);
      expect(toNumeric('  123.4  '), 123.4);
      expect(toNumeric('  123,4  '), 123.4);
      expect(toNumeric('0x12').isNaN, isTrue);
    });
    test('toNumeric handles dates', () {
      // JavaRosa: new Date(86400 * 1000L), i.e. one day after the epoch.
      // Days are counted in the local zone, so use local midnight.
      expect(toNumeric(DateTime(1970, 1, 2)), 1.0);
    });
  });

  group('containsFunc and isIdempotent', () {
    test('binary operators', () {
      final expr = XPathArithExpr(ArithOp.add, fn('a'), fn('b'));
      expect(expr.containsFunc('c'), isFalse);
      expect(expr.containsFunc('a'), isTrue);
      expect(expr.containsFunc('b'), isTrue);
    });
    test('unary operators', () {
      final expr = XPathNumNegExpr(fn('a'));
      expect(expr.containsFunc('b'), isFalse);
      expect(expr.containsFunc('a'), isTrue);
    });
    test('paths', () {
      XPathStep step(String predicate) => XPathStep.named(
        XPathAxis.child,
        XPathQName.parse('x'),
        [fn(predicate)],
      );
      expect(
        XPathPathExpr(PathStart.root, [step('a')]).containsFunc('b'),
        isFalse,
      );
      expect(
        XPathPathExpr.fromFilter(XPathFilterExpr(fn('a'), const []), [
          step('b'),
        ]).containsFunc('c'),
        isFalse,
      );
      expect(
        XPathPathExpr.fromFilter(
          XPathFilterExpr(fn('a'), const []),
          const [],
        ).containsFunc('a'),
        isTrue,
      );
      expect(
        XPathPathExpr(PathStart.root, [step('a')]).containsFunc('a'),
        isTrue,
      );
    });
    test('filter expressions', () {
      final expr = XPathFilterExpr(fn('a'), [fn('b')]);
      expect(expr.containsFunc('c'), isFalse);
      expect(expr.containsFunc('a'), isTrue);
      expect(expr.containsFunc('b'), isTrue);
    });
    test('function calls', () {
      expect(fn('string', [fn('random')]).isIdempotent, isFalse);
      expect(fn('random').containsFunc('random'), isTrue);
      expect(fn('string', [fn('random')]).containsFunc('random'), isTrue);
      expect(fn('random').containsFunc('other'), isFalse);
    });
  });
}
