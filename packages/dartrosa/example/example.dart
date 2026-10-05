// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Parses an XForm, answers its questions and prints the submission XML.
import 'package:dartrosa/dartrosa.dart';

const xform = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household</h:title>
    <model>
      <instance>
        <data id="household">
          <name/>
          <age/>
          <adult/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 0"
          jr:constraintMsg="Age can't be negative"/>
      <bind nodeset="/data/adult" type="string"
          calculate="if(/data/age &gt;= 18, 'yes', 'no')"/>
      <bind nodeset="/data/meta/instanceID" type="string"
          jr:preload="uid" readonly="true()"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Name</label></input>
    <input ref="/data/age"><label>Age</label></input>
  </h:body>
</h:html>
''';

Future<void> main() async {
  final definition = await FormDefinition.parse(xform);
  final session = definition.createSession();

  final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
  session.answer(name.index, const StringValue('Ada'));

  switch (session.answer(age.index, const IntegerValue(-3))) {
    case AnswerConstraintViolated(:final message):
      _log('Rejected: $message'); // Age can't be negative
    case AnswerAccepted() || AnswerRequired() || AnswerRejected():
      break;
  }
  session.answer(age.index, const UncastValue('42')); // text is parsed

  switch (session.finalize()) {
    case FinalizeSuccess(:final submission):
      _log(submission.xml);
    case FinalizeFailure(:final failure):
      _log('Invalid at ${failure.index.reference}');
  }
}

// ignore: avoid_print
void _log(Object? message) => print(message);
