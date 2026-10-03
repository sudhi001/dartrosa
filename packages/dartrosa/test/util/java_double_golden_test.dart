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
    final file = File('../../conformance/numbers/double_to_string.json');
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
