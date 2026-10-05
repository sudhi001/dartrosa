// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The Flutter code of docs/GETTING_STARTED.md, run as a widget test so the
// guide can't rot (packages/dartrosa/test/docs checks that the guide's
// snippets are here).
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Hello</h:title>
    <model>
      <instance><data id="hello"><name/></data></instance>
      <bind nodeset="/data/name" type="string"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Your name</label></input>
  </h:body>
</h:html>
''';

class FormScreen extends StatelessWidget {
  const FormScreen({required this.session, required this.onDone, super.key});

  final FormSession session;
  final ValueChanged<Submission> onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(session.definition.title ?? '')),
    body: XFormView(
      session: session,
      mode: XFormMode.pager, // or XFormMode.scroll
      // Camera, location, barcode, media in labels, external apps, ...
      // Without delegates, capture questions fall back to typing.
      delegates: const NoDelegates(),
      // Replace any question widget, by control type and appearance.
      widgetOverrides: {
        'selectOne:likert': (context, node) => const Text('My likert'),
      },
      onFinalized: onDone,
    ),
  );
}

void main() {
  testWidgets('XFormView shows the form', (tester) async {
    final session = await tester.runAsync(
      () async => (await FormDefinition.parse(formXml)).createSession(),
    );
    final submissions = <Submission>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [XFormTheme()]),
        home: FormScreen(session: session!, onDone: submissions.add),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
  });
}
