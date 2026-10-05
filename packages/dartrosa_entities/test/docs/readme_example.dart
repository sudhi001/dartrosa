// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim below the imports its placeholders
// need; run by api_examples_test.dart.
// ignore_for_file: avoid_print, directives_ordering
import '../../example/example.dart' as example;
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';

Future<void> main() async {
  final repository = InMemEntitiesRepository()
    ..save('people', [
      NewEntity('a1', 'Shiv', properties: const [('full_name', 'Shiv Roy')]),
    ]);
  final config = withEntities(
    const DartRosaConfig(),
    entitiesRepository: () => repository,
  );

  final definition = await FormDefinition.parse(entityFormXml, config: config);
  final session = definition.createSession();
  // ... answer questions ...
  if (session.finalize() is FinalizeSuccess) {
    print(formEntities(session)!.entities.map((e) => e.label));
    saveFormEntities(session, repository); // the new person joins 'people'
  }
}

/// The entity form of example/example.dart.
const entityFormXml = example.xform;
