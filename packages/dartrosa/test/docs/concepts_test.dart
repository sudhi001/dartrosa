// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of docs/CONCEPTS.md, run as tests so the page can't rot
// (doc_snippets.dart checks that its snippets are here).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household visit</h:title>
    <model>
      <itext>
        <translation lang="English" default="true()">
          <text id="members"><value>How many people live here?</value></text>
        </translation>
        <translation lang="Kiswahili">
          <text id="members"><value>Watu wangapi wanaishi hapa?</value></text>
        </translation>
      </itext>
      <instance>
        <data id="household_visit" version="1">
          <head_name/><members/><has_water/><water_source/>
          <person jr:template=""><age/></person>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/head_name" type="string" required="true()"/>
      <bind nodeset="/data/members" type="int" required="true()"
          constraint=". &gt; 0 and . &lt; 30"
          jr:constraintMsg="Between 1 and 29"/>
      <bind nodeset="/data/has_water" type="string"/>
      <bind nodeset="/data/water_source" type="string"
          relevant="/data/has_water = 'yes'"/>
      <bind nodeset="/data/person/age" type="int"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/head_name"><label>Name of the household head</label></input>
    <input ref="/data/members"><label ref="jr:itext('members')"/></input>
    <select1 ref="/data/has_water"><label>Drinking water?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <input ref="/data/water_source"><label>Where from?</label></input>
    <group ref="/data/person"><label>People</label>
      <repeat nodeset="/data/person">
        <input ref="/data/person/age"><label>Age</label></input>
      </repeat>
    </group>
  </h:body>
</h:html>
''';

void main() {
  test('definition and session', () async {
    // Parse once per form version: the questions, rules and translations.
    final definition = await FormDefinition.parse(formXml);
    // One filling of the form (one household): the answers and their state.
    final session = definition.createSession(language: 'English');

    expect(definition.languages, ['English', 'Kiswahili']);
    expect(session.root.children, hasLength(5));
    expect(session.language, 'English');
  });

  test('nodes, rules and answers', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();

    final [_, members, water, source, _] = session.root.children;
    final result = session.answer(members.index, const IntegerValue(40));
    // AnswerConstraintViolated('Between 1 and 29'): nothing was saved.
    session.answer(water.index, const SelectOneValue(Selection('no')));
    // water_source is no longer relevant: hidden, and left out of the
    // submission.
    final shown = session.root.visibleChildren.contains(source); // false

    expect(result, isA<AnswerConstraintViolated>());
    expect((result as AnswerConstraintViolated).message, 'Between 1 and 29');
    expect((members as QuestionNode).value, isNull);
    expect(shown, isFalse);
    expect(source.isRelevant, isFalse);
    expect(members.isRequired, isTrue);
  });

  test('changes', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();
    final log = <String>[];
    final water = session.root.children[2] as QuestionNode;

    final subscription = session.changes.listen((change) {
      // change.kind: answer, value (a calculation), condition (relevance,
      // required, read-only), repeat or language; change.refs: the nodes.
      log.add('${change.kind} ${change.refs.join(', ')}');
    });
    session.answer(water.index, const SelectOneValue(Selection('yes')));
    await subscription.cancel();

    expect(log, contains('answer /data/has_water[1]'));
    expect(log.any((l) => l.startsWith('condition')), isTrue);
  });

  test('repeats and languages', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();

    final people = session.root.children[4] as RepeatNode;
    final first = session.addRepeatInstance(people.index);
    final person = session.nodeAt(first) as RepeatInstanceNode;
    final age = person.children.single as QuestionNode;
    session.answer(age.index, const UncastValue('34')); // read as an int

    session.language = 'Kiswahili';
    final label = session.root.children[1].label.text;
    // 'Watu wangapi wanaishi hapa?'

    expect(age.value, const IntegerValue(34));
    expect(label, 'Watu wangapi wanaishi hapa?');
    expect(people.instances, hasLength(1));
  });
}
