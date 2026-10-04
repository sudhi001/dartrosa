@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:test/test.dart';

import '../support/forms.dart' show skipUnlessUtc;
import 'structure_dump.dart';

/// Resolves `jr://file/x`, `jr://file-csv/x`, … to files next to the form,
/// as the oracle does.
final class _DirectoryResolver implements ResourceResolver {
  _DirectoryResolver(this.dir);

  final Directory dir;

  @override
  Future<Uint8List> read(String uri) async {
    final match = RegExp(r'^jr://[^/]+/(.*)$').firstMatch(uri);
    final file = File('${dir.path}/${match?.group(1) ?? uri}');
    if (!file.existsSync()) throw ResourceNotFoundException(uri);
    return file.readAsBytes();
  }
}

Directory _conformanceDir() {
  for (var dir = Directory.current; ; dir = dir.parent) {
    final candidate = Directory('${dir.path}/conformance');
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) throw StateError('conformance/ not found');
  }
}

/// Compares the parsed structure of every form with the JavaRosa oracle's
/// `traces/structure` golden.
void main() {
  final conformance = _conformanceDir();
  final traces = Directory('${conformance.path}/traces/structure');
  final goldens =
      traces
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final golden in goldens) {
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
        final form = await XFormParser(
          resolver: _DirectoryResolver(formFile.parent),
        ).parse(formFile.readAsStringSync());
        actual =
            jsonDecode(jsonEncode(structureOf(form))) as Map<String, Object?>;
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
      _diff('', expected, actual, differences);
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}

void _diff(String path, Object? expected, Object? actual, List<String> out) {
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      _diff('$path.$key', expected[key], actual[key], out);
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} != ${actual.length}');
    }
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      _diff('$path[$i]', expected[i], actual[i], out);
    }
  } else if (!const DeepCollectionEquality().equals(expected, actual)) {
    out.add('$path: expected <$expected> got <$actual>');
  }
}

/// Whether [node] holds a time or date-time instance value.
bool _hasZonedValue(Object? node) => switch (node) {
  {'type': 'time' || 'dateTime', 'value': final Object _} => true,
  Map() => node.values.any(_hasZonedValue),
  List() => node.any(_hasZonedValue),
  _ => false,
};
