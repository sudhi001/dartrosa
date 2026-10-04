import 'dart:math';

/// A [Random] whose bytes are `seed, seed + 1, ...` (mod 256): the
/// `CounterRandom` of `tool/golden/Golden.java`, which made the golden
/// fixtures.
final class CounterRandom implements Random {
  CounterRandom(this._next);

  int _next;

  @override
  int nextInt(int max) {
    if (max != 256) throw UnsupportedError('only bytes');
    return _next++ & 0xFF;
  }

  @override
  bool nextBool() => throw UnsupportedError('only bytes');

  @override
  double nextDouble() => throw UnsupportedError('only bytes');
}
