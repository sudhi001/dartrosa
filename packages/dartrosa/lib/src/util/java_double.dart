/// Formats [value] exactly as Java's `Double.toString(double)` (JDK 19+).
///
/// JavaRosa uses Java's formatting wherever a number becomes text: XPath
/// `string()`, calculated values written to the instance, and expression
/// `toString()`. Dart's own formatting differs (`10` vs `10.0`, `1e+21` vs
/// `1.0E21`), so a direct port would silently change collected data.
///
/// Both languages pick the shortest decimal digits that round-trip to the
/// same double, with one difference: Java always considers two significant
/// digits, so when the shortest form has a single digit it uses the closest
/// two-digit decimal instead (`4.9E-324`, where Dart prints `5e-324`). The
/// layout also differs:
/// * `1e-3 <= |value| < 1e7`: plain notation with at least one fraction
///   digit (`10.0`, `0.001`, `9999999.5`).
/// * otherwise: `d.dddE±n` with at least one fraction digit and no `+` sign
///   (`1.23E21`, `1.0E-4`).
String javaDoubleToString(double value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value > 0 ? 'Infinity' : '-Infinity';
  if (value == 0) return value.isNegative ? '-0.0' : '0.0';

  final sign = value < 0 ? '-' : '';
  final magnitude = value.abs();

  // Shortest round-trip digits, e.g. "1.23e+21" or "5e-7".
  var (digits, exponent) = _decompose(magnitude.toStringAsExponential());
  if (digits.length == 1) {
    // Closest two-digit decimal, e.g. "4.9e-324"; then drop a trailing zero.
    (digits, exponent) = _decompose(magnitude.toStringAsPrecision(2));
    if (digits.endsWith('0')) digits = digits.substring(0, 1);
  }

  if (magnitude >= 1e-3 && magnitude < 1e7) {
    final integerDigits = exponent + 1;
    if (integerDigits <= 0) {
      return '${sign}0.${'0' * -integerDigits}$digits';
    }
    if (integerDigits >= digits.length) {
      return '$sign$digits${'0' * (integerDigits - digits.length)}.0';
    }
    return '$sign${digits.substring(0, integerDigits)}.'
        '${digits.substring(integerDigits)}';
  }

  final fraction = digits.length > 1 ? digits.substring(1) : '0';
  return '$sign${digits[0]}.${fraction}E$exponent';
}

/// Splits Dart's exponential or precision notation into significant digits
/// and a decimal exponent: `"4.9e-324"` → `("49", -324)`, `"10"` → `("10", 1)`.
(String, int) _decompose(String text) {
  final e = text.indexOf('e');
  if (e >= 0) {
    return (
      text.substring(0, e).replaceFirst('.', ''),
      int.parse(text.substring(e + 1)),
    );
  }
  // Plain notation from toStringAsPrecision, e.g. "10", "0.50" or "4.9".
  final point = text.indexOf('.');
  final integer = point < 0 ? text : text.substring(0, point);
  final fraction = point < 0 ? '' : text.substring(point + 1);
  final all = integer + fraction;
  final firstNonZero = all.indexOf(RegExp('[1-9]'));
  return (all.substring(firstNonZero), integer.length - 1 - firstNonZero);
}
