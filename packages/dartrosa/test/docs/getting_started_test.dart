// The code of docs/GETTING_STARTED.md, run as tests so the guide can't rot.
// Every ```dart block of the guide must appear here (or in another doc
// test); doc_snippets.dart checks it.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

import 'doc_snippets.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household survey</h:title>
    <model>
      <itext>
        <translation lang="English" default="true()">
          <text id="name"><value>Your name</value></text>
          <text id="age"><value>Your age</value></text>
          <text id="consent"><value>Do you agree?</value></text>
        </translation>
        <translation lang="Français">
          <text id="name"><value>Votre nom</value></text>
          <text id="age"><value>Votre âge</value></text>
          <text id="consent"><value>Êtes-vous d'accord ?</value></text>
        </translation>
      </itext>
      <instance>
        <data id="household">
          <name/><age/><consent/>
          <member jr:template=""><member_name/></member>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 18"
          jr:constraintMsg="You must be an adult"/>
      <bind nodeset="/data/consent" type="select1"/>
      <bind nodeset="/data/member/member_name" type="string"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label ref="jr:itext('name')"/></input>
    <input ref="/data/age"><label ref="jr:itext('age')"/></input>
    <select1 ref="/data/consent">
      <label ref="jr:itext('consent')"/>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <group ref="/data/member">
      <label>Members</label>
      <repeat nodeset="/data/member">
        <input ref="/data/member/member_name"><label>Name</label></input>
      </repeat>
    </group>
  </h:body>
