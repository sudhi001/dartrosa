import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<FormSession> _form() => formSession(
  '<n/><a/><b/><c/><r/><d/>',
  '<bind nodeset="/data/n" type="string" required="true()"/>'
      '<bind nodeset="/data/a" type="string"/>'
      '<bind nodeset="/data/b" type="string"/>'
      '<bind nodeset="/data/c" type="string"/>'
      '<bind nodeset="/data/r" type="int"/>'
      '<bind nodeset="/data/d" type="date"/>',
  '<input ref="/data/n"><label>**Name**</label></input>'
      '<select1 ref="/data/a"><label>A</label>${items(['X', 'Y'])}</select1>'
      '<select1 ref="/data/b" appearance="likert"><label>B</label>'
      '${items(['Bad', 'Good'])}</select1>'
      '<select ref="/data/c" appearance="columns-2 no-buttons"><label>C</label>'
      '${items(['P', 'Q', 'S'])}</select>'
      '<range ref="/data/r" start="1" end="3" step="1" appearance="rating">'
      '<label>R</label></range>'
      '<input ref="/data/d"><label>D</label></input>',
);

void main() {
  testWidgets('questions are labelled with label, required and error', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await _form();
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    final name = find.bySemanticsLabel('Name, required');
    expect(name, findsOneWidget);
    expect(
      tester.getSemantics(name).getSemanticsData().validationResult,
      SemanticsValidationResult.none,
    );
    await tester.enterText(find.byType(TextField), 'x');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(
      tester.getSemantics(name).getSemanticsData().validationResult,
      SemanticsValidationResult.invalid,
    );
    expect(find.bySemanticsLabel('A'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('blocked Next announces the error', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await _form();
    await tester.pumpWidget(app(XFormView(session: s)));
    await tester.tap(find.text('Next'));
    await tester.pump();
    final announcements = tester.takeAnnouncements();
    expect(announcements.map((a) => a.message), [
      'Sorry, this response is required!',
    ]);
    expect(announcements.single.assertiveness, Assertiveness.assertive);
    handle.dispose();
  });

  testWidgets('tap targets are at least 48dp and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await _form();
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('focus follows form order', (tester) async {
    final s = await _form();
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    final group = tester.widget<FocusTraversalGroup>(
      find
          .descendant(
            of: find.byType(XFormView),
            matching: find.byType(FocusTraversalGroup),
          )
          .first,
    );
    expect(group.policy, isA<WidgetOrderTraversalPolicy>());
  });
}
