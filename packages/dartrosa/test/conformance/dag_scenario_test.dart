@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/xform/xform_answer_data_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'init_test.dart' show diff, stableMessage;
import 'structure_dump.dart';

/// Replays the `scenarios/**.dag.json` scripts (value changes, repeat
/// insertion and deletion, constraints, post-processing, driven on the
/// form directly) and compares the instance after each step with the
/// JavaRosa oracle's `traces/dag` golden.
void main() {
  final root = conformanceDir();
  final traces = Directory('${root.path}/traces/dag');
  final goldens =
      traces
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dag.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final golden in goldens) {
    final trace = jsonDecode(golden.readAsStringSync()) as Map<String, Object?>;
    test(golden.uri.pathSegments.last, skip: skipUnlessUtc, () async {
      final form = await parseFile(File('${root.path}/${trace['form']}'))
        ..initialize(newInstance: true);
      final differences = <String>[];
      final steps = trace['steps']! as List<Object?>;
      for (final (i, raw) in steps.indexed) {
        final expected = raw! as Map<String, Object?>;
        final step = expected['step']! as Map<String, Object?>;
        Object? result;
        String? error;
        try {
          result = _apply(form, step);
        } on Object catch (e) {
          error = stableMessage('$e');
        }
        final at = '.steps[$i] ${jsonEncode(step)}';
        final expectedError = (expected['error'] as Map?)?['message'];
        if (expectedError != error) {
          differences.add('$at: error expected <$expectedError> got <$error>');
        }
        diff('$at.result', expected['result'], result, differences);
        diff(
          '$at.instance',
          expected['instance'],
          jsonDecode(jsonEncode(structureOf(form)['instance'])),
          differences,
        );
      }
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}

Object? _apply(FormDef form, Map<String, Object?> step) {
  final ref = step['ref'] == null ? null : getRef(step['ref']! as String);
  final value = step['value'] as String?;
  switch (step['op']) {
    case 'setValue':
      final node = form.mainInstance.resolveReference(ref!)!;
      form.setValue(
        value == null ? null : parseAnswerData(value, node.dataType),
        ref,
      );
    case 'createRepeat':
      form.createRepeatInstance(ref!);
    case 'deleteRepeat':
      form.deleteRepeatInstance(ref!);
    case 'constraint':
      final node = form.mainInstance.resolveReference(ref!)!;
      return form.evaluateConstraint(
        ref,
        value == null ? null : parseAnswerData(value, node.dataType),
      );
    case 'repeatRelevant':
      return form.isRepeatRelevant(ref!);
    case 'postProcess':
      form.postProcessInstance();
    default:
      throw ArgumentError('unknown op ${step['op']}');
  }
  return null;
}
