// DartRosa tests (not ports) of FormEntryModel: index arithmetic in the
// linear and non-linear repeat structures, relevance/read-only/compound
// queries, the caption hierarchy and form metadata. JavaRosa has no tests
// for most of these; every expectation was captured from JavaRosa 6.0.0
// (jshell, FormEntryModel.incrementIndex / decrementIndex / getEvent /
// isIndex* and FormEntryController on the same form). Events are shown by
// their JavaRosa codes (4 question, 8 group, 16 repeat, 2 new-repeat
// prompt, 32 repeat juncture).
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:test/test.dart';

const modelForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
<h:head><h:title>Model</h:title><model>
<itext><translation lang="en" default=""><text id="x"><value>X</value></text></translation><translation lang="de"><text id="x"><value>Ix</value></text></translation></itext>
<instance><data id="model"><q1/><r><a>1</a></r><r><a>2</a></r><full><ro>fixed</ro><b/></full><q2/></data></instance>
<bind nodeset="/data/full/ro" readonly="true()"/>
<bind nodeset="/data/full/b" relevant="/data/q1 = 'yes'"/>
</model></h:head>
<h:body>
<input ref="/data/q1"><label ref="jr:itext('x')"/></input>
<repeat nodeset="/data/r"><input ref="/data/r/a"><label>A</label></input></repeat>
<group ref="/data/full" appearance="FULL"><label>Full</label>
<input ref="/data/full/ro"><label>RO</label></input>
<input ref="/data/full/b"><label>B</label></input>
</group>
<input ref="/data/q2"><label>Q2</label></input>
</h:body></h:html>
''';

const countForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
<h:head><h:title>Count</h:title><model>
<instance><data id="count"><n>2</n><r><a/></r></data></instance>
</model></h:head>
<h:body>
<input ref="/data/n"><label>N</label></input>
<group ref="/data/g"><repeat nodeset="/data/r" jr:count="/data/n"><input ref="/data/r/a"><label>A</label></input></repeat></group>
</h:body></h:html>
''';

Future<FormDef> parse(String xml) async {
  final form = await XFormParser().parse(xml);
  form.initialize(newInstance: true);
  return form;
}

String describe(FormEntryModel model, FormIndex index) {
  if (index.isEndOfFormIndex) return 'END';
  if (index.isBeginningOfFormIndex) return 'BEG';
  return '${index.toString().trim()}:${model.event(index).code}';
}

/// Every index from the beginning to the end of the form and back, with
/// relevance (R/N), read-only (ro) and compound element (C) going forward.
(String, String) walk(FormEntryModel model) {
  final forward = StringBuffer();
  var index = FormIndex.beginningOfForm();
  while (!index.isEndOfFormIndex) {
    index = model.incrementIndex(index);
    forward.write(describe(model, index));
    if (!index.isEndOfFormIndex) {
      forward
        ..write(':')
        ..write(model.isIndexRelevant(index) ? 'R' : 'N')
        ..write(model.isIndexReadonly(index) ? 'ro' : '')
        ..write(model.isIndexCompoundElement(index) ? 'C' : '');
    }
    forward.write(' | ');
  }
  final back = StringBuffer();
  while (!index.isBeginningOfFormIndex) {
    index = model.decrementIndex(index);
    back.write('${describe(model, index)} | ');
  }
  return ('$forward'.trim(), '$back'.trim());
}

