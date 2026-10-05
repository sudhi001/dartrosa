// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/xform/xform_answer_data_parser.dart';
import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'describe.dart';
import 'structure_dump.dart';
import 'trace_support.dart';

const _maxEvents = 2000;

/// Replays the oracle's walk traces (`traces/walk`, one per form: walk the
/// whole form, then validate) and scenario traces (`traces/scenarios`)
/// through DartRosa's form-entry API and compares every event and the
/// final serialized instance.
void main() {
  final root = conformanceDir();
  for (final golden in goldenTraces(['walk', 'scenarios'])) {
    final trace = jsonDecode(golden.readAsStringSync()) as Map<String, Object?>;
    final name = golden.path.substring(golden.path.indexOf('/traces/') + 8);
    test(name, skip: skipUnlessUtc, () async {
      final parse = trace['parse']! as Map<String, Object?>;
      final file = File('${root.path}/${trace['form']}');
      Scenario s;
      try {
        s = Scenario.fromFormDef(await parseFile(file));
      } on Object catch (e) {
        expect(parse['ok'], isFalse, reason: 'JavaRosa loads it: $e');
        return;
      }
      expect(parse['ok'], isTrue, reason: 'JavaRosa fails: ${parse['error']}');
      final form = s.formDef;
      final differences = <String>[];
      diff('.parse', parse, {
        'ok': true,
        'title': form.title,
        'languages': form.localizer?.availableLocales ?? const <String>[],
        'language': form.localizer?.locale,
      }, differences);
      final steps = trace['steps']! as List<Object?>;
      final scenario = _scenarioSteps(trace, root);
      for (final (i, raw) in steps.indexed) {
        final expected = raw! as Map<String, Object?>;
        final actual = <String, Object?>{'op': expected['op']};
        try {
          _runStep(s, scenario[i], actual);
        } on Object catch (e) {
          actual['error'] = {'message': exceptionMessage(e)};
        }
        final expectedError = expected['error'] as Map?;
        if (expectedError != null || actual['error'] != null) {
          diff(
            '.steps[$i].error.message',
            expectedError?['message'],
            (actual['error'] as Map?)?['message'],
            differences,
          );
          expected.remove('error');
          actual.remove('error');
        }
        diff('.steps[$i]', expected, asJson(actual), differences);
      }
      final expectedInstance = trace['instance'];
      String? actualInstance;
      try {
        actualInstance = normalize(
          XFormSerializingVisitor().serializeInstanceToString(
            form.mainInstance,
          ),
        );
      } on Object catch (e) {
        actualInstance = 'ERROR $e';
      }
      if (expectedInstance is String) {
        diff('.instance', expectedInstance, actualInstance, differences);
      }
      expect(differences, isEmpty, reason: differences.take(20).join('\n'));
    });
  }
}

/// The ops of [trace]: walk traces are `walk` then `validate`; scenario
/// traces replay their scenario file.
List<Map<String, Object?>> _scenarioSteps(
  Map<String, Object?> trace,
  Directory root,
) {
  final steps = trace['steps']! as List<Object?>;
  if (steps.length == 2 &&
      (steps[0]! as Map)['op'] == 'walk' &&
      (steps[1]! as Map)['op'] == 'validate') {
    return [
      {'op': 'walk'},
      {'op': 'validate'},
    ];
  }
  final file = Directory('${root.path}/scenarios')
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((f) {
        if (!f.path.endsWith('.scenario.json')) return false;
        final s = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
        return s['form'] == trace['form'] &&
            (s['steps']! as List).length == steps.length;
      });
  final scenario = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return [
    for (final s in scenario['steps']! as List) s as Map<String, Object?>,
  ];
}

void _runStep(Scenario s, Map<String, Object?> step, Map<String, Object?> out) {
  final controller = s.formEntryController;
  final model = controller.model;
  switch (step['op']) {
    case 'walk':
      s.jumpToBeginningOfForm();
      final events = <Object?>[];
      FormEntryEvent event;
      do {
        event = controller.stepToNextEvent();
        events.add(describe(model, event));
      } while (event != FormEntryEvent.endOfForm && events.length < _maxEvents);
      out['events'] = events;
    case 'next':
      out['event'] = describe(model, controller.stepToNextEvent());
    case 'prev':
      out['event'] = describe(model, controller.stepToPreviousEvent());
    case 'jumpToBeginning':
      s.jumpToBeginningOfForm();
    case 'answer':
      final index = s.indexOf(step['ref']! as String)!;
      final prompt = model.questionPrompt(index);
      final value = step['value'] as String?;
      final data = value == null || value.isEmpty
          ? null
          : parseAnswerData(value, prompt.dataType, prompt.question);
      out['result'] = switch (controller.answerQuestion(
        data,
        index: index,
        midSurvey: true,
      )) {
        AnswerStatus.ok => 'accepted',
        AnswerStatus.requiredButEmpty => 'required',
        AnswerStatus.constraintViolated => 'constraintViolated',
      };
    case 'addRepeat':
      s.createNewRepeat(step['ref']! as String);
    case 'removeRepeat':
      s.removeRepeat(step['ref']! as String);
    case 'setLanguage':
      s.language = step['language']! as String;
    case 'validate':
      final outcome = s.validationOutcome;
      out['outcome'] = switch (outcome?.outcome) {
        null || AnswerStatus.ok => 'ok',
        AnswerStatus.requiredButEmpty => 'required',
        AnswerStatus.constraintViolated => 'constraintViolated',
      };
      out['ref'] = outcome?.failedPrompt.reference?.toString(
        includePredicates: true,
      );
    default:
      throw ArgumentError('unknown op ${step['op']}');
  }
}
