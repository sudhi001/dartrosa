// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"';

const formXml =
    '<?xml version="1.0"?><h:html $_ns><h:head><h:title>Survey</h:title>'
    '<model><instance><data id="survey"><name/><age/><adult/><pet/>'
    '<colors/><child><cname/></child><meta><instanceID/></meta></data>'
    '</instance>'
    '<bind nodeset="/data/name" type="string" required="true()"/>'
    '<bind nodeset="/data/age" type="int" constraint=". &gt;= 0" '
    'jr:constraintMsg="Age must not be negative"/>'
    '<bind nodeset="/data/adult" type="string" relevant="/data/age &gt;= 18"/>'
    '<bind nodeset="/data/pet" type="string"/>'
    '<bind nodeset="/data/colors" type="string"/>'
    '<bind nodeset="/data/child/cname" type="string"/>'
    '<bind nodeset="/data/meta/instanceID" type="string" readonly="true()" '
    'jr:preload="uid"/>'
    '</model></h:head><h:body>'
    '<input ref="/data/name"><label>Name</label><hint>Your name</hint></input>'
    '<input ref="/data/age"><label>Age</label></input>'
    '<input ref="/data/adult"><label>Adult question</label></input>'
    '<select1 ref="/data/pet"><label>Pet</label>'
    '<item><label>Cat</label><value>cat</value></item>'
    '<item><label>Dog</label><value>dog</value></item></select1>'
    '<select ref="/data/colors"><label>Colors</label>'
    '<item><label>Red</label><value>red</value></item>'
    '<item><label>Blue</label><value>blue</value></item></select>'
    '<repeat nodeset="/data/child"><label>Child</label>'
    '<input ref="/data/child/cname"><label>Child name</label></input>'
    '</repeat>'
    '</h:body></h:html>';

Future<FormSession> session() async =>
    (await FormDefinition.parse(formXml)).createSession();

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('scroll mode: answers, relevance, constraint, selects', (
    tester,
  ) async {
    final s = await session();
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    expect(find.text('* Name'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Adult question'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Ann');
    await tester.enterText(find.byType(TextField).at(1), '-3');
    await tester.pump();
    expect(find.text('Age must not be negative'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.pump();
    expect(find.text('Age must not be negative'), findsNothing);
    expect(find.text('Adult question'), findsOneWidget);

    for (final label in ['Dog', 'Blue']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.pump();
    final root = s.root.children;
    expect((root[3] as QuestionNode).value?.displayText, 'dog');
    expect((root[4] as QuestionNode).value?.displayText, 'blue');
    expect((root[1] as QuestionNode).value, const IntegerValue(30));
  });

  testWidgets('scroll mode: repeats can be added and removed', (tester) async {
    final s = await session();
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    expect(find.text('Child name'), findsOneWidget);
    await tester.ensureVisible(find.text('Add another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another'));
    await tester.pump();
    RepeatNode repeat() => s.root.children[5] as RepeatNode;
    expect(repeat().instances, hasLength(2));
    await tester.ensureVisible(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    // Removing asks first.
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repeat().instances, hasLength(2));
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repeat().instances, hasLength(1));
  });

  testWidgets('pager mode: required blocks Next; finalize submits', (
    tester,
  ) async {
    final s = await session();
    Submission? submitted;
    await tester.pumpWidget(
      app(XFormView(session: s, onFinalized: (sub) => submitted = sub)),
    );
    expect(find.text('* Name'), findsOneWidget);
    expect(find.text('Age'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Sorry, this response is required!'), findsOneWidget);
    expect(find.text('* Name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bo');
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Age'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Next'));
    await tester.pump();
    // The adult question is not relevant: skipped.
    expect(find.text('Pet'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Colors'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    // The repeat's first instance.
    expect(find.text('Child name'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Add group'), findsOneWidget);
    await tester.tap(find.text('Do not add'));
    await tester.pump();
    expect(find.text('Finalize'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Add group'), findsOneWidget);
    await tester.tap(find.text('Do not add'));
    await tester.pump();
    await tester.tap(find.text('Finalize'));
    await tester.pump();
    expect(submitted, isNotNull);
    expect(submitted!.xml, contains('<name>Bo</name><age>5</age>'));
    expect(submitted!.instanceId, startsWith('uuid:'));
  });
}
