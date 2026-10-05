// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim below the first import (which
// supplies its form); run by api_examples_test.dart.
// ignore_for_file: avoid_print, directives_ordering
import '../../example/example.dart' show xform;
import 'package:dartrosa/dartrosa.dart';

Future<void> main() async {
  final definition = await FormDefinition.parse(xform);
  final session = definition.createSession();

  final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
  session.answer(name.index, const StringValue('Ada'));
  switch (session.answer(age.index, const IntegerValue(-3))) {
    case AnswerConstraintViolated(:final message):
      print('Rejected: $message');
    case AnswerAccepted() || AnswerRequired() || AnswerRejected():
      break;
  }
  session.answer(age.index, const UncastValue('42')); // text is parsed

  switch (session.finalize()) {
    case FinalizeSuccess(:final submission):
      print(submission.xml);
    case FinalizeFailure(:final failure):
      print('Invalid at ${failure.index.reference}');
  }
}
