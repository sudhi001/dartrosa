// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// Java standard-library behaviour that JavaRosa relies on and Dart does
/// differently: number parsing and `String.split`.
library;

import 'dart:typed_data';

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
final _trailingPoint = RegExp(r'\.$');
final _leadingZeros = RegExp('^0+(?=.)');

/// Java `Double.parseDouble`: trims characters `<= ' '`, accepts an
/// optional sign, `NaN`, `Infinity`, decimal and exponent notation, a
/// trailing `f`/`F`/`d`/`D`, and hexadecimal floating point. Returns `null`
/// where Java throws `NumberFormatException`.
double? javaParseDouble(String input) {
  final s = javaTrim(input);
  final decimal = _javaDecimal.firstMatch(s);
  if (decimal != null) {
    final negative = decimal.group(1) == '-';
    final value = switch (decimal.group(2)!) {
      'NaN' => double.nan,
      'Infinity' => double.infinity,
      // Dart rejects a trailing '.', so append a zero ("1." -> "1.0").
      _ => double.parse(
        decimal.group(4)!.replaceFirst(_trailingPoint, '.0') +
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
      '0$intPart$fracPart'.replaceFirst(_leadingZeros, ''),
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

/// Java `String.trim()`: strips leading and trailing characters `<= ' '`.
///
/// Unlike Dart's [String.trim], it keeps other Unicode whitespace such as
/// the no-break space (U+00A0), which matters for labels.
String javaTrim(String s) {
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

/// Java's `(int) d` cast: truncates and saturates at the 32-bit range;
/// NaN becomes 0.
int javaIntCast(double d) {
  if (d.isNaN) return 0;
  if (d >= 2147483647) return 2147483647;
  if (d <= -2147483648) return -2147483648;
  return d.truncate();
}

/// Java's `String.hashCode()` (over UTF-16 code units, 32-bit wrapping).
int javaStringHashCode(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (31 * h + c).toSigned(32);
  }
  return h;
}

/// The iteration order of a `java.util.HashMap` (or `HashSet`) with
/// default capacity holding [keys], given in insertion order.
///
/// Entries sit in buckets `(h ^ (h >>> 16)) & (capacity - 1)` of a table
/// that starts at 16 and doubles past a 0.75 load factor; iteration goes
/// bucket by bucket, in insertion order within a bucket (resizing keeps
/// that order). Used where JavaRosa's output follows such an order.
List<String> javaHashMapOrder(Iterable<String> keys) {
  final list = keys.toList();
  var capacity = 16;
  while (list.length > capacity * 0.75) {
    capacity *= 2;
  }
  int bucket(String key) {
    final h = javaStringHashCode(key);
    final spread = h ^ ((h & 0xFFFFFFFF) >> 16);
    return spread & (capacity - 1);
  }

  final indexed = [for (final (i, k) in list.indexed) (bucket(k), i, k)]
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final e in indexed) e.$3];
}

/// [s] encoded as Java's `String.getBytes("UTF-16BE")`, or with [bom] as
/// `getBytes("UTF-16")` (big-endian with a `FE FF` byte order mark).
/// Unpaired surrogates become `U+FFFD`, as in Java.
Uint8List javaUtf16Bytes(String s, {bool bom = false}) {
  final units = s.codeUnits;
  final out = Uint8List((units.length + (bom ? 1 : 0)) * 2);
  var i = 0;
  void write(int unit) {
    out[i++] = unit >> 8;
    out[i++] = unit & 0xFF;
  }

  if (bom) write(0xFEFF);
  for (var k = 0; k < units.length; k++) {
    final unit = units[k];
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh &&
        k + 1 < units.length &&
        units[k + 1] >= 0xDC00 &&
        units[k + 1] <= 0xDFFF) {
      write(unit);
      write(units[++k]);
    } else if (isHigh || isLow) {
      write(0xFFFD);
    } else {
      write(unit);
    }
  }
  return out;
}
