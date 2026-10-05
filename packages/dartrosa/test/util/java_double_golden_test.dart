// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa/src/util/java_double.dart';
import 'package:test/test.dart';

/// Compares against `conformance/numbers/double_to_string.json`, produced by
/// real Java (`oracle.sh doubles`): edge cases plus 10,000 random doubles.
void main() {
  test('matches Java Double.toString for every golden case', () {
    final file = _conformanceFile('numbers/double_to_string.json');
    final golden = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final cases = (golden['cases']! as List<Object?>).cast<List<Object?>>();
    expect(cases.length, greaterThan(10000));

    final bytes = ByteData(8);
    final mismatches = <String>[];
    for (final [bits as String, javaString as String] in cases) {
      bytes.setUint64(0, BigInt.parse(bits, radix: 16).toSigned(64).toInt());
      final value = bytes.getFloat64(0);
      final dartString = javaDoubleToString(value);
      if (dartString != javaString) {
        mismatches.add('$bits: java=$javaString dart=$dartString');
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.take(20).join('\n'));
  });
}

/// Finds [path] under the repository's `conformance/` directory, whether the
/// tests run from the repository root or from the package directory.
File _conformanceFile(String path) {
  for (var dir = Directory.current; ; dir = dir.parent) {
    final file = File('${dir.path}/conformance/$path');
    if (file.existsSync()) return file;
    if (dir.parent.path == dir.path) {
      throw StateError(
        'conformance/$path not found above ${Directory.current}',
      );
    }
  }
}
