/// Java standard-library behaviour that JavaRosa relies on and Dart does
/// differently: number parsing and `String.split`.
library;

final _unicodeDigit = RegExp(r'^\p{Nd}$', unicode: true);

/// The value of [codeUnit] as a decimal digit, following Java's
/// `Character.digit(ch, 10)` (any Unicode `Nd` digit), or -1.
int javaDigit(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit < 0x80 ||
      !_unicodeDigit.hasMatch(String.fromCharCode(codeUnit))) {
    return -1;
  }
  // Nd digits come in contiguous runs of ten starting at zero.
  var zero = codeUnit;
  while (zero > 0 &&
      codeUnit - zero < 9 &&
      _unicodeDigit.hasMatch(String.fromCharCode(zero - 1))) {
    zero--;
  }
  return (codeUnit - zero) % 10;
}

/// Java `Integer.parseInt` (32-bit) or, with [bits] 64, `Long.parseLong`.
///
/// Accepts an optional `+`/`-` sign followed by decimal digits (any Unicode
/// decimal digit, as Java does); no whitespace, no `0x` prefix. Returns
/// `null` where Java throws `NumberFormatException`.
int? javaParseInt(String s, {int bits = 32}) {
  if (s.isEmpty) return null;
  var i = 0;
  var negative = false;
  final first = s.codeUnitAt(0);
  if (first == 0x2D || first == 0x2B) {
    negative = first == 0x2D;
    i = 1;
    if (s.length == 1) return null;
  }
  var value = BigInt.zero;
  for (; i < s.length; i++) {
    final digit = javaDigit(s.codeUnitAt(i));
    if (digit < 0) return null;
    value = value * BigInt.from(10) + BigInt.from(digit);
  }
  if (negative) value = -value;
  final max = (BigInt.one << (bits - 1)) - BigInt.one;
  final min = -(BigInt.one << (bits - 1));
  if (value > max || value < min) return null;
  return value.toInt();
}

final _javaDecimal = RegExp(
  r'^([+-]?)(NaN|Infinity|((\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)[fFdD]?)$',
);
final _javaHex = RegExp(
  r'^([+-]?)0[xX]([0-9a-fA-F]*)\.?([0-9a-fA-F]*)[pP]([+-]?\d+)[fFdD]?$',
);

/// Java `Double.parseDouble`: trims characters `<= ' '`, accepts an
/// optional sign, `NaN`, `Infinity`, decimal and exponent notation, a
/// trailing `f`/`F`/`d`/`D`, and hexadecimal floating point. Returns `null`
/// where Java throws `NumberFormatException`.
double? javaParseDouble(String input) {
  var start = 0;
  var end = input.length;
  while (start < end && input.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && input.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  final s = input.substring(start, end);
  final decimal = _javaDecimal.firstMatch(s);
  if (decimal != null) {
    final negative = decimal.group(1) == '-';
    final value = switch (decimal.group(2)!) {
      'NaN' => double.nan,
      'Infinity' => double.infinity,
      // Dart rejects a trailing '.', so append a zero ("1." -> "1.0").
      _ => double.parse(
        decimal.group(4)!.replaceFirst(RegExp(r'\.$'), '.0') +
            (decimal.group(5) ?? ''),
      ),
    };
    return negative ? -value : value;
  }
  final hex = _javaHex.firstMatch(s);
  if (hex != null) {
    final intPart = hex.group(2)!;
    final fracPart = hex.group(3)!;
    if (intPart.isEmpty && fracPart.isEmpty) return null;
    final mantissa = BigInt.parse(
      '0$intPart$fracPart'.replaceFirst(RegExp('^0+(?=.)'), ''),
      radix: 16,
    );
    final exponent = int.parse(hex.group(4)!) - 4 * fracPart.length;
    var value = mantissa.toDouble();
    value = exponent >= 0 ? value * _pow2(exponent) : value / _pow2(-exponent);
    return hex.group(1) == '-' ? -value : value;
  }
  return null;
}

double _pow2(int n) {
  var result = 1.0;
  for (var i = 0; i < n; i++) {
    result *= 2;
  }
  return result;
}

/// Java `String.split` with a literal (non-regex) [separator]: trailing
/// empty strings are removed, and a string without the separator yields a
/// single element (even when empty).
List<String> javaSplit(String s, String separator) {
  final parts = s.split(separator);
  if (parts.length == 1) return parts;
  var end = parts.length;
  while (end > 0 && parts[end - 1].isEmpty) {
    end--;
  }
  return parts.sublist(0, end);
}
