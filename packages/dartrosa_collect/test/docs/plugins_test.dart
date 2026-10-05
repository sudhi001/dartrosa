// The Collect-packages code of docs/PLUGINS.md, run as a test so the guide
// can't rot (packages/dartrosa/test/docs checks that the guide's snippets
// are here or there).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Collect</h:title>
    <model>
      <instance>
        <data id="collect"><person/><size/><previous/></data>
      </instance>
      <instance id="last" src="jr://instance/last-saved"/>
      <bind nodeset="/data/person" type="string"
          calculate="pulldata('people', 'label', 'name', 'p1')"/>
      <bind nodeset="/data/size" type="string"
          calculate="pulldata('sizes', 'size', 'name', 'big')"/>
      <bind nodeset="/data/previous" type="string"
          calculate="instance('last')/data/size"/>
    </model>
  </h:head>
  <h:body><input ref="/data/person"><label>Person</label></input></h:body>
</h:html>
''';

void main() {
  test('collectFormConfig + ExternalDataPlugin + withEntities', () async {
    // The form's media folder.
    final media = MapResourceResolver({
      'jr://file/sizes.csv': Uint8List.fromList(
        utf8.encode('name,label,size\nbig,Big,10\n'),
      ),
    });
    // Entity lists downloaded from the server (implement
    // EntitiesRepository on your database).
    final entities = InMemEntitiesRepository()
      ..save('people', [NewEntity('p1', 'Ada')]);
    final lastSaved = LastSaved(InMemoryLastSavedStore(), 'collect-v1');

    final config = withEntities(
      collectFormConfig(
        media: media,
        lastSaved: lastSaved, // jr://instance/last-saved
        plugins: [
          // pulldata() and search() over the form's CSV media.
          ExternalDataPlugin(listMedia: (form) => ['sizes.csv']),
        ],
      ),
      // Entity lists become secondary instances and answer pulldata()
      // before CSV media.
      entitiesRepository: () => entities,
    );

    final definition = await FormDefinition.parse(formXml, config: config);
    final session = definition.createSession();
    // ... fill the form, then:
    if (session.finalize() case FinalizeSuccess(:final submission)) {
      saveFormEntities(session, entities); // entities the form created
      await lastSaved.instanceSaved(session); // for the next instance
      expect(submission.xml, contains('<person>Ada</person>'));
      expect(submission.xml, contains('<size>10</size>'));
    }

    // The next instance reads the previous one through last-saved.
    final next = (await FormDefinition.parse(
      formXml,
      config: config,
    )).createSession();
    expect(next.saveDraft(), contains('<previous>10</previous>'));
  });
}
