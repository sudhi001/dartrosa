// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

/// The form of example/example.dart: a village pre-filled from the
/// last-saved instance.
const xform = example.xform;

void main() {
  test('collectFormConfig', () async {
    final lastSaved = LastSaved(InMemoryLastSavedStore(), 'visit-v1');
    final config = collectFormConfig(
      media: MapResourceResolver(const {}), // the form's media files
      lastSaved: lastSaved,
    );
    final definition = await FormDefinition.parse(xform, config: config);

    expect(definition.createSession().isClosed, isFalse);
  });

  test('LastSaved', () async {
    final store = InMemoryLastSavedStore();
    const formKey = 'visit-v1';
    final mediaResolver = MapResourceResolver(const {});
    final session = (await FormDefinition.parse(xform)).createSession();
    final village = session.root.children.whereType<QuestionNode>().single;
    session.answer(village.index, const StringValue('Kisumu'));

    final lastSaved = LastSaved(store, formKey);
    final config = DartRosaConfig(
      lastSavedSrc: LastSaved.src,
      resolver: lastSaved.resolver(mediaResolver),
    );
    // ... after saving or finalizing an instance:
    await lastSaved.instanceSaved(session);

    expect(store.instances[formKey], contains('Kisumu'));
    final next = (await FormDefinition.parse(
      xform,
      config: config,
    )).createSession();
    expect(next.saveDraft(), contains('<village>Kisumu</village>'));
  });

  test('FastExternalItemsetsPlugin', () async {
    final mediaResolver = MapResourceResolver(const {});

    final config = DartRosaConfig(
      resolver: mediaResolver, // serves jr://file/itemsets.csv
      plugins: [FastExternalItemsetsPlugin()],
    );

    expect(config.plugins.single, isA<FastExternalItemsetsPlugin>());
  });

  test('README example', () async {
    await expectLater(readme.main, prints(contains('<deprecatedID>')));
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints(contains('true')));
  });
}
