// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Submission.attachments lists the files answered to binary questions.
import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const _form = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Media</h:title>
    <model>
      <instance>
        <data id="media">
          <photo/><show/><hidden/><note/>
          <r jr:template=""><clip/></r>
          <again/>
        </data>
      </instance>
      <bind nodeset="/data/photo" type="binary"/>
      <bind nodeset="/data/show" type="string"/>
      <bind nodeset="/data/hidden" type="binary" relevant="/data/show = 'yes'"/>
      <bind nodeset="/data/note" type="string"/>
      <bind nodeset="/data/r/clip" type="binary"/>
      <bind nodeset="/data/again" type="binary"/>
    </model>
  </h:head>
  <h:body>
    <upload ref="/data/photo" mediatype="image/*"><label>Photo</label></upload>
    <input ref="/data/show"><label>Show</label></input>
    <upload ref="/data/hidden" mediatype="image/*"><label>Hidden</label></upload>
    <input ref="/data/note"><label>Note</label></input>
    <repeat nodeset="/data/r">
      <upload ref="/data/r/clip" mediatype="audio/*"><label>Clip</label></upload>
    </repeat>
    <upload ref="/data/again" mediatype="image/*"><label>Again</label></upload>
  </h:body>
</h:html>''';

/// Every node under [node], depth first.
Iterable<FormNode> _descendants(FormNode node) sync* {
  final children = switch (node) {
    ContainerNode(:final children) => children,
    RepeatNode(:final instances) => instances,
    _ => const <FormNode>[],
  };
  for (final child in children) {
    yield child;
    yield* _descendants(child);
  }
}

void main() {
  late FormDefinition definition;
  late FormSession session;

  FormIndex indexOf(String ref) {
    for (final node in _descendants(session.root)) {
      if (node case QuestionNode(
        :final index,
      ) when index.reference.toString() == ref) {
        return index;
      }
    }
    throw StateError('no question $ref');
  }

  Submission finalize() => (session.finalize() as FinalizeSuccess).submission;

  setUp(() async {
    definition = await FormDefinition.parse(_form);
    session = definition.createSession();
  });

  test('an image answered with a file name', () {
    session.answer(indexOf('/data/photo[1]'), const UncastValue('photo.jpg'));
    expect(finalize().attachments, ['photo.jpg']);
  });

  test('none without binary answers', () {
    session.answer(indexOf('/data/note[1]'), const StringValue('photo.jpg'));
    expect(finalize().attachments, isEmpty);
  });

  test('non-relevant answers are left out, as in the XML', () {
    session
      ..answer(indexOf('/data/show[1]'), const StringValue('yes'))
      ..answer(indexOf('/data/hidden[1]'), const StringValue('hidden.jpg'))
      ..answer(indexOf('/data/show[1]'), const StringValue('no'));
    final submission = finalize();
    expect(submission.xml, isNot(contains('hidden.jpg')));
    expect(submission.attachments, isEmpty);
  });

  test('document order, repeats included, without duplicates', () {
    final repeat = _descendants(session.root).whereType<RepeatNode>().single;
    session.addRepeatInstance(repeat.index);
    session.addRepeatInstance(repeat.index);
    session
      ..answer(indexOf('/data/again[1]'), const StringValue('a.jpg'))
      ..answer(indexOf('/data/r[1]/clip[1]'), const StringValue('b.m4a'))
      ..answer(indexOf('/data/r[2]/clip[1]'), const StringValue('c.m4a'))
      ..answer(indexOf('/data/photo[1]'), const StringValue('a.jpg'));
    expect(finalize().attachments, ['a.jpg', 'b.m4a', 'c.m4a']);
  });

  test('answers of a resumed draft', () {
    session.answer(indexOf('/data/photo[1]'), const StringValue('photo.jpg'));
    final draft = session.saveDraft();
    session = definition.createSession(existingInstance: draft);
    expect(finalize().attachments, ['photo.jpg']);
  });
}
