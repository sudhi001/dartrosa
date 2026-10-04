import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/xpath/conversions.dart' as conversions;
import 'package:dartrosa/src/xpath/nodeset.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

/// ```xml
/// <data>
///   <name>Ada</name><age>36</age><score>2.5</score>
///   <hidden>secret</hidden>
///   <item id="a"><v>1</v></item><item id="b"><v>2</v></item>
///   <item id="c"><v>3</v></item>
/// </data>
/// ```
FormInstance buildInstance() {
  final data = TreeElement('data')
    ..addChild(TreeElement('name')..value = const StringValue('Ada'))
    ..addChild(TreeElement('age')..value = const IntegerValue(36))
    ..addChild(TreeElement('score')..value = const DecimalValue(2.5))
    ..addChild(TreeElement('hidden')..value = const StringValue('secret'));
  final ids = ['a', 'b', 'c'];
  for (var i = 0; i < 3; i++) {
    data.addChild(
      TreeElement('item', i)
        ..setAttribute(null, 'id', ids[i])
        ..addChild(TreeElement('v')..value = IntegerValue(i + 1)),
    );
  }
  return FormInstance(data);
}

void main() {
  late FormInstance instance;
  late EvaluationContext ec;

  setUp(() {
    instance = buildInstance();
    ec = EvaluationContext(instance);
  });

  Object eval(String xpath, [EvaluationContext? context]) =>
      parseXPath(xpath).evalIn(context ?? ec);

  Object value(String xpath) {
    final result = eval(xpath);
    return result is XPathNodeset ? result.unpack() : result;
  }

  group('literals and operators', () {
    test('arithmetic follows Java doubles', () {
      expect(eval('1 + 2 * 3'), 7.0);
      expect(eval('7 div 2'), 3.5);
      expect(eval('-7 mod 3'), -1.0); // Java %: sign of the dividend
      expect(eval('7 mod -3'), 1.0);
      expect(eval('1 div 0'), double.infinity);
      expect((eval('0 div 0') as double).isNaN, isTrue);
      expect(eval('- - 4'), 4.0);
    });

    test('comparisons and booleans', () {
      expect(eval('2 > 1 and 1 >= 1'), true);
      expect(eval("'10' < 9"), false);
      expect(eval('0 or 1'), true);
      expect(eval("'' or 0"), false);
    });

    test('equality rules', () {
      expect(eval("1 = '1'"), true);
      expect(eval("1 = '1.0000000000001'"), true); // within 1e-12
      expect(eval("'a' != 'b'"), true);
      expect(eval("1 = 'abc'"), false); // NaN
    });

    test('union and filter expressions are unsupported', () {
      expect(() => eval('1 | 2'), throwsA(isA<XPathUnsupportedException>()));
    });

    test('and/or short-circuit', () {
      // The right side would fail (unknown function) if evaluated.
      expect(eval('0 and unknown-fn()'), false);
      expect(eval('1 or unknown-fn()'), true);
    });
  });

  group('paths', () {
    test('absolute paths unpack typed values', () {
      expect(value('/data/name'), 'Ada');
      expect(value('/data/age'), 36.0);
      expect(value('/data/score'), 2.5);
      expect(value('/data/missing'), '');
    });

    test('relative paths use the context node', () {
      final context = EvaluationContext.withContext(
        ec,
        getRef('/data[1]/item[2]'),
      );
      expect(value('v'), ''); // from the root context 'v' is /v
      expect(parseXPath('v').evalIn(context) is XPathNodeset, isTrue);
      expect((parseXPath('v').evalIn(context) as XPathNodeset).unpack(), 2.0);
      expect(
        (parseXPath('../name').evalIn(context) as XPathNodeset).unpack(),
        'Ada',
      );
    });

    test('a repeated node cannot be unpacked', () {
      expect(
        () => value('/data/item/v'),
        throwsA(
          isA<XPathTypeMismatchException>().having(
            (e) => e.message,
            'message',
            contains('This field is repeated'),
          ),
        ),
      );
      expect((eval('/data/item') as XPathNodeset).size, 3);
    });

    test('predicates filter by boolean result only', () {
      expect(value("/data/item[@id = 'b']/v"), 2.0);
      expect(value('/data/item[v > 2]/v'), 3.0);
      // A numeric predicate is not positional in JavaRosa: nothing passes.
      expect((eval('/data/item[2]') as XPathNodeset).size, 0);
    });

    test('attributes', () {
      expect((eval('/data/item/@id') as XPathNodeset).size, 3);
      expect(value('/data/item[v = 3]/@id'), 'c');
    });

    test('non-relevant nodes are excluded and read as empty', () {
      instance.root.firstChild('hidden')!.isRelevant = false;
      expect((eval('/data/hidden') as XPathNodeset).size, 0);
      expect(value('/data/hidden'), '');
    });

    test('missing secondary instance', () {
      expect(
        () => eval("instance('nope')/root/item"),
        throwsA(isA<XPathMissingInstanceException>()),
      );
    });

    test('secondary instances', () {
      final towns = FormInstance(
        TreeElement('root')..addChild(
          TreeElement('item')
            ..addChild(TreeElement('label')..value = const StringValue('Lyon')),
        ),
        'towns',
      );
      final context = EvaluationContext(instance, {'towns': towns});
      expect(
        (parseXPath("instance('towns')/root/item/label").evalIn(context)
                as XPathNodeset)
            .unpack(),
        'Lyon',
      );
    });

    test('constraint candidate value replaces the node value', () {
      final context =
          EvaluationContext.withContext(ec, getRef('/data[1]/age[1]'))
            ..isConstraint = true
            ..candidateValue = const IntegerValue(5);
      expect(parseXPath('. > 3 and . < 10').evalIn(context), true);
    });
  });

  group('conversions', () {
    test('string() of numbers follows JavaRosa', () {
      Object str(String xpath) => toXPathStringForTest(eval(xpath));
      expect(str('2.0'), '2');
      expect(str('1 div 3'), '0.3333333333333333');
      expect(str('10000000000'), '1.0E10'); // Java (int) cast saturates
      expect(str('0.0000000000001'), '0');
      expect(str('-1 div 0'), '-Infinity');
    });

    test('number() of strings', () {
      expect(eval("'3,5' * 1"), 3.5); // ',' accepted as decimal separator
      expect((eval("'1e3' * 1") as double).isNaN, isTrue);
      expect(eval("' 42 ' * 1"), 42.0);
    });
  });

  group('custom functions', () {
    test('arguments are coerced to the prototype', () {
      ec.addFunctionHandler(_Concat());
      expect(eval('my-concat(1, 1 = 1)'), '1true');
    });

    test('unknown functions throw', () {
      expect(
        () => eval('nope()'),
        throwsA(
          isA<XPathUnhandledException>().having(
            (e) => e.message,
            'message',
            "XPath evaluation: cannot handle function 'nope'",
          ),
        ),
      );
    });
  });
}

String toXPathStringForTest(Object value) =>
    // Imported lazily to keep the public surface small.
    conversions.toXPathString(value);

final class _Concat extends XPathFunctionHandler {
  @override
  String get name => 'my-concat';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string, XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      '${args[0]}${args[1]}';
}
