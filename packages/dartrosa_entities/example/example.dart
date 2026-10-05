// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// An entity form: the local `people` list is a secondary instance, and
// finalizing creates a new person in it.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';

const xform = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:entities="http://www.opendatakit.org/xforms/entities">
  <h:head>
    <h:title>Add person</h:title>
    <model entities:entities-version="2024.1.0">
      <instance>
        <data id="add-person">
          <name/>
          <count/>
          <meta>
            <entity dataset="people" create="1" id=""><label/></entity>
          </meta>
        </data>
      </instance>
      <instance id="people" src="jr://file-csv/people.csv"/>
      <bind nodeset="/data/name" type="string" entities:saveto="full_name"/>
      <bind nodeset="/data/count" type="string"
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
  </h:body>
</h:html>
''';

Future<void> main() async {
  final repository = InMemEntitiesRepository()
    ..save('people', [
      NewEntity('a1', 'Shiv', properties: const [('full_name', 'Shiv Roy')]),
    ]);
  final config = withEntities(
    const DartRosaConfig(),
    entitiesRepository: () => repository,
  );

  final definition = await FormDefinition.parse(xform, config: config);
  final session = definition.createSession();
  final name = session.root.children.whereType<QuestionNode>().first;
  session.answer(name.index, const StringValue('Kendall Roy'));

  if (session.finalize() is FinalizeSuccess) {
    for (final entity in formEntities(session)!.entities) {
      _log('${entity.action.name} ${entity.label} ${entity.properties}');
    }
    saveFormEntities(session, repository);
    _log('people: ${repository.getCount('people')}'); // 2
  }
}

// ignore: avoid_print
void _log(Object? message) => print(message);
