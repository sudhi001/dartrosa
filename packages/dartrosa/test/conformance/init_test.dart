@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'structure_dump.dart';

/// Compares the dependency graph and the instance after
/// `initialize(newInstance: true)` of every form with the JavaRosa
/// oracle's `traces/init` golden.
void main() {
  final traces = Directory('${conformanceDir().path}/traces/init');
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
    test(formPath, skip: skipUnlessUtc, () async {
      final parse = trace['parse']! as Map<String, Object?>;
      final file = File('${conformanceDir().path}/$formPath');
      FormDef form;
      try {
        form = await parseFile(file);
      } on Object catch (e) {
        expect(parse['ok'], isFalse, reason: 'JavaRosa parses it: $e');
        final error = parse['error']! as Map<String, Object?>;
        if (error['type'] == 'XFormParseException') {
          expect(e, isA<XFormParseException>());
          expect(
            stableMessage((e as XFormParseException).message),
            error['message'],
          );
        }
        return;
      }
      expect(parse['ok'], isTrue, reason: 'JavaRosa fails: ${parse['error']}');
      final differences = <String>[];
      diff(
        '.cascades',
        trace['cascades'],
        _json(cascadesOf(form)),
        differences,
      );
      final init = trace['initialize']! as Map<String, Object?>;
      try {
        form.initialize(newInstance: true);
      } on Object catch (e) {
        expect(init['ok'], isFalse, reason: 'JavaRosa initializes it: $e');
        // JavaRosa evaluates a DAG level in identity-hash order, so what a
        // failed initialization already changed isn't comparable; the error
        // is.
        expect(exceptionMessage(e), (init['error']! as Map)['message']);
        expect(differences, isEmpty, reason: differences.join('\n'));
        return;
      }
      expect(init['ok'], isTrue, reason: 'JavaRosa fails: ${init['error']}');
      diff(
        '.instance',
        trace['instance'],
        _json(structureOf(form)['instance']),
        differences,
      );
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}

Object? _json(Object? o) => jsonDecode(jsonEncode(o));

/// [e]'s message as Java's `getMessage()` gives it (Dart's
/// `FormatException.toString()` adds its type), with cycle lines sorted.
String exceptionMessage(Object e) =>
    stableMessage(e is FormatException ? e.message : '$e');

/// The oracle's `stableError`: cycle node lines sorted.
String stableMessage(String message) {
  const marker = 'The following nodes are likely involved in the loop:';
  final at = message.indexOf(marker);
  if (at == -1) return message;
  final end = at + marker.length;
  final lines =
      message.substring(end).split('\n').where((l) => l.isNotEmpty).toList()
        ..sort();
  return '${message.substring(0, end)}\n${lines.join('\n')}';
}

/// Records differences between [expected] and [actual] under [path].
void diff(String path, Object? expected, Object? actual, List<String> out) {
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      diff('$path.$key', expected[key], actual[key], out);
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} != ${actual.length}');
    }
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      diff('$path[$i]', expected[i], actual[i], out);
    }
  } else if (!const DeepCollectionEquality().equals(expected, actual)) {
    out.add('$path: expected <$expected> got <$actual>');
  }
}
