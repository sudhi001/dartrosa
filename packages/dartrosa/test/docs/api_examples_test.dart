// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot. api_docs_test.dart
// checks that every such block is in a doc test like this one.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

/// The form of example/example.dart: name, age (constraint `. >= 0`) and
/// a calculated `adult`.
const xform = example.xform;

void main() {
  test('library: dartrosa', () async {
    await expectLater(() async {
      final definition = await FormDefinition.parse(xform);
      final session = definition.createSession();
      final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
      session.answer(name.index, const StringValue('Ada'));
      session.answer(age.index, const IntegerValue(42));
      if (session.finalize() case FinalizeSuccess(:final submission)) {
        print(submission.xml);
      }
    }, prints(contains('<name>Ada</name><age>42</age><adult>yes</adult>')));
  });

  test('FormDefinition', () async {
    final definition = await FormDefinition.parse(xform);
    print(definition.title); // Household
    final session = definition.createSession();
    // ... answer questions, then keep a draft ...
    final draft = session.saveDraft();

    // Later: continue the draft (this closes `session`).
    final resumed = definition.createSession(existingInstance: draft);

    expect(definition.title, 'Household');
    expect(session.isClosed, isTrue);
    expect(resumed.isClosed, isFalse);
  });

  test('FormSession', () async {
    final definition = await FormDefinition.parse(xform);
    final printed = <String>[];
    await runZonedPrints(printed, () async {
      final session = definition.createSession();
      final changes = session.changes.listen((change) => print(change.kind));
      final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
      session.answer(name.index, const StringValue('Ada'));
      session.answer(age.index, const UncastValue('42')); // text is parsed
      switch (session.finalize()) {
        case FinalizeSuccess(:final submission):
          print(submission.xml);
        case FinalizeFailure(:final failure):
          print('Fix the question at ${failure.index}');
      }
      await changes.cancel();
      await session.close();
    });
    expect(printed, contains('value'));
    expect(printed.last, contains('<age>42</age><adult>yes</adult>'));
  });

  test('FormNavigator', () async {
    final session = (await FormDefinition.parse(xform)).createSession();
    final printed = <String>[];
    await runZonedPrints(printed, () async {
      final navigator = session.navigator;
      while (navigator.next() != FormEntryEvent.endOfForm) {
        if (navigator.current case QuestionNode(:final label)) {
          print(label);
        }
      }
    });
    expect(printed, ['Name', 'Age']);
  });

  test('DartRosaConfig', () async {
    final config = DartRosaConfig(
      resolver: MapResourceResolver({
        'jr://file/towns.csv': utf8.encode('name,label\nnbo,Nairobi\n'),
      }),
      properties: MapPropertyManager({'deviceid': 'my-app:device-1'}),
    );
    final definition = await FormDefinition.parse(xform, config: config);

    expect(definition.config, same(config));
  });

  test('AnswerResult', () async {
    final session = (await FormDefinition.parse(xform)).createSession();
    final [_, age] = session.root.visibleChildren.cast<QuestionNode>();
    final printed = <String>[];
    await runZonedPrints(printed, () async {
      switch (session.answer(age.index, const IntegerValue(-3))) {
        case AnswerAccepted():
          break;
        case AnswerRequired(:final message) ||
            AnswerConstraintViolated(:final message):
          print(message ?? 'Invalid answer');
        case AnswerRejected(:final message):
          print('Not a valid value: $message');
      }
    });
    expect(printed, ["Age can't be negative"]);
  });

  test('BindBuilderXFormsElement', () {
    final element = bind('/data/age')
      ..type('int')
      ..required()
      ..constraint('. > 0');
    expect(element.asXml(), contains('constraint=". > 0"'));
  });

  test('README example', () async {
    await expectLater(readme.main, prints(contains('<age>42</age>')));
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints(contains('<age>42</age>')));
  });
}

/// Runs [body], adding what it prints to [printed] instead of printing it.
Future<void> runZonedPrints(
  List<String> printed,
  Future<void> Function() body,
) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) => printed.add(line),
  ),
);