void main() {
  late FormDef form;

  setUp(() async => form = await parse(modelForm));

  test(
    'linear walk visits every repeat instance and the new-repeat prompt',
    () {
      final model = FormEntryModel(form);
      expect(model.repeatStructure, RepeatStructure.linear);
      final (forward, back) = walk(model);
      expect(
        forward,
        '0,:4:R | 1_0,:16:R | 1_0, 0,:4:R | 1_1,:16:R | 1_1, 0,:4:R | '
        '1_2,:2:R | 2,:8:R | 2, 0,:4:RroC | 2, 1,:4:NC | 3,:4:R | END |',
      );
      expect(
        back,
        '3,:4 | 2, 1,:4 | 2, 0,:4 | 2,:8 | 1_2,:2 | 1_1, 0,:4 | 1_1,:16 | '
        '1_0, 0,:4 | 1_0,:16 | 0,:4 | BEG |',
      );
    },
  );

  test('non-linear walk stops at the repeat juncture', () {
    final model = FormEntryModel(
      form,
      repeatStructure: RepeatStructure.nonLinear,
    );
    expect(model.repeatStructure, RepeatStructure.nonLinear);
    final (forward, back) = walk(model);
    expect(
      forward,
      '0,:4:R | 1_-10,:32:R | 2,:8:R | 2, 0,:4:RroC | 2, 1,:4:NC | 3,:4:R | '
      'END |',
    );
    expect(back, '3,:4 | 2, 1,:4 | 2, 0,:4 | 2,:8 | 1_-10,:32 | 0,:4 | BEG |');
  });

  test('non-linear navigation into, out of and around instances', () {
    final model = FormEntryModel(
      form,
      repeatStructure: RepeatStructure.nonLinear,
    );
    final controller = FormEntryController(model)
      ..stepToNextEvent()
      ..stepToNextEvent();
    final juncture = model.formIndex;
    expect(describe(model, juncture), '1_-10,:32');
    expect(model.isIndexRelevant(), isTrue);
    expect(model.isIndexReadonly(), isFalse);

    final instance = controller.descendIntoRepeat(1);
    expect(describe(model, instance), '1_1,:16');
    final inc1 = model.incrementIndex(instance);
    expect(describe(model, inc1), '1_1, 0,:4');
    final inc2 = model.incrementIndex(inc1);
    expect(describe(model, inc2), '1_-10,:32');
    expect(describe(model, model.incrementIndex(inc2)), '2,:8');
    final dec1 = model.decrementIndex(inc1);
    expect(describe(model, dec1), '1_1,:16');
    final dec2 = model.decrementIndex(dec1);
    expect(describe(model, dec2), '1_-10,:32');
    expect(describe(model, model.decrementIndex(dec2)), '0,:4');
    expect(
      describe(model, model.incrementIndex(instance, descend: false)),
      '1_-10,:32',
    );

    controller.jumpToIndex(juncture);
    expect(describe(model, controller.descendIntoNewRepeat()), '1_2,:16');
    expect(form.numRepetitions(juncture), 3);

    controller
      ..jumpToIndex(juncture)
      ..deleteRepeatAt(0);
    expect(form.numRepetitions(juncture), 2);
    expect(
      form.mainInstance.root
          .getChild('r', 0)!
          .getChild('a', 0)!
          .value!
          .displayText,
      '2',
    );
    expect(model.captionPrompt(juncture).repetitionsText, [
      'null 1/2',
      'null 2/2',
    ]);
  });

  test('non-linear falls back to linear with jr:count repeats', () async {
    final model = FormEntryModel(
      await parse(countForm),
      repeatStructure: RepeatStructure.nonLinear,
    );
    expect(model.repeatStructure, RepeatStructure.linear);
  });

  test('compound containers are groups with appearance full', () {
    final model = FormEntryModel(form);
    final controller = FormEntryController(model);
    while (model.event() != FormEntryEvent.group) {
      controller.stepToNextEvent();
    }
    final group = model.formIndex;
    expect(model.isIndexCompoundContainer(), isTrue);
    expect(model.isIndexCompoundElement(), isFalse);
    expect(model.isIndexReadonly(group), isFalse);
    // Only relevant children are listed.
    expect(model.compoundIndices().map((i) => '$i'), ['2, 0, ']);
    expect(
      model.isIndexCompoundContainer(model.incrementIndex(group)),
      isFalse,
    );
  });

  test('the caption hierarchy lists enclosing groups and the question', () {
    final model = FormEntryModel(form);
    final controller = FormEntryController(model);
    while (model.event() != FormEntryEvent.group) {
      controller.stepToNextEvent();
    }
    controller.stepToNextEvent();
    final hierarchy = model.captionHierarchy();
    expect(hierarchy.map((c) => c.longText), ['Full', 'RO']);
    expect(hierarchy.map((c) => '${c.index}'), ['2, ', '2, 0, ']);
    expect(hierarchy.last, isA<FormEntryPrompt>());
    expect(hierarchy.first, isNot(isA<FormEntryPrompt>()));
  });

  test('form metadata and languages', () {
    final model = FormEntryModel(form);
    expect(model.formTitle, 'Model');
    expect(model.languages, ['en', 'de']);
    expect(model.language, 'en');
    expect(model.numQuestions, 5);
    model.language = 'de';
    expect(model.language, 'de');
    expect(FormEntryController(model).language, 'de');
    expect(
      model.questionPrompt(model.incrementIndex(model.formIndex)).longText,
      'Ix',
    );
    // The beginning of the form is read-only.
    expect(model.isIndexReadonly(FormIndex.beginningOfForm()), isTrue);
    expect(
      () => model.questionPrompt(FormIndex.beginningOfForm()),
      throwsStateError,
    );
  });
}
