import 'package:dartrosa/src/util/java_double.dart';
import 'package:test/test.dart';

void main() {
  // Runs on every platform, including dart2js/dart2wasm.
  const cases = [
    (0.0, '0.0'),
    (-0.0, '-0.0'),
    (1.0, '1.0'),
    (-1.0, '-1.0'),
    (10.0, '10.0'),
    (0.1, '0.1'),
    (123.0, '123.0'),
    (734.04, '734.04'),
    (0.12345, '0.12345'),
    (0.666, '0.666'),
    (333.333, '333.333'),
    (1.23e21, '1.23E21'),
    (1.23e-18, '1.23E-18'),
    (1e7, '1.0E7'),
    (9999999.0, '9999999.0'),
    (1e-3, '0.001'),
    (0.00099999, '9.9999E-4'),
    (1e23, '1.0E23'),
    (double.maxFinite, '1.7976931348623157E308'),
    (5e-324, '4.9E-324'),
    (0.5, '0.5'),
    (100.0, '100.0'),
    (2e-3, '0.002'),
    (double.nan, 'NaN'),
    (double.infinity, 'Infinity'),
    (double.negativeInfinity, '-Infinity'),
  ];
  for (final (value, expected) in cases) {
    test('$value -> $expected', () {
      expect(javaDoubleToString(value), expected);
    });
  }
}
