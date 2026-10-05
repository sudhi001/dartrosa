// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XFormParserTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 XFormParserTest.
import 'package:dartrosa/src/codec/form_def_codec.dart';
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/actions/actions.dart';
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xform/instance_structure.dart';
import 'package:dartrosa/src/xform/kdom.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void assertNoParseErrors(FormDef form) => expect(form.parseErrors, isEmpty);

TreeElement? findDepthFirst(TreeElement parent, String name) {
  for (final e in parent.children) {
    if (e.name == name) return e;
    if (e.numChildren != 0) {
      final found = findDepthFirst(e, name);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  test('parses simple form', () async {
    expect((await parseForm('simple-form.xml')).title, 'Simple Form');
  });

  test('parses form2', () async {
    final form = await parseForm('form2.xml');
    expect(form.title, 'My Survey');
    expect(form.children, hasLength(3));
    expect(form.childAt(0)!.labelInnerText, 'What is your first name?');
  });

  test('spaces between outputs are respected', () async {
    final form = await parseXml(
      html(
        head([
          title(),
          model([
            mainInstance([
              t('data id="spaces-outputs"', [
                t('first_name'),
                t('last_name'),
                t('question'),
              ]),
            ]),
            bind('/data/question')..type('string'),
          ]),
        ]),
        body([
          input('/data/question', [
            tText(
              'label',
              'Full name: <output value=" ../first_name "/>\u00A0'
                  '<output value=" ../last_name "/>',
            ),
          ]),
        ]),
      ).asXml(),
    );
    expect(form.childAt(0)!.labelInnerText, 'Full name: \${0}\u00A0\${1}');
  });

  test('parses secondary instance form', () async {
    expect(
      (await parseForm('secondary-instance.xml')).title,
      'Form with secondary instance',
    );
  });

  test('parses secondary instance form 2', () async {
    expect(
      (await parseForm('internal_select_10.xml')).title,
      'internal select 10',
    );
  });

  test('parses last-saved instance with null src', () async {
    final form = await parseForm('last-saved-blank.xml');
    expect(form.title, 'Form with last-saved instance (blank)');
    expect(form.nonMainInstance('last-saved')!.root!.numChildren, 0);
  });

  test('parses last-saved instance with filled form', () async {
    final form = await parseForm(
      'last-saved-blank.xml',
      lastSavedSrc: 'jr://file/last-saved-filled.xml',
    );
    expect(form.title, 'Form with last-saved instance (blank)');
    final item = form
        .nonMainInstance('last-saved')!
        .root!
        .getChild('head', 0)!
        .getChild('model', 0)!
        .getChild('instance', 0)!
        .getChild('data', 0)!
        .getChild('item', 0)!;
    expect(item.value!.displayText, 'Foo');
  });

  // JavaRosa's Externalizable round trips, as FormDefCodec round trips.
  Future<FormDef> serializeAndDeserialize(FormDef form) =>
      FormDefCodec.decode(FormDefCodec.encode(form));

  test('multiple instances form saves and restores', () async {
    final originalFormDef = await parseForm(
      'Simpler_Cascading_Select_Form.xml',
    );

    final deserializedFormDef = await serializeAndDeserialize(originalFormDef);

    expect(originalFormDef.title, deserializedFormDef.title);
  });

  // ensure serializing and deserializing a range form is done without errors
  // see https://github.com/getodk/javarosa/issues/245 why this is needed
  test('range form saves and restores', () async {
    final originalFormDef = await parseForm('range-form.xml');

    final deserializedFormDef = await serializeAndDeserialize(originalFormDef);

    expect(originalFormDef.title, deserializedFormDef.title);

    final question = deserializedFormDef.childAt(0)! as RangeQuestion;
    expect(question.dynamicChoices, isNull);
  });

  test('itemset range form saves and restores', () async {
    final originalFormDef = await parseForm('range-form-itemset.xml');

    final deserializedFormDef = await serializeAndDeserialize(originalFormDef);

    expect(originalFormDef.title, deserializedFormDef.title);

    final question = deserializedFormDef.childAt(0)! as RangeQuestion;
    expect(question.dynamicChoices, isNotNull);
  });

  test('parses rank form', () async {
    final form = await parseForm('rank-form.xml');
    expect(form.title, 'Rank Form');
    expect(form.children, hasLength(1));
    expect((form.childAt(0)! as QuestionDef).controlType, ControlType.rank);
    assertNoParseErrors(form);
  });

  test('parses range form', () async {
    final question =
        (await parseForm('range-form.xml')).childAt(0)! as RangeQuestion;
    expect(question.controlType, ControlType.range);
    expect(double.parse(question.rangeStart!), -2.0);
    expect(double.parse(question.rangeEnd!), 2.0);
    expect(double.parse(question.rangeStep!), 0.5);
  });

  test('parses range form with itemset', () async {
    final form = await parseForm('range-form-itemset.xml');
    final question = form.childAt(0)! as RangeQuestion;
    expect(question.controlType, ControlType.range);
    expect(double.parse(question.rangeStart!), -2.0);
    expect(double.parse(question.rangeEnd!), 2.0);
    expect(double.parse(question.rangeStep!), 0.5);
    expect(double.parse(question.tickInterval!), 2.0);
    expect(double.parse(question.placeholder!), 1.0);
    expect(question.dynamicChoices, isNotNull);

    final formEntryModel = FormEntryModel(form);
    final formEntryController = FormEntryController(formEntryModel)
      ..stepToNextEvent();
    final questionIndex = formEntryController.model.formIndex;
    final formEntryPrompt = formEntryModel.questionPrompt(questionIndex);
    expect(formEntryPrompt.selectChoices, hasLength(2));
  });

  test('throws parse exception on bad range form', () {
    expect(
      parseForm('bad-range-form.xml'),
      throwsA(isA<XFormParseException>()),
    );
  });

  test('throws exception on empty select', () {
    expect(
      parseForm('internal_empty_select.xml'),
      throwsA(
        isA<XFormParseException>().having(
          (e) => e.message,
          'message',
          contains("Select question 'First' has no choices"),
        ),
      ),
    );
  });

  test('form with count-non-empty() does not throw', () async {
    final scenario = await scenarioFor('countNonEmptyForm.xml');
    expect(scenario.answerOf('/test/count_value'), intAnswer(4));
    expect(scenario.answerOf('/test/count_non_empty_value'), intAnswer(2));
  });

  test('parses meta namespace form', () async {
    final form = await parseForm('meta-namespace-form.xml');
    expect(form.title, 'Namespace for Metadata');
    assertNoParseErrors(form);
  });

  test('serialize and restore meta namespace form instance', () async {
    // Given
    final formDef = await parseForm('meta-namespace-form.xml');
    expect(formDef.title, 'Namespace for Metadata');
    assertNoParseErrors(formDef);

    var audit = findDepthFirst(formDef.mainInstance.root, 'audit');
    var audit2 = findDepthFirst(formDef.mainInstance.root, 'audit2');
    var audit3 = findDepthFirst(formDef.mainInstance.root, 'audit3');

    expect(audit, isNotNull);
    expect(audit!.namespacePrefix, 'orx2');
    expect(audit.namespace, 'http://openrosa.org/xforms');

    expect(audit2, isNotNull);
    expect(audit2!.namespacePrefix, 'orx2');
    expect(audit2.namespace, 'http://openrosa.org/xforms');

    expect(audit3, isNotNull);
    expect(audit3!.namespacePrefix, isNull);
    expect(audit3.namespace, isNull);

    audit.setAnswer(const StringValue('audit111.csv'));
    audit2.setAnswer(const StringValue('audit222.csv'));
    audit3.setAnswer(const StringValue('audit333.csv'));

    // When

    // serialize the form instance
    final xml = XFormSerializingVisitor().serializeInstanceToString(
      formDef.mainInstance,
    );

    // restore (deserialize) the form instance
    final formInstance = restoreDataModel(parseKDocument(xml));

    // Then
    audit = findDepthFirst(formInstance.root, 'audit');
    audit2 = findDepthFirst(formInstance.root, 'audit2');
    audit3 = findDepthFirst(formInstance.root, 'audit3');

    expect(audit, isNotNull);
    expect(audit!.namespacePrefix, 'orx2');
    expect(audit.namespace, 'http://openrosa.org/xforms');
    expect(audit.value!.value, 'audit111.csv');

    expect(audit2, isNotNull);
    expect(audit2!.namespacePrefix, 'orx2');
    expect(audit2.namespace, 'http://openrosa.org/xforms');
    expect(audit2.value!.value, 'audit222.csv');

    expect(audit3, isNotNull);
    expect(audit3!.namespacePrefix, isNull);
    expect(audit3.namespace, isNull);
    expect(audit3.value!.value, 'audit333.csv');
  });

  test('parses form with template repeat', () async {
    final form = await parseForm('template-repeat.xml');
    expect(form.title, 'Repeat with template');
    assertNoParseErrors(form);
  });

  test('parses eIMCI by D-Tree form', () async {
    final form = await parseForm('eIMCI-by-D-Tree.xml');
    expect(form.title, 'eIMCI by D-Tree');
    assertNoParseErrors(form);
  });

  test('parses form with submission element', () async {
    final form = await parseForm('submission-element.xml');
    expect(form.title, 'Single Submission Element');
    assertNoParseErrors(form);
    final profile = form.submissionProfile()!;
    expect(profile.action, 'http://some.destination.com');
    expect(profile.method, 'form-data-post');
    expect(profile.mediaType, isNull);
    expect(profile.ref.toString(), '/data/text');
  });

  test('form with body before model fails', () {
    expect(parseForm('body-before-model.xml'), throwsA(anything));
  });

  test('parses form with two models', () async {
    final form = await parseForm('two-models.xml');
    expect(form.title, 'Two Models');
    expect(form.parseWarnings, [
      'XForm Parse Warning: Multiple models not supported. Ignoring '
          'subsequent models.\n'
          '    Problem found at nodeset: /html/head/model\n'
          '    With element <model><instance><data id="second-model">...\n',
    ]);
    expect(
      form.mainInstance.root.getAttribute(null, 'id')!.value!.value,
      'first-model',
    );
  });

  test('parses form with setvalue action', () async {
    final form = await parseForm('form-with-setvalue-action.xml')
      // dispatch 'odk-instance-first-load' event
      ..initialize(newInstance: true);
    expect(form.title, 'SetValue action');
    assertNoParseErrors(form);
    expect(
      form.actionController.listenersFor(FormEvents.odkInstanceFirstLoad),
      hasLength(1),
    );

    final textNode = form.mainInstance.root.childrenWithName('text').first;
    expect(textNode.value!.value, 'Test Value');
  });

  test('parses group with nodeset attribute', () async {
    final form = await parseForm('group-with-nodeset-attr.xml');
    expect(form.title, 'group with nodeset attribute');
    expect(form.parseErrors, isEmpty);
    final group = form.childAt(0)!.childAt(0)!;
    expect(group, isA<GroupDef>());
    expect((group as GroupDef).isRepeat, isFalse);
    expect(
      group.bind,
      const TreeReference.root()
          .extend('data', -1)
          .extend('R1', -1)
          .extend('G2', -1),
    );
  });

  test('parses group with ref attribute', () async {
    final form = await parseForm('group-with-ref-attr.xml');
    expect(form.title, 'group with ref attribute');
    expect(form.parseErrors, isEmpty);
    final g2 = const TreeReference.root()
        .extend('data', -1)
        .extend('G1', -1)
        .extend('G2', -1);
    // G2 has no `ref`: it is bound to its parent's reference.
    expect(
      form.childAt(0)!.childAt(0)!.bind,
      FormDef.getAbsRef(null, g2.parentRef!),
    );
    final g3 = const TreeReference.root()
        .extend('data', -1)
        .extend('G1', -1)
        .extend('G3', -1);
    expect(
      form.childAt(0)!.childAt(1)!.bind,
      FormDef.getAbsRef(g3, g3.parentRef!),
    );
  });

  test('setvalue with strings', () async {
    final scenario = await scenarioFor('default_test.xml');
    expect(
      scenario.getAnswerNode('/data/string_val').value!.value.toString(),
      'string-value',
    );
    expect(
      scenario.getAnswerNode('/data/inline_val').value!.value.toString(),
      'inline-value',
    );
  });
}
