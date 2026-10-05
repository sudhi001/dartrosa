@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/data_type.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/src/xform/xform_answer_data_parser.dart';
import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'describe.dart';
import 'structure_dump.dart';
import 'trace_support.dart';

const _maxSteps = 400;

/// Replays the oracle's seeded random walks (`traces/fuzz`): every
/// question answered with the same type-valid random text (parsed by each
/// engine's answer parser), repeat instances added at random, then
/// validation and the serialized instance. Mirrors the oracle's
/// `FuzzWalk.java` exactly.
void main() {
  final root = conformanceDir();
  for (final golden in goldenTraces(['fuzz'])) {
    final trace = jsonDecode(golden.readAsStringSync()) as Map<String, Object?>;
    final name = golden.path.substring(golden.path.indexOf('/traces/') + 8);
    test(name, skip: skipUnlessUtc, () async {
      final parse = trace['parse']! as Map<String, Object?>;
      final Scenario s;
      try {
        s = Scenario.fromFormDef(
          await parseFile(File('${root.path}/${trace['form']}')),
        );
      } on Object catch (e) {
        expect(parse['ok'], isFalse, reason: 'JavaRosa loads it: $e');
        return;
      }
      expect(parse['ok'], isTrue);
      final actual = _run(s, trace['seed']! as int);
      final differences = <String>[];
      for (final key in ['steps', 'validate', 'instance']) {
        diff(
          '.$key',
          _withoutJavaTypes(trace[key]),
          asJson(actual[key]),
          differences,
        );
      }
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}

/// [value] without the Java exception class names the oracle records next
/// to error messages (only messages are compared).
Object? _withoutJavaTypes(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final MapEntry(:key, value: v) in map.entries)
      if (!(key == 'type' && map.containsKey('message')))
        key: _withoutJavaTypes(v),
  },
  final List<Object?> list => [for (final v in list) _withoutJavaTypes(v)],
  _ => value,
};

/// Park-Miller minimal standard generator, as in `FuzzWalk.Rng`.
final class _Rng {
  _Rng(int seed)
    : _state = seed % 2147483647 <= 0
          ? seed % 2147483647 + 2147483646
          : seed % 2147483647;

  int _state;

  int next(int bound) {
    _state = _state * 16807 % 2147483647;
    return _state % bound;
  }
}

const _words = [
  'alpha', 'beta', 'gamma delta', 'épsilon', 'zeta & eta', 'theta<iota>', //
  '', "kappa'lambda", 'mu"nu', '123', 'x y z',
];

String _answerText(_Rng rng, DataType type, List<SelectChoice> unordered) {
  // By value, so unseeded randomize() order doesn't matter.
  final choices = [...unordered]..sort((a, b) => a.value.compareTo(b.value));
  switch (type) {
    case DataType.integer:
      return '${rng.next(200) - 50}';
    case DataType.long:
      return '${rng.next(100000) * 1000}';
    case DataType.decimal:
      return '${rng.next(2000) - 500}.${rng.next(100)}';
    case DataType.date:
      return '20${10 + rng.next(20)}-0${1 + rng.next(9)}-1${rng.next(9)}';
    case DataType.time:
      return '1${rng.next(10)}:3${rng.next(10)}:00.000Z';
    case DataType.dateTime:
      return '2021-0${1 + rng.next(9)}-1${rng.next(9)}'
          'T1${rng.next(10)}:2${rng.next(10)}:00.000Z';
    case DataType.boolean:
      return rng.next(2) == 0 ? 'true' : 'false';
    case DataType.geopoint:
      return '${rng.next(180) - 90}.${rng.next(1000)} '
          '${rng.next(360) - 180}.${rng.next(1000)} '
          '${rng.next(500)} ${rng.next(20)}';
    case DataType.geotrace || DataType.geoshape:
      final p = '${rng.next(10)} ${rng.next(10)} 0 0';
      return '$p;${rng.next(10)} 1${rng.next(10)} 0 0;'
          '1${rng.next(10)} ${rng.next(10)} 0 0;$p';
    case DataType.choice:
      if (choices.isEmpty) return '';
      return choices[rng.next(choices.length)].value;
    case DataType.multipleItems:
      if (choices.isEmpty) return '';
      return [
        for (final c in choices)
          if (rng.next(2) == 0) c.value,
      ].join(' ');
    case DataType.binary:
      return 'file${rng.next(100)}.jpg';
    default:
      return _words[rng.next(_words.length)];
  }
}

String _result(AnswerStatus status) => switch (status) {
  AnswerStatus.ok => 'accepted',
  AnswerStatus.requiredButEmpty => 'required',
  AnswerStatus.constraintViolated => 'constraintViolated',
};

Map<String, Object?> _run(Scenario s, int seed) {
  final controller = s.formEntryController;
  final model = controller.model;
  final rng = _Rng(seed);
  final steps = <Object?>[];
  try {
    var event = FormEntryEvent.beginningOfForm;
    var repeatsAdded = 0;
    while (event != FormEntryEvent.endOfForm && steps.length < _maxSteps) {
      event = controller.stepToNextEvent();
      final step = describe(model, event);
      if (event == FormEntryEvent.question) {
        final p = model.questionPrompt();
        if (!p.isReadOnly) {
          final empty = rng.next(10) == 0;
          final text = empty
              ? ''
              : _answerText(rng, p.dataType, p.selectChoices);
          step['answer'] = text;
          final data = text.isEmpty
              ? null
              : parseAnswerData(text, p.dataType, p.question);
          step['result'] = _result(
            controller.answerQuestion(
              data,
              index: model.formIndex,
              midSurvey: true,
            ),
          );
          final now = model.questionPrompt().answerValue;
          step['after'] = now == null ? null : normalize(now.uncast().string);
        }
      } else if (event == FormEntryEvent.promptNewRepeat) {
        final add = repeatsAdded < 3 && rng.next(2) == 0;
        step['add'] = add;
        if (add) {
          controller.newRepeat();
          repeatsAdded++;
        }
      }
      steps.add(step);
    }
  } on Object catch (e) {
    steps.add({
      'error': {'message': exceptionMessage(e)},
    });
  }
  Object? validate;
  try {
    final outcome = s.formDef.validate();
    validate = outcome == null
        ? 'ok'
        : '${_result(outcome.outcome)} '
              '${outcome.failedPrompt.reference!.toString(includePredicates: true)}';
  } on Object catch (e) {
    validate = {
      'error': {'message': exceptionMessage(e)},
    };
  }
  Object? instance;
  try {
    instance = normalize(
      XFormSerializingVisitor().serializeInstanceToString(
        s.formDef.mainInstance,
      ),
    );
  } on Object catch (e) {
    instance = {
      'error': {'message': exceptionMessage(e)},
    };
  }
  return {'steps': steps, 'validate': validate, 'instance': instance};
}
