import 'package:dartrosa/src/util/java_lang.dart';
import 'package:test/test.dart';

void main() {
  test('javaParseInt follows Integer.parseInt', () {
    expect(javaParseInt('42'), 42);
    expect(javaParseInt('+42'), 42);
    expect(javaParseInt('-42'), -42);
    expect(javaParseInt('٣٤'), 34); // Arabic-Indic digits
    expect(javaParseInt('2147483647'), 2147483647);
    expect(javaParseInt('2147483648'), isNull);
    expect(javaParseInt('2147483648', bits: 64), 2147483648);
    for (final bad in ['', '+', '-', ' 1', '1 ', '0x10', '1.0', '1e3']) {
      expect(javaParseInt(bad), isNull, reason: bad);
    }
  });

  test('javaParseDouble follows Double.parseDouble', () {
    const cases = {
      '1': 1.0,
      '1.': 1.0,
      '.5': 0.5,
      '-0.5': -0.5,
      '+2.5': 2.5,
      '1e3': 1000.0,
      '1.e2': 100.0,
      '2.5E-1': 0.25,
      '  7  ': 7.0,
      '1.5d': 1.5,
      '1.5F': 1.5,
      'Infinity': double.infinity,
      '-Infinity': double.negativeInfinity,
      '0x1.8p1': 3.0,
      '0x10p0': 16.0,
    };
    cases.forEach((input, expected) {
      expect(javaParseDouble(input), expected, reason: input);
    });
    expect(javaParseDouble('NaN')!.isNaN, isTrue);
    expect(javaParseDouble('-NaN')!.isNaN, isTrue);
    for (final bad in ['', 'abc', '1,5', '٣', 'Infinityd', 'NaNd', '1e', '.']) {
      expect(javaParseDouble(bad), isNull, reason: bad);
    }
  });

  test('javaSplit follows String.split', () {
    expect(javaSplit('a;b;c', ';'), ['a', 'b', 'c']);
    expect(javaSplit('a;b;;', ';'), ['a', 'b']);
    expect(javaSplit(';', ';'), <String>[]);
    expect(javaSplit('', ';'), ['']);
    expect(javaSplit(';a', ';'), ['', 'a']);
  });
}
