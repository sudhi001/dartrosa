// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests: closing a session, and a definition starting a new one,
// stop the old session's change events and let it be garbage collected
// (a definition used to keep every session it created, through the form's
// event listeners).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

import '../support/gc.dart';

const _form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>Lifecycle</h:title><model>
<instance><data id="life"><a/><b/></data></instance>
<bind nodeset="/data/a" type="int"/>
<bind nodeset="/data/b" type="int" calculate="/data/a * 2"/>
</model></h:head>
<h:body><input ref="/data/a"><label>A</label></input></h:body></h:html>
''';

/// Creates a session of [definition] that nothing else references, and a
/// weak reference to it.
WeakReference<FormSession> _unreferencedSession(FormDefinition definition) =>
    WeakReference(definition.createSession());

void main() {
  late FormDefinition definition;

  setUp(() async => definition = await FormDefinition.parse(_form));

  test('close ends the changes stream; closing twice is harmless', () async {
    final session = definition.createSession();
    final changes = <String>[];
    var done = false;
    session.changes.listen(
      (c) => changes.add(c.kind),
      onDone: () => done = true,
    );
    session.answer(session.root.children.first.index, const IntegerValue(2));
    expect(changes, ['value', 'answer']);
    expect(session.isClosed, isFalse);

    await session.close();
    expect(done, isTrue);
    expect(session.isClosed, isTrue);
    await session.close();
  });

  test('a closed session can still be answered and read, silently', () async {
    final session = definition.createSession();
    await session.close();
    final a = session.root.children.first;
    expect(
      session.answer(a.index, const IntegerValue(4)),
      isA<AnswerAccepted>(),
    );
    session.language = null;
    final repeatless = session.saveDraft();
    expect(repeatless, contains('<b>8</b>'));
  });

  test('a new session closes the previous one', () async {
    final first = definition.createSession();
    var firstDone = false;
    final firstChanges = <String>[];
    first.changes.listen(
      (c) => firstChanges.add(c.kind),
      onDone: () => firstDone = true,
    );
    final second = definition.createSession();
    await pumpEventQueue();
    expect(first.isClosed, isTrue);
    expect(firstDone, isTrue);
    expect(second.isClosed, isFalse);

    final secondChanges = <String>[];
    second.changes.listen((c) => secondChanges.add(c.kind));
    second.answer(second.root.children.first.index, const IntegerValue(1));
    expect(secondChanges, ['value', 'answer']);
    expect(firstChanges, isEmpty);
    await second.close();
  });

  group('garbage collection', () {
    test('the current session is kept by its definition', () async {
      final weak = _unreferencedSession(definition);
      await collectGarbage();
      expect(weak.target, isNotNull);
    });

    test('a session replaced by a new one can be collected', () async {
      final weak = _unreferencedSession(definition);
      final current = definition.createSession();
      await pumpEventQueue();
      await collectGarbage();
      expect(weak.target, isNull);
      await current.close();
    });

    test('a closed session can be collected', () async {
      final weak = _unreferencedSession(definition);
      await weak.target!.close();
      await collectGarbage();
      expect(weak.target, isNull);
    });
  });
}
