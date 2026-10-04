/// `randomize()` support: JavaRosa's Fisher–Yates shuffle with the
/// Park–Miller generator for seeded shuffles, and its seed derivation.
///
/// Port of `FisherYates`, `ParkMiller` and `RandomizeHelper`. A seeded
/// shuffle must produce the same order as ODK Collect, so the arithmetic is
/// reproduced exactly (Java `long` seeds are handled as `double`s, which is
/// what JavaRosa does internally and keeps the web build exact).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'java_lang.dart';

/// A number generator yielding doubles in [0, 1).
abstract interface class _DoubleSource {
  double nextDouble();
}

final class _DartRandom implements _DoubleSource {
  final _random = math.Random();

  @override
  double nextDouble() => _random.nextDouble();
}

/// The Park–Miller "minimal standard" generator as implemented in
/// JavaRosa (with double arithmetic).
final class ParkMiller implements _DoubleSource {
  /// Seeds the generator with [seed], a Java `long` value as a double.
  ParkMiller(double seed) : _seed = seed.remainder(_modulus) {
    if (_seed <= 0) _seed += _modulus - 1;
  }

  static const double _modulus = 2147483647;
  static const double _multiplier = 16807;

  double _seed;

  /// The next value of Java's `Random.nextInt()` for this generator.
  int nextInt() {
    _seed = (_seed * _multiplier).remainder(_modulus);
    return _seed.toInt();
  }

  @override
  double nextDouble() => (nextInt() - 1) / (_modulus - 1);
}

/// A shuffled copy of [input]: seeded with [seed] (a Java `long` as a
/// double) when given, otherwise random.
List<T> shuffle<T>(List<T> input, [double? seed]) {
  final _DoubleSource random = seed == null ? _DartRandom() : ParkMiller(seed);
  final size = input.length;
  final output = List<T?>.filled(size, null);
  for (var i = 0; i < size; i++) {
    final j = (random.nextDouble() * (i + 1)).toInt();
    if (j != i) output[i] = output[j];
    output[j] = input[i];
  }
  return output.cast<T>();
}

/// JavaRosa's string seed: the first 8 bytes of the SHA-256 of the UTF-8
/// text as a signed 64-bit value (0 for the empty string), as a double.
double longHash(String text) {
  if (text.isEmpty) return 0;
  final digest = sha256.convert(utf8.encode(text)).bytes;
  var value = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | BigInt.from(digest[i]);
  }
  return value.toSigned(64).toDouble();
}

/// Java `(long) d` as a double: truncates and saturates at the 64-bit
/// range.
double javaLongValue(double d) {
  if (d.isNaN) return 0;
  if (d >= 9223372036854775807.0) return 9223372036854775807.0;
  if (d <= -9223372036854775808.0) return -9223372036854775808.0;
  return d.truncateToDouble();
}

final _choiceFilterPattern = RegExp(r'^randomize\((.+?),?([^,)\]]+?)?\)$');

/// The nodeset inside an itemset `randomize(path, seed?)` definition,
/// e.g. `/some/path[filter]` from `randomize( /some/path[filter], 33)`.
///
/// Port of `RandomizeHelper.cleanNodesetDefinition`; throws
/// [ArgumentError] when the definition doesn't use `randomize(...)`.
String cleanNodesetDefinition(String nodeset) =>
    javaTrim(randomizeArgs(nodeset)[0]);

/// The arguments of a `randomize(path, seed?)` nodeset definition.
///
/// Port of `RandomizeHelper.getArgs`.
List<String> randomizeArgs(String definition) {
  final trimmed = javaTrim(definition);
  if (!trimmed.startsWith('randomize(') || !trimmed.endsWith(')')) {
    throw ArgumentError(
      'Nodeset definition must use randomize(path, seed?) function',
    );
  }
  if (!trimmed.contains('[')) {
    return javaSplit(trimmed.substring(10, trimmed.length - 1), ',');
  }
  final match = _choiceFilterPattern.firstMatch(trimmed);
  if (match == null) throw ArgumentError("Can't parse the Nodeset definition");
  final seed = match.group(2);
  return seed != null ? [match.group(1)!, seed] : [match.group(1)!];
}
