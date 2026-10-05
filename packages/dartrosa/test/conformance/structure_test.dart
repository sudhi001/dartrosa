@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/forms.dart';
import 'structure_dump.dart';
import 'trace_support.dart';

/// Compares the parsed structure of every form with the JavaRosa oracle's
/// `traces/structure` golden.
void main() {
  final conformance = conformanceDir();
  for (final golden in goldenTraces(['structure'])) {
    final trace = jsonDecode(golden.readAsStringSync()) as Map<String, Object?>;
    final formPath = trace['form']! as String;
    // Time and date-time defaults are converted to the local zone on parse
    // (as in JavaRosa); the oracle records them in UTC.
    final zoned = _hasZonedValue(trace['structure']);
    test(formPath, skip: zoned ? skipUnlessUtc : null, () async {
      final formFile = File('${conformance.path}/$formPath');
      final expectedOk = (trace['parse']! as Map)['ok'] as bool;
      Map<String, Object?>? actual;
      Object? error;
      try {
        final form = await parseFile(formFile);
        actual = asJson(structureOf(form)) as Map<String, Object?>;
      } on Object catch (e) {
        error = e;
      }
      if (!expectedOk) {
        expect(actual, isNull, reason: 'JavaRosa fails to parse this form');
        return;
      }
      expect(error, isNull, reason: 'JavaRosa parses this form: $error');
      final expected = trace['structure']! as Map<String, Object?>;
      final differences = <String>[];
      diff('', expected, actual, differences);
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}

/// Whether [node] holds a time or date-time instance value.
bool _hasZonedValue(Object? node) => switch (node) {
  {'type': 'time' || 'dateTime', 'value': final Object _} => true,
  Map() => node.values.any(_hasZonedValue),
  List() => node.any(_hasZonedValue),
  _ => false,
};
