// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

/// A select whose choices come from `fruits.csv` (a `search()`
/// appearance).
const searchForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Fruit</h:title>
    <model>
      <instance><data id="fruit"><fruit/></data></instance>
      <bind nodeset="/data/fruit" type="string"/>
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/fruit" appearance="search('fruits')">
      <label>Fruit</label>
      <item><label>label</label><value>name</value></item>
    </select1>
  </h:body>
</h:html>
''';

void main() {
  test('ExternalDataPlugin', () async {
    final mediaResolver = MapResourceResolver({
      'jr://file/fruits.csv': utf8.encode(
        'name,label\nmango,Mango\nbanana,Banana\n',
      ),
    });
    final mediaFileNames = ['fruits.csv'];
    const xml = searchForm;

    final config = DartRosaConfig(
      resolver: mediaResolver,
      plugins: [ExternalDataPlugin(listMedia: (form) => mediaFileNames)],
    );
    final definition = await FormDefinition.parse(xml, config: config);
    final select = definition.createSession().root.children.single;
    // Choices of a select with a search() appearance:
    final choices = loadSelectChoices(
      FormEntryPrompt(definition.formDef, select.index),
    );

    expect([for (final c in choices) c.value], ['mango', 'banana']);
  });

  test('README example', () async {
    await expectLater(readme.main, prints('1.5\n'));
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints('price: 1.5\n'));
  });
}
