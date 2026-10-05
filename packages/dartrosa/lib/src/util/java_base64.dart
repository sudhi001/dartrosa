// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// JavaRosa's own Base64 codec (`org.javarosa.core.util.Base64`).
///
/// The decoder is lenient in JavaRosa's specific way: characters outside
/// the alphabet are skipped, and input whose length (without them) isn't a
/// multiple of four decodes to nothing. `digest()`, `base64-decode()` and
/// `extract-signed()` depend on this exact behaviour.
library;

import 'dart:convert';
import 'dart:typed_data';

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

final List<int> _index = () {
  final index = List<int>.filled(256, -1);
  for (var i = 0; i < _alphabet.length; i++) {
    index[_alphabet.codeUnitAt(i)] = i;
  }
  index[0x3D] = 0; // '='
  return index;
}();

/// Standard Base64 with padding (identical to `dart:convert` here).
String javaBase64Encode(List<int> bytes) => base64Encode(bytes);

/// JavaRosa's lenient Base64 decoding of [input] bytes.
Uint8List javaBase64Decode(List<int> input) {
  var separators = 0;
  for (final b in input) {
    if (_index[b & 0xff] < 0) separators++;
  }
  if ((input.length - separators) % 4 != 0) return Uint8List(0);

  var pad = 0;
  for (var i = input.length; i > 1 && _index[input[--i] & 0xff] <= 0;) {
    if (input[i] == 0x3D) pad++;
  }
  final length = ((input.length - separators) * 6 >> 3) - pad;
  final output = Uint8List(length);
  for (var s = 0, d = 0; d < length;) {
    var bits = 0;
    for (var j = 0; j < 4; j++) {
      final c = _index[input[s++] & 0xff];
      if (c >= 0) {
        bits |= c << (18 - j * 6);
      } else {
        j--;
      }
    }
    output[d++] = bits >> 16;
    if (d < length) {
      output[d++] = bits >> 8;
      if (d < length) output[d++] = bits;
    }
  }
  return output;
}

/// Decodes [s] (as UTF-8 bytes) with [javaBase64Decode].
Uint8List javaBase64DecodeString(String s) => javaBase64Decode(utf8.encode(s));

/// Lower-case hexadecimal, as JavaRosa's `Encoding.HEX.encode`.
String hexEncode(List<int> bytes) =>
    bytes.map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0')).join();

/// JavaRosa's `Encoding.HEX.decode` (pairs of hex digits; invalid digits
/// count as -1, as Java's `Character.digit` returns).
Uint8List hexDecode(List<int> input) {
  int digit(int c) => int.tryParse(String.fromCharCode(c), radix: 16) ?? -1;
  final output = Uint8List(input.length ~/ 2);
  for (var i = 0; i + 1 < input.length; i += 2) {
    output[i ~/ 2] = (digit(input[i]) << 4) + digit(input[i + 1]);
  }
  return output;
}
