// The code of docs/guides/save-and-resume-drafts.md, run as tests so the
// guide can't rot (doc_snippets.dart checks that its snippets are here).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance>
        <data id="visit" version="2">
          <name/><pregnant/><weeks/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/pregnant" type="string" saveIncomplete="true()"/>
      <bind nodeset="/data/weeks" type="int"
          relevant="/data/pregnant = 'yes'"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Name</label></input>
    <select1 ref="/data/pregnant"><label>Pregnant?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <input ref="/data/weeks"><label>Weeks</label></input>
  </h:body>
</h:html>
''';

void main() {
  test('save, close, resume and finalize', () async {
    final drafts = <String, String>{};
    var definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();
    final [name, pregnant, weeks] = session.root.children.cast<QuestionNode>();
    session.answer(name.index, const StringValue('Amina'));
    session.answer(pregnant.index, const SelectOneValue(Selection('yes')));
    session.answer(weeks.index, const IntegerValue(20));
    session.answer(pregnant.index, const SelectOneValue(Selection('no')));

    // Save when the person leaves the form or the app goes to the
    // background, and keep it with the form's id and version.
    drafts['visit-1'] = session.saveDraft();
    await session.close();

    // weeks is no longer relevant, but the draft keeps its value.
    expect(drafts['visit-1'], contains('<weeks>20</weeks>'));
    expect(drafts['visit-1'], contains('version="2"'));

    // Later, maybe after the app restarted: parse the form again and load
    // the draft into a new session.
    definition = await FormDefinition.parse(formXml);
    final resumed = definition.createSession(
      existingInstance: drafts['visit-1'],
    );

    final resumedName = resumed.root.children.first as QuestionNode;
    expect(resumedName.value, const StringValue('Amina'));

    final outbox = <Submission>[];
    switch (resumed.finalize()) {
      case FinalizeSuccess(:final submission):
        // Non-relevant answers are left out of the submission.
        outbox.add(submission); // to upload
        drafts.remove('visit-1');
      case FinalizeFailure(:final failure):
        // Show the question that needs attention.
        resumed.navigator.jumpTo(failure.index);
    }

    expect(outbox.single.xml, isNot(contains('<weeks>')));
    expect(outbox.single.instanceId, startsWith('uuid:'));
  });

  test('autosave on every change', () async {
    final drafts = <String, String>{};
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();

    // Save after every answer and every added or removed repeat
    // instance, so nothing is lost if the app is killed.
    final subscription = session.changes
        .where((change) => change.kind == 'answer' || change.kind == 'repeat')
        .listen((_) => drafts['visit-1'] = session.saveDraft());
    // ... and when the form is closed:
    await subscription.cancel();

    final again = session.changes
        .where((change) => change.kind == 'answer' || change.kind == 'repeat')
        .listen((_) => drafts['visit-1'] = session.saveDraft());
    final name = session.root.children.first as QuestionNode;
    session.answer(name.index, const StringValue('Ada'));
    expect(drafts['visit-1'], contains('<name>Ada</name>'));
    await again.cancel();
  });

  test('saveIncomplete questions ask for a draft', () async {
    final drafts = <String, String>{};
    final session = (await FormDefinition.parse(formXml)).createSession();
    final question = session.root.children[1] as QuestionNode;
    const value = SelectOneValue(Selection('yes'));

    // Questions with saveIncomplete="true()" (XLSForm's save_incomplete
    // column) ask the app to save a draft as soon as they are answered.
    final result = session.answer(question.index, value);
    if (result is AnswerAccepted && question.saveIncomplete) {
      drafts['visit-1'] = session.saveDraft();
    }

    expect(drafts['visit-1'], contains('<pregnant>yes</pregnant>'));
  });

  test('open a finalized submission for editing', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();
    final name = session.root.children.first as QuestionNode;
    session.answer(name.index, const StringValue('Ada'));
    final submission = (session.finalize() as FinalizeSuccess).submission;
    await session.close();

    // A finalized submission opens like a draft.
    final edit = definition.createSession(existingInstance: submission.xml);

    expect(
      (edit.root.children.first as QuestionNode).value,
      const StringValue('Ada'),
    );
  });
}
