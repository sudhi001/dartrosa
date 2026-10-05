// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every capture feature on, so questions show their buttons.
class _AllDelegates extends XFormDelegates {
  const _AllDelegates();

  @override
  bool get canCaptureMedia => true;

  @override
  bool get canLocate => true;

  @override
  bool get canScanBarcode => true;

  @override
  bool get canReadBearing => true;

  @override
  bool get canLaunchExternalApps => true;

  @override
  bool get canPrint => true;

  @override
  bool get canShowMaps => true;
}

const _long = 'A rather long question label that has to wrap';

/// One question of most kinds, with long labels.
Future<FormSession> _questions() => formSession(
  '<t/><i>123456789</i><c>999999999</c><d/><dt/><tm/><s1/><s2/><lk/><cl/>'
      '<r>3</r><rt/><vr/><g/><gt/><b/><m/><bc/><ex/><lb/><ln/><mn/><mm/>',
  '<bind nodeset="/data/t" type="string" required="true()"/>'
      '<bind nodeset="/data/i" type="int"/>'
      '<bind nodeset="/data/c" type="int"/>'
      '<bind nodeset="/data/d" type="date"/>'
      '<bind nodeset="/data/dt" type="dateTime"/>'
      '<bind nodeset="/data/tm" type="time"/>'
      '<bind nodeset="/data/r" type="int"/>'
      '<bind nodeset="/data/rt" type="int"/>'
      '<bind nodeset="/data/vr" type="int"/>'
      '<bind nodeset="/data/g" type="geopoint"/>'
      '<bind nodeset="/data/gt" type="geoshape"/>'
      '<bind nodeset="/data/b" type="decimal"/>'
      '<bind nodeset="/data/m" type="binary"/>'
      '<bind nodeset="/data/bc" type="barcode"/>'
      '<bind nodeset="/data/ex" type="string"/>',
  '<input ref="/data/t"><label>$_long</label><hint>$_long</hint></input>'
      '<input ref="/data/i" appearance="thousands-sep"><label>I</label></input>'
      '<input ref="/data/c" appearance="counter"><label>$_long</label></input>'
      '<input ref="/data/d"><label>D</label></input>'
      '<input ref="/data/dt"><label>DT</label></input>'
      '<input ref="/data/tm"><label>TM</label></input>'
      '<select1 ref="/data/s1"><label>$_long</label>'
      '${items(['Strongly disagree with this', 'Neutral'])}</select1>'
      '<select ref="/data/s2" appearance="columns"><label>S2</label>'
      '${items(['First choice', 'Second choice', 'Third choice'])}</select>'
      '<select1 ref="/data/lk" appearance="likert"><label>LK</label>'
      '${items(['Strongly disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly agree'])}'
      '</select1>'
      '<select ref="/data/cl" appearance="columns-pack no-buttons">'
      '<label>CL</label>${items(['One', 'Two', 'Three'])}</select>'
      '<range ref="/data/r" start="1" end="10" step="1"><label>R</label>'
      '</range>'
      '<range ref="/data/rt" start="1" end="5" step="1" appearance="rating">'
      '<label>RT</label></range>'
      '<range ref="/data/vr" start="1" end="5" step="1" appearance="vertical">'
      '<label>VR</label></range>'
      '<input ref="/data/g"><label>G</label></input>'
      '<input ref="/data/gt"><label>GT</label></input>'
      '<input ref="/data/b" appearance="bearing"><label>B</label></input>'
      '<upload ref="/data/m" mediatype="image/*"><label>M</label></upload>'
      '<input ref="/data/bc"><label>BC</label></input>'
      '<input ref="/data/ex" appearance="ex:org.example.app(x=\'1\')">'
      '<label>EX</label></input>'
      '<select1 ref="/data/lb" appearance="label"><label>LB</label>'
      '${items(['Yes', 'No', 'Maybe'])}</select1>'
      '<select1 ref="/data/ln" appearance="list-nolabel"><label>$_long</label>'
      '${items(['Yes', 'No', 'Maybe'])}</select1>'
      '<select1 ref="/data/mn" appearance="minimal"><label>MN</label>'
      '${items(['Yes', 'No'])}</select1>'
      '<select ref="/data/mm" appearance="minimal"><label>MM</label>'
      '${items(['Yes', 'No'])}</select>',
);

/// A field-list screen with a table-list group.
Future<FormSession> _tableList() => formSession(
  '<p><a/><b/></p>',
  '<bind nodeset="/data/p/a" type="string"/>'
      '<bind nodeset="/data/p/b" type="string"/>',
  '<group ref="/data/p" appearance="field-list">'
      '<label>$_long</label>'
      '<select1 ref="/data/p/a" appearance="table-list"><label>$_long</label>'
      '${items(['Always', 'Sometimes', 'Rarely', 'Never'])}</select1>'
      '<group ref="/data/p" appearance="table-list"><label>T</label>'
      '<select1 ref="/data/p/b"><label>$_long</label>'
      '${items(['Always', 'Sometimes', 'Rarely', 'Never'])}</select1>'
      '</group></group>',
);

