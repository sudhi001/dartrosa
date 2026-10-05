// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of docs/cookbook/csv-and-entities.md, run as tests so the recipe
// can't rot (packages/dartrosa/test/docs checks that the recipe's snippets
// are here).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa" '
    'xmlns:entities="http://www.opendatakit.org/xforms/entities"';

/// Registers a household in the "households" entity list, choosing its
/// village from villages.csv.
const registerXml =
    '''
<h:html $_ns>
  <h:head><h:title>Register a household</h:title>
    <model entities:entities-version="2024.1.0">
      <instance>
        <data id="register">
          <village/><head_name/>
          <meta>
            <entity dataset="households" create="1" id=""><label/></entity>
          </meta>
        </data>
      </instance>
      <instance id="villages" src="jr://file-csv/villages.csv"/>
      <bind nodeset="/data/village" type="string" entities:saveto="village"/>
      <bind nodeset="/data/head_name" type="string" entities:saveto="head"/>
      <bind nodeset="/data/meta/entity/@id" type="string"/>
      <bind nodeset="/data/meta/entity/label" type="string"
          calculate="concat(/data/head_name, ' (', /data/village, ')')"/>
      <setvalue event="odk-instance-first-load"
          ref="/data/meta/entity/@id" value="uuid()"/>
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/village"><label>Village</label>
      <itemset nodeset="instance('villages')/root/item">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
    <input ref="/data/head_name"><label>Head of household</label></input>
  </h:body>
</h:html>''';

/// A follow-up visit: choose one of the registered households.
const visitXml =
    '''
<h:html $_ns>
  <h:head><h:title>Visit</h:title>
    <model>
      <instance><data id="visit"><household/></data></instance>
      <instance id="households" src="jr://file-csv/households.csv"/>
      <bind nodeset="/data/household" type="string"/>
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/household"><label>Household</label>
      <itemset nodeset="instance('households')/root/item">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
  </h:body>
</h:html>''';

// One repository for the whole app; implement EntitiesRepository on your
// database to keep the lists between runs.
final households = InMemEntitiesRepository();

/// Loads any form of the project: entity forms and the forms that read
/// their lists share the repository.
Future<FormDefinition> loadForm(String xml, ResourceResolver media) =>
    FormDefinition.parse(
      xml,
      config: withEntities(
        DartRosaConfig(
          resolver: media,
          // pulldata() and search() over the form's CSV media.
          plugins: [
            ExternalDataPlugin(listMedia: (form) => ['villages.csv']),
          ],
        ),
        entitiesRepository: () => households,
      ),
    );

void main() {
  test('register offline, then visit', () async {
    final media = MapResourceResolver({
      'jr://file-csv/villages.csv': utf8.encode(
        'name,label\nkib,Kibera\nmat,Mathare\n',
      ),
      'jr://file/villages.csv': utf8.encode(
        'name,label\nkib,Kibera\nmat,Mathare\n',
      ),
    });

    // Lists come from the server with the form (see LocalEntityUseCases);
    // forms add entities only to lists the repository already has.
    households.addList('households');

    final register = (await loadForm(registerXml, media)).createSession();
    final [village, head] = register.root.children.cast<QuestionNode>();
    final villages = [for (final c in village.choices) c.value]; // kib, mat
    register
      ..answer(village.index, const SelectOneValue(Selection('kib')))
      ..answer(head.index, const StringValue('Amina'));
    if (register.finalize() is FinalizeSuccess) {
      // Works offline: the household is in the local list before upload.
      saveFormEntities(register, households);
    }

    // The visit form offers the new household straight away.
    final visit = (await loadForm(visitXml, media)).createSession();
    final household = visit.root.children.single as QuestionNode;
    final labels = [
      for (final c in household.choices) household.choiceLabel(c),
    ]; // ['Amina (kib)']

    expect(villages, ['kib', 'mat']);
    expect(labels, ['Amina (kib)']);
  });
}
