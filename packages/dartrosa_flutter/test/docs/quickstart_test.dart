// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Runs the app of docs/QUICKSTART.md (quickstart_app.dart) with the quick
// start's form as its asset.
import 'dart:convert';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quickstart_app.dart' as app;

/// assets/visit.xml of the quick start.
const visitXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance>
        <data id="visit">
          <name/><age/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 18"
          jr:constraintMsg="Only adults can take part"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>What is your name?</label></input>
    <input ref="/data/age"><label>How old are you?</label></input>
  </h:body>
</h:html>
''';

void main() {
  testWidgets('the quick start app shows the form', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        return key == 'assets/visit.xml'
            ? ByteData.sublistView(utf8.encode(visitXml))
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    expect(find.byType(XFormView), findsOne);
    expect(find.text('Visit'), findsOne);
    expect(
      find.textContaining('What is your name?', findRichText: true),
      findsOne,
    );
  });
}
