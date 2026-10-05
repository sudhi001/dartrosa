// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Read-only questions show their values, as ODK Collect's widgets do;
// notes (read-only text without a value) show only their labels.

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The widget of the question labelled [label].
Finder _question(String label) => find.byWidgetPredicate(
  (w) => w is QuestionWidget && w.node.label.text == label,
);

Finder _in(String label, Finder finder) =>
    find.descendant(of: _question(label), matching: finder);

void main() {
  late FormSession s;

  setUp(() async {
    s = await formSession(
      '<name>Amina</name><note/><calc/><default>Kept</default>'
          '<secret>abc</secret><n>1250</n><d>3.5</d><empty_n/>'
          '<date>2024-03-20</date><one>b</one><many>a c</many>',
      '<bind nodeset="/data/name" type="string"/>'
          '<bind nodeset="/data/note" type="string" readonly="true()"/>'
          '<bind nodeset="/data/calc" type="string" readonly="true()" '
          'calculate="concat(\'Hello \', /data/name)"/>'
          '<bind nodeset="/data/default" type="string" readonly="true()"/>'
          '<bind nodeset="/data/secret" type="string" readonly="true()"/>'
          '<bind nodeset="/data/n" type="int" readonly="true()"/>'
          '<bind nodeset="/data/d" type="decimal" readonly="true()"/>'
          '<bind nodeset="/data/empty_n" type="int" readonly="true()"/>'
          '<bind nodeset="/data/date" type="date" readonly="true()"/>'
          '<bind nodeset="/data/one" type="string" readonly="true()"/>'
          '<bind nodeset="/data/many" type="string" readonly="true()"/>',
      '<input ref="/data/name"><label>Name</label></input>'
          '<input ref="/data/note"><label>Just a note</label></input>'
          '<input ref="/data/calc"><label>Greeting</label></input>'
          '<input ref="/data/default"><label>Default</label></input>'
          '<secret ref="/data/secret"><label>Secret</label></secret>'
          '<input ref="/data/n" appearance="thousands-sep">'
          '<label>Integer</label></input>'
          '<input ref="/data/d"><label>Decimal</label></input>'
          '<input ref="/data/empty_n"><label>Empty integer</label></input>'
          '<input ref="/data/date"><label>Date</label></input>'
          '<select1 ref="/data/one"><label>One</label>'
          '${items(['A', 'B'])}</select1>'
          '<select ref="/data/many"><label>Many</label>'
          '${items(['A', 'B', 'C'])}</select>',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    await tester.pumpAndSettle();
  }

  testWidgets('a read-only text with a value shows it, not a field', (
    tester,
  ) async {
    await pump(tester);
    expect(_in('Default', find.text('Kept')), findsOneWidget);
    expect(_in('Default', find.byType(EditableText)), findsNothing);
    // A calculated value, kept up to date.
    expect(_in('Greeting', find.text('Hello Amina')), findsOneWidget);
    await tester.enterText(_in('Name', find.byType(EditableText)), 'Bo');
    await tester.pumpAndSettle();
    expect(_in('Greeting', find.text('Hello Bo')), findsOneWidget);
  });

  testWidgets('a note (read-only text without a value) is label only', (
    tester,
  ) async {
    await pump(tester);
    expect(_question('Just a note'), findsOneWidget);
    expect(_in('Just a note', find.byType(EditableText)), findsNothing);
    // The label is its only text.
    expect(_in('Just a note', find.byType(Text)), findsOneWidget);
  });

  testWidgets('read-only values are read out as read-only', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      tester.getSemantics(_in('Default', find.text('Kept'))),
      matchesSemantics(label: 'Kept', isReadOnly: true),
    );
    // Secrets stay masked.
    expect(_in('Secret', find.text('abc')), findsNothing);
    expect(_in('Secret', find.text('•••')), findsOneWidget);
    expect(
      tester.getSemantics(_in('Secret', find.text('•••'))),
      matchesSemantics(isReadOnly: true, isObscured: true),
    );
    handle.dispose();
  });

  testWidgets('read-only numbers, dates and selects show their values', (
    tester,
  ) async {
    await pump(tester);
    expect(_in('Integer', find.text('1,250')), findsOneWidget);
    expect(_in('Decimal', find.text('3.5')), findsOneWidget);
    expect(_in('Empty integer', find.text('—')), findsOneWidget);
    for (final label in ['Integer', 'Decimal', 'Empty integer']) {
      expect(_in(label, find.byType(EditableText)), findsNothing);
    }
    expect(_in('Date', find.text('20/03/24')), findsOneWidget);
    expect(_in('Date', find.byType(FilledButton)), findsNothing);
    final radio = tester.widget<RadioGroup<String>>(
      _in('One', find.byType(RadioGroup<String>)),
    );
    expect(radio.groupValue, 'b');
    final boxes = tester
        .widgetList<Checkbox>(_in('Many', find.byType(Checkbox)))
        .toList();
    expect([for (final b in boxes) b.value], [true, false, true]);
    expect(boxes.every((b) => b.onChanged == null), isTrue);
  });
}
