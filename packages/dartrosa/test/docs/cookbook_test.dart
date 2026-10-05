// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of the engine recipes in docs/cookbook/ (custom XPath function,
// server-side validation, testing forms with the session API), run as
// tests so the recipes can't rot (doc_snippets.dart checks that their
// snippets are here).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:test/test.dart';

const visitForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household visit</h:title>
    <model>
      <instance>
        <data id="household_visit" version="1">
          <head_name/><members/><has_water/><water_source/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/head_name" type="string" required="true()"/>
      <bind nodeset="/data/members" type="int" required="true()"
          constraint=". &gt; 0 and . &lt; 30"
          jr:constraintMsg="Between 1 and 29"/>
      <bind nodeset="/data/has_water" type="string"/>
      <bind nodeset="/data/water_source" type="string" required="true()"
          relevant="/data/has_water = 'yes'"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/head_name"><label>Name of the household head</label></input>
    <input ref="/data/members"><label>How many people live here?</label></input>
    <select1 ref="/data/has_water"><label>Drinking water?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <input ref="/data/water_source"><label>Where does the water come from?</label></input>
  </h:body>
</h:html>
''';

const cardForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Card</h:title>
    <model>
      <instance><data id="card"><number/><checked/></data></instance>
      <bind nodeset="/data/number" type="string" constraint="luhn(.)"
          jr:constraintMsg="Check the card number"/>
      <bind nodeset="/data/checked" type="string"
          calculate="if(luhn(/data/number), 'valid', 'invalid')"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/number"><label>Card number</label></input>
  </h:body>
</h:html>
''';

// --- Recipe: add a custom XPath function --------------------------------

// luhn('79927398713') is true: the number's check digit is right.
final class LuhnFunction extends XPathFunctionHandler {
  @override
  String get name => 'luhn';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    final text = args.single as String;
    if (!RegExp(r'^\d+$').hasMatch(text)) return false;
    var sum = 0;
    for (final (i, char) in text.split('').reversed.indexed) {
      final digit = int.parse(char) * (i.isOdd ? 2 : 1);
      sum += digit > 9 ? digit - 9 : digit;
    }
    return sum % 10 == 0;
  }
}

// --- Recipe: validate submissions on the server --------------------------

final _definitions = <String, Future<FormDefinition>>{};

/// The first problem of [submissionXml] against [formXml], or `null` if
/// the submission is valid.
Future<String?> validateSubmission(String formXml, String submissionXml) async {
  // Parse each form version once. A definition backs one session at a
  // time, so nothing below awaits between createSession and finalize.
  final definition = await _definitions.putIfAbsent(
    formXml,
    () => FormDefinition.parse(formXml),
  );
  final session = definition.createSession(existingInstance: submissionXml);
  switch (session.finalize()) {
    case FinalizeSuccess():
      return null;
    case FinalizeFailure(:final failure):
      final question = session.nodeAt(failure.index) as QuestionNode;
      final problem = switch (failure.result) {
        AnswerRequired(:final message) => message ?? 'is required',
        AnswerConstraintViolated(:final message) => message ?? 'is invalid',
        AnswerRejected(:final message) => message,
        AnswerAccepted() => 'is invalid',
      };
      return '${question.label.text}: $problem';
  }
}

void main() {
  group('custom XPath function', () {
    test('in a constraint and a calculation', () async {
      final definition = await FormDefinition.parse(
        cardForm,
        config: DartRosaConfig(functions: [LuhnFunction()]),
      );
      final session = definition.createSession();
      final number = session.root.children.first as QuestionNode;
      final wrong = session.answer(number.index, const StringValue('1234'));
      // AnswerConstraintViolated('Check the card number')
      final right = session.answer(
        number.index,
        const StringValue('79927398713'),
      ); // AnswerAccepted

      expect(wrong, isA<AnswerConstraintViolated>());
      expect(right, isA<AnswerAccepted>());
      final xml = (session.finalize() as FinalizeSuccess).submission.xml;
      expect(xml, contains('<checked>valid</checked>'));
    });

    test('without the function the form does not start', () async {
      final definition = await FormDefinition.parse(cardForm);
      expect(
        definition.createSession,
        throwsA(
          predicate((e) => '$e'.contains("cannot handle function 'luhn'")),
        ),
      );
    });
  });

  group('server-side validation', () {
    test('valid and invalid submissions', () async {
      const valid =
          '<data id="household_visit" version="1">'
          '<head_name>Amina</head_name><members>4</members>'
          '<has_water>no</has_water><meta><instanceID>uuid:1</instanceID>'
          '</meta></data>';
      const tooMany =
          '<data id="household_visit" version="1">'
          '<head_name>Amina</head_name><members>40</members>'
          '<has_water>no</has_water><meta><instanceID>uuid:2</instanceID>'
          '</meta></data>';
      const missingSource =
          '<data id="household_visit" version="1">'
          '<head_name>Amina</head_name><members>4</members>'
          '<has_water>yes</has_water><meta><instanceID>uuid:3</instanceID>'
          '</meta></data>';

      expect(await validateSubmission(visitForm, valid), isNull);
      expect(
        await validateSubmission(visitForm, tooMany),
        'How many people live here?: Between 1 and 29',
      );
      expect(
        await validateSubmission(visitForm, missingSource),
        startsWith('Where does the water come from?: '),
      );
    });
  });

  test('a tampered calculation is recomputed', () async {
    final definition = await FormDefinition.parse(
      cardForm,
      config: DartRosaConfig(functions: [LuhnFunction()]),
    );
    final session = definition.createSession(
      existingInstance:
          '<data id="card"><number>1234</number><checked>valid</checked>'
          '</data>',
    );
    final checked = session.root.children.length;
    expect(checked, 1);
    // The constraint fails on finalize; the calculation was recomputed.
    expect(session.finalize(), isA<FinalizeFailure>());
    expect(session.saveDraft(), contains('<checked>invalid</checked>'));
  });

  group('testing forms with the session API', () {
    late FormSession session;
    late List<QuestionNode> questions;

    setUp(() async {
      final definition = await FormDefinition.parse(visitForm);
      session = definition.createSession();
      questions = session.root.children.cast<QuestionNode>();
    });

    test('members must be between 1 and 29', () {
      final members = questions[1];
      expect(
        session.answer(members.index, const IntegerValue(40)),
        isA<AnswerConstraintViolated>().having(
          (r) => r.message,
          'message',
          'Between 1 and 29',
        ),
      );
      expect(
        session.answer(members.index, const IntegerValue(4)),
        isA<AnswerAccepted>(),
      );
    });

    test('the water source is asked only when there is water', () {
      final [_, _, water, source] = questions;
      session.answer(water.index, const SelectOneValue(Selection('no')));
      expect(source.isRelevant, isFalse);
      session.answer(water.index, const SelectOneValue(Selection('yes')));
      expect(source.isRelevant, isTrue);
    });

    test('a complete visit finalizes', () {
      final [name, members, water, _] = questions;
      session
        ..answer(name.index, const StringValue('Amina'))
        ..answer(members.index, const IntegerValue(4))
        ..answer(water.index, const SelectOneValue(Selection('no')));
      final result = session.finalize();
      expect(result, isA<FinalizeSuccess>());
      final xml = (result as FinalizeSuccess).submission.xml;
      expect(xml, contains('<members>4</members>'));
      expect(xml, isNot(contains('water_source')));
    });
  });
}
