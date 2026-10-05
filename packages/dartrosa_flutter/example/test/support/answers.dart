// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart' show FormEntryPrompt;
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:dartrosa_flutter_example/src/external_choices.dart';

/// Park-Miller minimal standard generator (as in the conformance fuzz
/// walk), so every run answers the same way.
class Rng {
  /// Creates a generator for [seed].
  Rng(int seed) : _state = seed % 2147483646 + 1;

  int _state;

  /// A number in `[0, bound)`.
  int next(int bound) {
    _state = _state * 16807 % 2147483647;
    return _state % bound;
  }
}

/// A seed from [text].
int seedOf(String text) =>
    text.codeUnits.fold(17, (h, c) => (h * 31 + c) % 2147483647);

const _words = [
  'alpha', 'beta', 'gamma delta', 'épsilon', 'zeta & eta', 'theta<iota>', //
  "kappa'lambda", 'mu"nu', '123', 'x y z',
];

/// The choices of [node]: from form media when it uses them.
List<SelectChoice> choicesOf(FormSession session, QuestionNode node) {
  try {
    return externalChoices(
          FormEntryPrompt(session.definition.formDef, node.index),
        ) ??
        node.choices;
  } on Object {
    return node.choices;
  }
}

/// A type-valid random answer to [node] (the conformance fuzz walk's
/// generator, as answer values), or `null` for "no answer".
AnswerValue? randomAnswer(Rng rng, FormSession session, QuestionNode node) {
  if (node.controlType == ControlType.trigger) return const StringValue('OK');
  final choices = [...choicesOf(session, node)]
    ..sort((a, b) => a.value.compareTo(b.value));
  if (node.controlType == ControlType.rank) {
    if (choices.isEmpty) return null;
    for (var i = choices.length - 1; i > 0; i--) {
      final j = rng.next(i + 1);
      final swap = choices[i];
      choices[i] = choices[j];
      choices[j] = swap;
    }
    return MultipleItemsValue([for (final c in choices) Selection(c.value)]);
  }
  final text = switch (node.dataType) {
    DataType.choice when choices.isEmpty => null,
    DataType.choice => choices[rng.next(choices.length)].value,
    DataType.multipleItems when choices.isEmpty => null,
    DataType.multipleItems => [
      for (final c in choices)
        if (rng.next(2) == 0) c.value,
    ].join(' '),
    DataType.boolean => null,
    DataType.integer => '${rng.next(200) - 50}',
    DataType.long => '${rng.next(100000) * 1000}',
    DataType.decimal => '${rng.next(2000) - 500}.${rng.next(100)}',
    DataType.date =>
      '20${10 + rng.next(20)}-0${1 + rng.next(9)}-1${rng.next(9)}',
    DataType.time => '1${rng.next(10)}:3${rng.next(10)}:00.000Z',
    DataType.dateTime =>
      '2021-0${1 + rng.next(9)}-1${rng.next(9)}'
          'T1${rng.next(10)}:2${rng.next(10)}:00.000Z',
    DataType.geopoint =>
      '${rng.next(180) - 90}.${rng.next(1000)} '
          '${rng.next(360) - 180}.${rng.next(1000)} '
          '${rng.next(500)} ${rng.next(20)}',
    DataType.geotrace || DataType.geoshape => () {
      final p = '${rng.next(10)} ${rng.next(10)} 0 0';
      return '$p;${rng.next(10)} 1${rng.next(10)} 0 0;'
          '1${rng.next(10)} ${rng.next(10)} 0 0;$p';
    }(),
    DataType.binary => 'file${rng.next(100)}.jpg',
    _ => _words[rng.next(_words.length)],
  };
  if (node.dataType == DataType.boolean) return BooleanValue(rng.next(2) == 0);
  if (text == null || text.isEmpty) return null;
  return castToDataType(UncastValue(text), node.dataType);
}

/// The relevant questions shown with [node] (a question, or a group or
/// repeat shown as one screen).
List<QuestionNode> questionsOf(FormNode node) => switch (node) {
  _ when !node.isRelevant => const [],
  QuestionNode() => [node],
  ContainerNode(:final children) => [
    for (final child in children) ...questionsOf(child),
  ],
  RepeatNode(:final instances) => [
    for (final instance in instances) ...questionsOf(instance),
  ],
};

/// Answers every writable question of [node] with a value the form
/// accepts, trying a few random values (then no answer); returns the
/// questions no value was accepted for.
List<QuestionNode> answerScreen(Rng rng, FormSession session, FormNode node) {
  final rejected = <QuestionNode>[];
  for (final question in questionsOf(node)) {
    // Earlier answers may have changed what is relevant or writable.
    final current = session.nodeAt(question.index);
    if (current is! QuestionNode ||
        !current.isRelevant ||
        current.isReadonly ||
        current.isNote) {
      continue;
    }
    var accepted = false;
    for (var attempt = 0; attempt < 8 && !accepted; attempt++) {
      final value = attempt == 7 ? null : randomAnswer(rng, session, current);
      accepted = session.answer(current.index, value) is AnswerAccepted;
    }
    if (!accepted) rejected.add(current);
  }
  return rejected;
}
