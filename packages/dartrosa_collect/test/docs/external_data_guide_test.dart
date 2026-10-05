// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of docs/guides/external-data-and-entities.md, run as tests so
// the guide can't rot (packages/dartrosa/test/docs checks that the guide's
// snippets are here).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart' show FormEntryPrompt;
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa" '
    'xmlns:entities="http://www.opendatakit.org/xforms/entities"';

/// A select whose choices come from towns.csv, filtered by region.
const choicesForm =
    '''
<h:html $_ns>
  <h:head><h:title>Towns</h:title><model>
    <instance><data id="towns"><region/><town/></data></instance>
    <instance id="towns" src="jr://file-csv/towns.csv"/>
    <bind nodeset="/data/region" type="string"/>
    <bind nodeset="/data/town" type="string"/>
  </model></h:head>
  <h:body>
    <input ref="/data/region"><label>Region</label></input>
    <select1 ref="/data/town"><label>Town</label>
      <itemset nodeset="instance('towns')/root/item[region = /data/region]">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
  </h:body>
</h:html>''';

/// pulldata() and a search() select over fruits.csv.
const fruitsForm =
    '''
<h:html $_ns>
  <h:head><h:title>Fruits</h:title><model>
    <instance><data id="fruits"><fruit/><price/><favourite/></data></instance>
    <bind nodeset="/data/fruit" type="string"/>
    <bind nodeset="/data/price" type="string"
        calculate="pulldata('fruits', 'price', 'name', /data/fruit)"/>
    <bind nodeset="/data/favourite" type="string"/>
  </model></h:head>
  <h:body>
    <input ref="/data/fruit"><label>Fruit</label></input>
    <input ref="/data/price"><label>Price</label></input>
    <select1 ref="/data/favourite" appearance="search('fruits')">
      <label>Favourite</label>
      <item><label>label</label><value>name</value></item>
    </select1>
  </h:body>
</h:html>''';

/// Registers a person in the "people" entity list.
const entityForm =
    '''
<h:html $_ns>
  <h:head><h:title>Add person</h:title>
    <model entities:entities-version="2024.1.0">
      <instance>
        <data id="add-person">
          <name/><known/>
          <meta>
            <entity dataset="people" create="1" id=""><label/></entity>
          </meta>
        </data>
      </instance>
      <instance id="people" src="jr://file-csv/people.csv"/>
      <bind nodeset="/data/name" type="string" entities:saveto="full_name"/>
      <bind nodeset="/data/known" type="string"
          calculate="count(instance('people')/root/item)"/>
      <bind nodeset="/data/meta/entity/@id" type="string"/>
      <bind nodeset="/data/meta/entity/label" type="string"
          calculate="/data/name"/>
      <setvalue event="odk-instance-first-load"
          ref="/data/meta/entity/@id" value="uuid()"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Name</label></input>
    <input ref="/data/known"><label>People known</label></input>
  </h:body>
</h:html>''';

void main() {
  test('choices from a CSV secondary instance', () async {
    final definition = await FormDefinition.parse(
      choicesForm,
      config: DartRosaConfig(
        resolver: MapResourceResolver({
          'jr://file-csv/towns.csv': utf8.encode(
            'name,label,region\nnbo,Nairobi,central\nmsa,Mombasa,coast\n',
          ),
        }),
      ),
    );
    final session = definition.createSession();
    final [region, town] = session.root.children.cast<QuestionNode>();
    session.answer(region.index, const StringValue('coast'));
    final towns = [for (final c in town.choices) c.value]; // ['msa']
    expect(towns, ['msa']);
  });

  test('pulldata() and search() over CSV media', () async {
    // The form's media files, as downloaded with the form.
    final media = MapResourceResolver({
      'jr://file/fruits.csv': utf8.encode(
        'name,label,price\nmango,Mango,1.5\npapaya,Papaya,2\n',
      ),
    });
    final config = DartRosaConfig(
      resolver: media,
      plugins: [
        // Imports the CSV files when the form loads and registers
        // pulldata(). Give it a persistent ExternalDataRepository to
        // import each file only when it changes.
        ExternalDataPlugin(listMedia: (form) => ['fruits.csv']),
      ],
    );
    final definition = await FormDefinition.parse(fruitsForm, config: config);
    final session = definition.createSession();

    final [fruit, price, favourite] = session.root.children
        .cast<QuestionNode>();
    session.answer(fruit.index, const StringValue('mango'));
    final shown = price.value?.displayText; // '1.5'

    // A select with a search() appearance: its choices come from the CSV.
    final choices = loadSelectChoices(
      FormEntryPrompt(definition.formDef, favourite.index),
    );
    final names = [for (final c in choices) c.value]; // mango, papaya
    session.answer(favourite.index, const SelectOneValue(Selection('papaya')));

    expect(shown, '1.5');
    expect(names, ['mango', 'papaya']);
    expect(session.saveDraft(), contains('<favourite>papaya</favourite>'));
  });

  test('an entity form adds to a local entity list', () async {
    // Your storage of the entity lists downloaded from the server
    // (implement EntitiesRepository on your database).
    final people = InMemEntitiesRepository()
      ..save('people', [
        NewEntity('p1', 'Ada', properties: const [('full_name', 'Ada L')]),
      ]);
    final config = withEntities(
      const DartRosaConfig(),
      entitiesRepository: () => people,
    );

    final definition = await FormDefinition.parse(entityForm, config: config);
    final session = definition.createSession();
    final [name, known] = session.root.children.cast<QuestionNode>();
    final count = known.value?.displayText; // '1': the list is an instance
    session.answer(name.index, const StringValue('Grace Hopper'));

    if (session.finalize() is FinalizeSuccess) {
      final created = formEntities(session)!.entities.single;
      // created.label == 'Grace Hopper', created.action == EntityAction.create
      saveFormEntities(session, people); // works offline, before upload
      expect(created.label, 'Grace Hopper');
    }
    expect(count, '1');
    expect(people.getCount('people'), 2);
  });
}