/// A repeat, for the "add a group?" pager page.
Future<FormSession> _repeat() => formSession(
  '<r jr:template=""><x/></r>',
  '',
  '<repeat nodeset="/data/r"><label>$_long</label>'
      '<input ref="/data/r/x"><label>X</label></input></repeat>',
);

Future<void> _pump(
  WidgetTester tester,
  FormSession session, {
  required double width,
  required double textScale,
  double height = 640,
  XFormMode mode = XFormMode.scroll,
  XFormTheme? theme,
  XFormOutlineMode outline = XFormOutlineMode.adaptive,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme == null ? null : ThemeData(extensions: [theme]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: XFormView(
          session: session,
          mode: mode,
          delegates: const _AllDelegates(),
          outline: outline,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (1024.0, 2.0)]) {
    final name = '${width.round()}dp wide, text x$scale';

    testWidgets('questions lay out without overflow: $name', (tester) async {
      final s = await _questions();
      // Tall enough to lay out every question at once.
      await _pump(tester, s, width: width, height: 8000, textScale: scale);
      expect(find.text('Finish'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('table-list screen lays out: $name', (tester) async {
      final s = await _tableList();
      await _pump(
        tester,
        s,
        width: width,
        textScale: scale,
        mode: XFormMode.pager,
      );
      expect(find.text('Always'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pager pages lay out: $name', (tester) async {
      final s = await _repeat();
      // A phone in landscape: little height.
      await _pump(
        tester,
        s,
        width: width,
        height: 320,
        textScale: scale,
        mode: XFormMode.pager,
      );
      expect(find.text('Add group'), findsOneWidget);
      await tester.tap(find.text('Do not add'));
      await tester.pumpAndSettle();
      expect(find.text('Finalize'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('maxContentWidth at 1280dp', () {
    const capped = XFormTheme(maxContentWidth: 600);
    Rect firstField(WidgetTester tester) =>
        tester.getRect(find.byType(TextField).first);

    testWidgets('scroll mode: content is 720dp wide by default', (
      tester,
    ) async {
      await _pump(
        tester,
        await _questions(),
        width: 1280,
        textScale: 1,
        outline: XFormOutlineMode.none,
      );
      final field = firstField(tester);
      expect(field.width, XFormTheme.defaultMaxContentWidth);
      expect(field.center.dx, 640);
    });

    testWidgets('scroll mode: double.infinity fills the width', (tester) async {
      await _pump(
        tester,
        await _questions(),
        width: 1280,
        textScale: 1,
        theme: const XFormTheme(maxContentWidth: double.infinity),
        outline: XFormOutlineMode.none,
      );
      // 16dp page padding on both sides.
      expect(firstField(tester).width, 1280 - 32);
    });

    testWidgets('scroll mode: content is capped and centered', (tester) async {
      await _pump(
        tester,
        await _questions(),
        width: 1280,
        textScale: 1,
        theme: capped,
        outline: XFormOutlineMode.none,
      );
      final field = firstField(tester);
      expect(field.width, 600);
      expect(field.center.dx, 640);
      expect(tester.takeException(), isNull);

      // The margins still scroll the form.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      await tester.dragFrom(const Offset(40, 400), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));

      await tester.scrollUntilVisible(
        find.text('Finish'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getRect(find.byType(FilledButton).last).width, 600);
    });

    testWidgets('pager mode: page and buttons are capped and centered', (
      tester,
    ) async {
      final session = await formSession(
        '<a/><b/>',
        '',
        '<input ref="/data/a"><label>A</label></input>'
            '<input ref="/data/b"><label>B</label></input>',
      );
      await _pump(
        tester,
        session,
        width: 1280,
        textScale: 1,
        mode: XFormMode.pager,
        theme: capped,
        outline: XFormOutlineMode.none,
      );
      final field = firstField(tester);
      expect(field.width, 600);
      expect(field.center.dx, 640);
      // The buttons stay at the content's edges (8dp in from them).
      expect(
        tester.getRect(find.byWidgetPredicate((w) => w is OutlinedButton)).left,
        lessThan(340),
      );
      expect(
        tester.getRect(find.byWidgetPredicate((w) => w is OutlinedButton)).left,
        greaterThan(316),
      );
      expect(
        tester.getRect(find.byWidgetPredicate((w) => w is FilledButton)).right,
        greaterThan(900),
      );
      expect(
        tester.getRect(find.byWidgetPredicate((w) => w is FilledButton)).right,
        lessThan(964),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
