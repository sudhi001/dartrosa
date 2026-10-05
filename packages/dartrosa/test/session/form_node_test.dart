// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports) of the session facade's nodes (FormNode and
// subclasses) and the FormSession / FormNavigator operations not covered
// by form_session_test. The facade is DartRosa's own API; the texts and
// states it reports come from FormEntryCaption / FormEntryPrompt /
// FormEntryModel and follow JavaRosa (label forms, repeat headers,
// read-only, relevance, constraint and bind attributes).
import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms">
<h:head><h:title>Nodes</h:title><model>
<itext>
<translation lang="en"><text id="age"><value>Age</value><value form="short">Yrs</value><value form="image">jr://images/age.png</value><value form="big-image">jr://images/age-big.png</value><value form="audio">jr://audio/age.mp3</value><value form="video">jr://video/age.mp4</value><value form="guidance">Ask politely</value></text>
<text id="c-y"><value>Yes</value><value form="image">jr://images/yes.png</value></text>
</translation>
<translation lang="fr"><text id="age"><value>Âge</value></text><text id="c-y"><value>Oui</value></text></translation>
</itext>
<instance><data id="nodes"><age/><ok/><note/><g><x/></g><kid jr:template=""><kname/></kid><orx:meta><orx:instanceID>uuid:123</orx:instanceID></orx:meta></data></instance>
<bind nodeset="/data/age" type="int" required="true()" jr:requiredMsg="Age please" constraint=". &lt; 150" jr:constraintMsg="Too old"/>
<bind nodeset="/data/note" readonly="true()"/>
<bind nodeset="/data/g" relevant="/data/age &gt; 10"/>
<bind nodeset="/data/orx:meta/orx:instanceID" type="string"/>
</model></h:head>
<h:body>
<input ref="/data/age"><label ref="jr:itext('age')"/><hint>In years</hint></input>
<select1 ref="/data/ok" appearance="minimal" odk:extra="1"><label>OK?</label>
<item><label ref="jr:itext('c-y')"/><value>y</value></item>
<item><label>No</label><value>n</value></item>
</select1>
<input ref="/data/note"><label>Just a note</label></input>
<group ref="/data/g" appearance="Field-List"><label>Group</label><input ref="/data/g/x"><label>X</label></input></group>
<group ref="/data/kid"><label>Kid</label><repeat nodeset="/data/kid"><input ref="/data/kid/kname"><label>Kid name</label></input></repeat></group>
</h:body></h:html>
''';

void main() {
  late FormSession session;

  setUp(() async {
    final definition = await FormDefinition.parse(formXml);
    expect(definition.languages, ['en', 'fr']);
    session = definition.createSession(language: 'en');
  });

  QuestionNode question(int i) => session.root.children[i] as QuestionNode;

  test('label forms', () {
    final label = question(0).label;
    expect(label.text, 'Age');
    expect('$label', 'Age');
    expect(label.short, 'Yrs');
    expect(label.image, 'jr://images/age.png');
    expect(label.bigImage, 'jr://images/age-big.png');
    expect(label.audio, 'jr://audio/age.mp3');
    expect(label.video, 'jr://video/age.mp4');
    expect(label.guidance, 'Ask politely');
    expect(question(1).label.image, isNull);
    expect('${const LocalizedText()}', '');
  });

  test('changing the language is reported and relabels nodes', () async {
    final changes = <FormChange>[];
    session.changes.listen(changes.add);
    session.language = 'fr';
    expect(session.language, 'fr');
    expect(question(0).label.text, 'Âge');
    expect(changes.single.kind, 'language');
    expect('${changes.single}', 'FormChange(language, [])');
    await session.close();
  });

  test('a definition can start a session in a language', () {
    final fr = session.definition.createSession(language: 'fr');
    expect(fr.language, 'fr');
  });

  test('guidance hints come from the hint itext', () async {
    final definition = await FormDefinition.parse(
      formXml
          .replaceFirst(
            '<text id="c-y">',
            '<text id="h"><value>Hint</value>'
                '<value form="guidance">Probe gently</value></text>'
                '<text id="c-y">',
          )
          .replaceFirst(
            '<hint>In years</hint>',
            '<hint ref="jr:itext(\'h\')"/>',
          ),
    );
    final age =
        definition.createSession(language: 'en').root.children[0]
            as QuestionNode;
    expect(age.hint, 'Hint');
    expect(age.guidanceHint, 'Probe gently');
    expect(question(0).guidanceHint, isNull);
  });

  test('question details', () {
    final age = question(0);
    expect(age.question.textId, 'age');
    expect(age.controlType, ControlType.input);
    expect(age.hint, 'In years');
    expect(age.requiredMessage, 'Age please');
    expect(age.constraintMessage, 'Too old');
    expect(age.isNote, isFalse);
    expect(age.isReadonly, isFalse);
    expect(age.displayValue, isNull);
    session.answer(age.index, const IntegerValue(42));
    expect(question(0).displayValue, '42');
    expect(age.ancestors, isEmpty);
    expect(session.root.ancestors, isEmpty);
    expect(session.root.isReadonly, isFalse);
    expect(session.root.label.text, 'Nodes');
  });

  test('select choices, media and attributes', () {
    final ok = question(1);
    expect(ok.appearance, 'minimal');
    final [yes, no] = ok.choices;
    expect(ok.choiceLabel(yes), 'Yes');
    expect(ok.choiceLabel(no), 'No');
    expect(ok.choiceMedia(yes, 'image'), 'jr://images/yes.png');
    expect(ok.choiceMedia(no, 'image'), isNull);
    expect(ok.attributes.map((a) => '${a.name}=${a.attributeValue}'), [
      'extra=1',
    ]);
    expect(ok.bindAttributes, isEmpty);
    session.answer(ok.index, SelectOneValue(Selection.ofChoice(yes)));
    expect(question(1).displayValue, 'Yes');
  });

  test('read-only text inputs are notes', () {
    final note = question(2);
    expect(note.isReadonly, isTrue);
    expect(note.isNote, isTrue);
  });

  test('groups, field lists and ancestors', () {
    final group = session.root.children[3] as GroupNode;
    expect(group.isFieldList, isTrue);
    expect(group.isRelevant, isFalse);
    session.answer(question(0).index, const IntegerValue(20));
    expect(group.isRelevant, isTrue);
    final x = group.children.single as QuestionNode;
    expect(x.label.text, 'X');
    expect(x.ancestors.map((n) => n.label.text), ['Group']);
    expect(session.nodeAt(group.index), isA<GroupNode>());
  });

  test('repeat instances have headers', () {
    // As in JavaRosa, a group around a repeat with the same ref merges
    // into the repeat (which takes the group's label).
    final repeat = session.root.children[4] as RepeatNode;
    expect(repeat.repeat.isRepeat, isTrue);
    expect(repeat.instances, isEmpty);
    session
      ..addRepeatInstance(repeat.index)
      ..addRepeatInstance(repeat.index);
    final [first, second] = repeat.instances;
    expect(second.position, 1);
    expect(first.header, 'Kid 1/2');
    expect(second.header, 'Kid 2/2');
    final kname = second.children.single;
    expect(kname.ancestors.map((n) => n.runtimeType), [RepeatInstanceNode]);
    expect(session.nodeAt(second.index), isA<RepeatInstanceNode>());
  });

  test('answers can skip validation', () {
    final age = question(0);
    expect(
      session.answer(age.index, const IntegerValue(500), validate: false),
      isA<AnswerAccepted>(),
    );
    expect(question(0).value, const IntegerValue(500));
    final result = session.finalize();
    final failure = (result as FinalizeFailure).failure;
    expect((failure.result as AnswerConstraintViolated).message, 'Too old');
  });

  test('required messages and the instance ID', () {
    final result = session.finalize() as FinalizeFailure;
    expect((result.failure.result as AnswerRequired).message, 'Age please');
    session.answer(question(0).index, const IntegerValue(5));
    final success = session.finalize() as FinalizeSuccess;
    expect(success.submission.instanceId, 'uuid:123');
  });

  test('navigator jumps', () {
    final nav = session.navigator;
    expect(nav.jumpToEnd(), FormEntryEvent.endOfForm);
    expect(nav.jumpToBeginning(), FormEntryEvent.beginningOfForm);
    expect(nav.current, isA<RootNode>());
    expect(nav.jumpTo(question(2).index), FormEntryEvent.question);
    expect((nav.current as QuestionNode).label.text, 'Just a note');
    final repeat = session.root.children[4] as RepeatNode;
    session.addRepeatInstance(repeat.index);
    nav
      ..jumpTo(repeat.instances.single.children.single.index)
      ..jumpToNewRepeatPrompt();
    expect(nav.event, FormEntryEvent.promptNewRepeat);
    session.extras['k'] = 1;
    expect(session.extras, {'k': 1});
  });
}
