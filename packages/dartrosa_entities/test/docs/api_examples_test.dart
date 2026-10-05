// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

/// The entity form of example/example.dart: it creates a person in the
/// local `people` list.
const entityFormXml = example.xform;

void main() {
  test('withEntities', () async {
    final repository = InMemEntitiesRepository()..addList('people');
    final config = withEntities(
      const DartRosaConfig(),
      entitiesRepository: () => repository,
    );
    final definition = await FormDefinition.parse(
      entityFormXml,
      config: config,
    );
    final session = definition.createSession();
    final name = session.root.children.whereType<QuestionNode>().first;
    session.answer(name.index, const StringValue('Kendall Roy'));
    if (session.finalize() is FinalizeSuccess) {
      saveFormEntities(session, repository); // the new person joins 'people'
    }

    expect(repository.getCount('people'), 1);
  });

  test('README example', () async {
    await expectLater(readme.main, prints(isNotEmpty));
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints(contains('people: 2')));
  });
}
