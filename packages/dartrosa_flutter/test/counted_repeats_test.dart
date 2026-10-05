// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Repeats with a fixed number of instances (`jr:count`, `jr:noAddRemove`)
// in scroll mode: the counted instances are created as the pager creates
// them, and there are no add or remove buttons.

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// `plots`, then a `jr:count="/data/plots"` repeat of `crop`.
Future<FormSession> _counted({String plots = ''}) => formSession(
  '<plots>$plots</plots><plot jr:template=""><crop/></plot>',
  '<bind nodeset="/data/plots" type="int"/>'
      '<bind nodeset="/data/plot/crop" type="string"/>',
  '<input ref="/data/plots"><label>How many plots?</label></input>'
      '<group ref="/data/plot"><label>Plot</label>'
      '<repeat nodeset="/data/plot" jr:count="/data/plots">'
      '<input ref="/data/plot/crop"><label>Main crop</label></input>'
      '</repeat></group>',
);

RepeatNode _repeat(FormSession s) => s.root.children[1] as RepeatNode;

Future<void> _pump(WidgetTester tester, FormSession s) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
  await tester.pumpAndSettle();
}

Finder get _plots => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is QuestionWidget && w.node.label.text == 'How many plots?',
  ),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('scroll mode creates the jr:count instances', (tester) async {
    final s = await _counted(plots: '2');
    await _pump(tester, s);
    expect(_repeat(s).instances, hasLength(2));
    expect(find.text('Main crop'), findsNWidgets(2));
    expect(find.textContaining('Add'), findsNothing);
    expect(find.byTooltip('Remove'), findsNothing);
  });

  testWidgets('no count yet: no instances and no add button', (tester) async {
    final s = await _counted();
    await _pump(tester, s);
    expect(_repeat(s).instances, isEmpty);
    expect(find.text('Main crop'), findsNothing);
    expect(find.textContaining('Add'), findsNothing);
  });

  testWidgets('the instances follow the count', (tester) async {
    final s = await _counted();
    await _pump(tester, s);
    await tester.enterText(_plots, '3');
    await tester.pumpAndSettle();
    expect(_repeat(s).instances, hasLength(3));
    expect(find.text('Main crop'), findsNWidgets(3));
    await tester.enterText(_plots, '4');
    await tester.pumpAndSettle();
    expect(_repeat(s).instances, hasLength(4));
    expect(find.text('Main crop'), findsNWidgets(4));
    expect(find.textContaining('Add'), findsNothing);
    expect(find.byTooltip('Remove'), findsNothing);
  });

  testWidgets('jr:noAddRemove: the instances, no add or remove', (
    tester,
  ) async {
    final s = await formSession(
      '<visit><day>Mon</day></visit><visit><day>Tue</day></visit>',
      '<bind nodeset="/data/visit/day" type="string"/>',
      '<group ref="/data/visit"><label>Visit</label>'
          '<repeat nodeset="/data/visit" jr:noAddRemove="true()">'
          '<input ref="/data/visit/day"><label>Day</label></input>'
          '</repeat></group>',
    );
    await _pump(tester, s);
    expect(find.text('Day'), findsNWidgets(2));
    expect(find.textContaining('Add'), findsNothing);
    expect(find.byTooltip('Remove'), findsNothing);
  });

  testWidgets('the pager still creates them on the way', (tester) async {
    final s = await _counted(plots: '2');
    await tester.pumpWidget(app(XFormView(session: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Main crop'), findsOneWidget);
    expect(_repeat(s).instances, hasLength(1));
  });
}
