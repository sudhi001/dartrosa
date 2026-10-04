@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/data_type.dart';
import 'package:dartrosa/src/xform/xform_answer_data_parser.dart';
import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'init_test.dart' show diff, stableMessage;
import 'structure_dump.dart';

const _maxEvents = 2000;

/// Replays the oracle's walk traces (`traces/walk`, one per form: walk the
/// whole form, then validate) and scenario traces (`traces/scenarios`)
/// through DartRosa's form-entry API and compares every event and the
/// final serialized instance.
void main() {
  final root = conformanceDir();
  final goldens = [
    for (final kind in ['walk', 'scenarios'])
      ...Directory('${root.path}/traces/$kind')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  for (final golden in goldens) {
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
          actual['error'] = {'message': stableMessage('$e')};
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
        diff('.steps[$i]', expected, _json(actual), differences);
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

Object? _json(Object? o) => jsonDecode(jsonEncode(o));

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
        events.add(_describe(model, event));
      } while (event != FormEntryEvent.endOfForm && events.length < _maxEvents);
      out['events'] = events;
    case 'next':
      out['event'] = _describe(model, controller.stepToNextEvent());
    case 'prev':
      out['event'] = _describe(model, controller.stepToPreviousEvent());
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

String _dataTypeName(DataType t) => t == DataType.nullType ? 'null' : t.name;

Map<String, Object?> _describe(FormEntryModel model, FormEntryEvent event) {
  final e = <String, Object?>{'event': event.name};
  final ref = model.formIndex.reference;
  if (ref != null) e['ref'] = ref.toString(includePredicates: true);
  if (event == FormEntryEvent.question) {
    final p = model.questionPrompt();
    e
      ..['control'] = p.controlType.name
      ..['dataType'] = _dataTypeName(p.dataType)
      ..['appearance'] = p.appearanceHint
      ..['label'] = p.longText
      ..['hint'] = p.helpText
      ..['required'] = p.isRequired
      ..['readonly'] = p.isReadOnly;
    final value = p.answerValue;
    e['value'] = value == null ? null : normalize(value.uncast().string);
    final q = p.question;
    if (q.controlType == ControlType.selectOne ||
        q.controlType == ControlType.selectMulti ||
        q.controlType == ControlType.rank) {
      final choices = [
        for (final c in p.selectChoices)
          {'value': c.value, 'label': p.selectChoiceText(c)},
      ];
      final itemset = q.dynamicChoices;
      if (itemset != null &&
          itemset.randomize &&
          itemset.randomSeedExpr == null) {
        choices.sort((a, b) => '${a['value']}'.compareTo('${b['value']}'));
        e['choicesOrder'] = 'unseededRandom';
      }
      e['choices'] = choices;
    }
  } else if (event == FormEntryEvent.group || event == FormEntryEvent.repeat) {
    e
      ..['label'] = model.captionPrompt().longText
      ..['appearance'] = model.captionPrompt().appearanceHint;
  }
  return e;
}