</h:html>
''';

// An outline of the form tree, one line per node.
List<String> outline(FormNode node, [String indent = '']) => [
  switch (node) {
    QuestionNode(:final label, :final value) =>
      '$indent${label.text}: ${value?.displayText ?? '-'}',
    RepeatNode(:final instances) =>
      '$indent[repeat, ${instances.length} instances]',
    RepeatInstanceNode(:final position) => '$indent[instance $position]',
    GroupNode(:final label) => '$indent${label.text}',
    RootNode(:final label) => '${label.text}',
  },
  if (node is ContainerNode)
    for (final child in node.visibleChildren) ...outline(child, '$indent  '),
  if (node is RepeatNode)
    for (final instance in node.instances) ...outline(instance, '$indent  '),
];

// Stands in for the app's upload.
final uploaded = <String>[];
void upload(String xml, String? instanceId, List<String> attachments) =>
    uploaded.add(xml);

Future<FormDefinition> parseForm() async {
  final definition = await FormDefinition.parse(
    formXml,
    config: DartRosaConfig(
      // Reads jr://file/... form media and secondary instances.
      resolver: MapResourceResolver({
        'jr://file/towns.csv': Uint8List.fromList(
          utf8.encode('name,label\nnbo,Nairobi\n'),
        ),
      }),
      // Device properties for jr:preload="property" and property().
      properties: MapPropertyManager({'deviceid': 'my-app:1234'}),
    ),
  );
  return definition;
}

void main() {
  expectSnippetsTested('docs/GETTING_STARTED.md');

  test('parse and start a session', () async {
    final definition = await parseForm();
    final title = definition.title; // 'Household survey'
    final languages = definition.languages; // ['English', 'Français']
    final session = definition.createSession();
    expect(title, 'Household survey');
    expect(languages, ['English', 'Français']);
    expect(session.language, 'English');
    expect(outline(session.root), [
      'Household survey',
      '  Your name: -',
      '  Your age: -',
      '  Do you agree?: -',
      '  [repeat, 0 instances]',
    ]);
  });

  test('walk with the navigator', () async {
    final session = (await parseForm()).createSession();
    final labels = <String?>[];
    final nav = session.navigator;
    for (
      var event = nav.next();
      event != FormEntryEvent.endOfForm;
      event = nav.next()
    ) {
      switch (event) {
        case FormEntryEvent.question:
          final question = nav.current as QuestionNode;
          labels.add(question.label.text);
        case FormEntryEvent.promptNewRepeat:
          // "Add another member?": nav.addRepeatAndEnter() adds one; next()
          // declines.
          break;
        default:
          // Groups and repeat instances.
          break;
      }
    }
    expect(labels, ['Your name', 'Your age', 'Do you agree?']);
  });

  test('answer questions', () async {
    final session = (await parseForm()).createSession();
    final changed = <String>[];
    session.changes.listen((change) => changed.add(change.kind));

    final age = session.root.children[1] as QuestionNode;
    final result = session.answer(age.index, const IntegerValue(16));
    final message = switch (result) {
      AnswerAccepted() => 'Saved',
      AnswerRequired(:final message) => message ?? 'Sorry, this is required',
      AnswerConstraintViolated(:final message) => message ?? 'Invalid answer',
      AnswerRejected(:final message) => message, // wrong type, unknown choice
    };
    expect(message, 'You must be an adult');

    // Text is read as the question's type, as Collect's widgets do.
    session.answer(age.index, const UncastValue('42')); // AnswerAccepted
    session.answer(age.index, const UncastValue('forty')); // AnswerRejected

    final consent = session.root.children[2] as QuestionNode;
    session.answer(consent.index, const SelectOneValue(Selection('yes')));
    final choices = [for (final c in consent.choices) c.value]; // yes, no

    // A required question can't be cleared...
    final name = session.root.children[0] as QuestionNode;
    final cleared = session.answer(name.index, null); // AnswerRequired
    // ...unless validation is skipped (as when leaving a draft).
    session.answer(name.index, null, validate: false); // AnswerAccepted

    expect(age.value, const IntegerValue(42));
    expect(
      session.answer(age.index, const UncastValue('forty')),
      isA<AnswerRejected>(),
    );
    expect(consent.displayValue, 'Yes');
    expect(choices, ['yes', 'no']);
    expect(cleared, isA<AnswerRequired>());
    expect(changed, contains('answer'));
  });

  test('repeats and languages', () async {
    final session = (await parseForm()).createSession();

    // pyxform wraps repeats in a group with the same ref; JavaRosa (and
    // DartRosa) merge the two into the repeat.
    final members = session.root.children[3] as RepeatNode;
    final first = session.addRepeatInstance(members.index);
    final instance = session.nodeAt(first) as RepeatInstanceNode;
    final memberName = instance.children.single as QuestionNode;
    session.answer(memberName.index, const StringValue('Amina'));
    final count = members.instances.length; // 1
    session.removeRepeatInstance(first);

    expect(count, 1);
    expect(members.instances, isEmpty);

    session.language = 'Français';
    final label = session.root.children[0].label.text; // 'Votre nom'
    expect(label, 'Votre nom');
  });

  test('save a draft, resume and finalize', () async {
    final definition = await parseForm();
    final session = definition.createSession();
    final name = session.root.children[0] as QuestionNode;
    session.answer(name.index, const StringValue('Amina'));

    final draft = session.saveDraft(); // the instance XML, store it
    await session.close();

    // Later (a definition backs one session at a time):
    final resumed = definition.createSession(existingInstance: draft);

    switch (resumed.finalize()) {
      case FinalizeSuccess(:final submission):
        upload(submission.xml, submission.instanceId, submission.attachments);
      case FinalizeFailure(:final failure):
        // Show the first invalid question.
        resumed.navigator.jumpTo(failure.index);
    }

    expect(
      (resumed.root.children[0] as QuestionNode).value?.displayText,
      'Amina',
    );
    expect(uploaded.single, contains('<name>Amina</name>'));
    expect(uploaded.single, contains('<instanceID>uuid:'));
  });

  test('finalize reports the first invalid question', () async {
    final session = (await parseForm()).createSession();
    final result = session.finalize();
    expect(result, isA<FinalizeFailure>());
    final failure = (result as FinalizeFailure).failure;
    expect(failure.index.reference.toString(), '/data/name[1]');
    expect(failure.result, isA<AnswerRequired>());
  });
}
