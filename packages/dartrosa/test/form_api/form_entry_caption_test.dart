// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports): repeat captions of FormEntryCaption. JavaRosa
// has no tests for these; every expectation was captured from JavaRosa
// 6.0.0 (jshell, FormEntryCaption.getRepeatText / getRepetitionText /
// getRepetitionsText / register) on the same form.
import 'package:dartrosa/src/form_api/form_entry_caption.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const captionsForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
<h:head><h:title>Caps</h:title><model>
<itext>
<translation lang="en"><text id="who"><value>Who</value></text></translation>
<translation lang="fr"><text id="who"><value>Qui</value></text></translation>
</itext>
<instance><data id="caps"><who>Ann</who><r jr:template=""><q/></r><plain jr:template=""><x/></plain></data></instance>
</model></h:head>
<h:body>
<input ref="/data/who"><label ref="jr:itext('who')"/></input>
<group ref="/data/r"><label>Person</label>
<repeat nodeset="/data/r">
<jr:mainHeader>Main <output value="\$name"/> of <output value="\$n"/></jr:mainHeader>
<jr:addCaption>Add a <output value="\$name"/> for <output value="/data/who"/></jr:addCaption>
<jr:delCaption>Del <output value="\$name"/></jr:delCaption>
<jr:doneCaption>Finished <output value="\$n"/></jr:doneCaption>
<jr:delHeader>Remove which?</jr:delHeader>
<jr:entryHeader>Entry <output value="\$i"/> of <output value="\$n"/> new=<output value="\$new"/></jr:entryHeader>
<input ref="/data/r/q"><label>Q</label></input>
</repeat></group>
<group ref="/data/plain"><label>Thing</label>
<repeat nodeset="/data/plain">
<jr:chooseCaption>Pick <output value="\$i"/></jr:chooseCaption>
<input ref="/data/plain/x"><label>X</label></input>
</repeat></group>
</h:body></h:html>
''';

const repeatKeys = [
  'mainheader',
  'add',
  'add-empty',
  'del',
  'done',
  'done-empty',
  'delheader',
];

Map<String, String?> repeatTexts(FormEntryCaption caption) => {
  for (final key in repeatKeys) key: caption.repeatText(key),
};

class RecordingWidget implements QuestionWidget {
  final changes = <int>[];

  @override
  void refreshWidget(int changeFlags) => changes.add(changeFlags);
}

void main() {
  late Scenario scenario;

  setUp(() async {
    scenario = await Scenario.fromXml(captionsForm);
    scenario.language = 'en';
  });

  FormEntryCaption captionAt(String xPath) =>
      scenario.formEntryController.model.captionPrompt(scenario.indexOf(xPath));

  test('repeat texts use the jr: captions with name, n and outputs', () {
    scenario.next(2);
    var caption = scenario.formEntryCaptionAtIndex;
    expect(caption.repeats, isTrue);
    expect(repeatTexts(caption), {
      'mainheader': 'Main Person of 0',
      'add': 'Add a Person for Ann',
      // add-empty and done-empty fall back to add and done.
      'add-empty': 'Add a Person for Ann',
      'del': 'Del Person',
      'done': 'Finished 0',
      'done-empty': 'Finished 0',
      'delheader': 'Remove which?',
    });
    expect(caption.numRepetitions, 0);
    expect(caption.repetitionsText, isEmpty);
    expect(caption.repetitionText(newRepeat: true), 'Entry 1 of 0 new=true');

    scenario
      ..createNewRepeatHere()
      ..createNewRepeat('/data/r');
    caption = captionAt('/data/r[2]');
    expect(caption.multiplicity, 1);
    expect(caption.numRepetitions, 2);
    expect(caption.repeatText('mainheader'), 'Main Person of 2');
    expect(caption.repeatText('done'), 'Finished 2');
    expect(caption.repetitionText(newRepeat: false), 'Entry 2 of 2 new=false');
    expect(caption.repetitionsText, [
      'Entry 1 of 2 new=false',
      'Entry 2 of 2 new=false',
    ]);
  });

  test('repeat texts default to English without jr: captions', () {
    scenario.next(3);
    final caption = scenario.formEntryCaptionAtIndex;
    expect(repeatTexts(caption), {
      'mainheader': 'Thing',
      'add': 'Add another Thing',
      'add-empty': 'None - Add Thing',
      'del': 'Delete Thing',
      'done': 'Done',
      'done-empty': 'Skip',
      'delheader': 'Delete which Thing?',
    });
    // Without entryHeader, the header is "<label> <i>/<n>".
    expect(caption.repetitionText(newRepeat: true), 'Thing 1/0');
  });

  test('repetitionsText prefers chooseCaption', () {
    scenario
      ..createNewRepeat('/data/plain')
      ..createNewRepeat('/data/plain');
    expect(captionAt('/data/plain[2]').repetitionsText, ['Pick 1', 'Pick 2']);
  });

  test('repeat captions are not available for questions', () {
    final caption = captionAt('/data/who');
    expect(caption.repeats, isFalse);
    expect(caption.multiplicity, -1);
    expect(caption.repetitionText(newRepeat: true), isNull);
    // JavaRosa fails with a ClassCastException.
    expect(() => caption.repeatText('add'), throwsStateError);
    expect(() => caption.repetitionsText, throwsStateError);
  });

  test('a registered caption is told about language changes', () {
    final caption = captionAt('/data/who');
    final widget = RecordingWidget();
    caption.register(widget);
    expect(caption.viewWidget, same(widget));

    scenario.language = 'fr';
    expect(widget.changes, [ElementChange.locale]);
    expect(caption.longText, 'Qui');

    caption.unregister();
    expect(caption.viewWidget, isNull);
    scenario.language = 'en';
    expect(widget.changes, [ElementChange.locale]);
  });

  test('a registered prompt is also told about its value', () {
    final prompt = scenario.formEntryController.model.questionPrompt(
      scenario.indexOf('/data/who'),
    );
    final widget = RecordingWidget();
    prompt.register(widget);
    scenario.answer('/data/who', 'Bea');
    scenario.language = 'fr';
    expect(widget.changes, [ElementChange.data, ElementChange.locale]);

    prompt.unregister();
    scenario.answer('/data/who', 'Cy');
    expect(widget.changes, hasLength(2));
  });
}
