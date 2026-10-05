// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Details of the renderer's UX: keyboard-usable rank questions, the
// calendar dialog on narrow screens, desktop pickers, nested groups and
// the controller's form-wide notifications.

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('rank: move buttons reorder without dragging', (tester) async {
    final s = await formSession(
      '<r/>',
      '<bind nodeset="/data/r" type="odk:rank" '
          'xmlns:odk="http://www.opendatakit.org/xforms"/>',
      '<odk:rank xmlns:odk="http://www.opendatakit.org/xforms" '
          'ref="/data/r"><label>R</label>${items(['A', 'B', 'C'])}'
          '</odk:rank>',
    );
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    // The first can't move up, the last can't move down.
    List<IconButton> buttons(String tooltip) => [
      for (final b in tester.widgetList<IconButton>(find.byType(IconButton)))
        if (b.tooltip == tooltip) b,
    ];
    expect(buttons('Move up').first.onPressed, isNull);
    expect(buttons('Move down').last.onPressed, isNull);
    expect(buttons('Move down').first.onPressed, isNotNull);
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pumpAndSettle();
    expect(question(s, 0).value?.displayText, 'b, a, c');
  });

  testWidgets('calendar dialog: the month gets its own line when narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<DateTime>(
                context: context,
                builder: (_) => CustomCalendarDatePickerDialog(
                  details: DatePickerDetails.fromAppearance('ethiopian'),
                  initialDate: DateTime(2024, 3, 20),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final month = tester.getRect(find.byKey(const ValueKey('calendar-month')));
    final day = tester.getRect(find.byKey(const ValueKey('calendar-day')));
    expect(month.bottom, lessThanOrEqualTo(day.top));
    expect(find.text('Megabit'), findsOneWidget);
  });

  testWidgets('desktop: the time picker opens for typing', (tester) async {
    final s = await formSession(
      '<t/>',
      '<bind nodeset="/data/t" type="time"/>',
      '<input ref="/data/t"><label>T</label></input>',
    );
    await tester.pumpWidget(
      app(
        XFormView(session: s, mode: XFormMode.scroll),
        theme: ThemeData(platform: TargetPlatform.windows),
      ),
    );
    await tester.tap(find.text('Select time'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialEntryMode,
      TimePickerEntryMode.input,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a group inside a group is a section, not a card', (
    tester,
  ) async {
    final s = await formSession(
      '<g><h><a/></h></g>',
      '',
      '<group ref="/data/g"><label>Outer</label>'
          '<group ref="/data/g/h"><label>Inner</label>'
          '<input ref="/data/g/h/a"><label>A</label></input>'
          '</group></group>',
    );
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(XFormCard), findsNWidgets(2));
    // The outer card is a filled card: no shadow.
    expect(tester.widget<Card>(find.byType(Card)).elevation, 0);
  });

  test('XFormTheme: the new settings copy and lerp', () {
    const a = XFormTheme();
    expect(a.adaptiveChoiceColumns, isTrue);
    expect(a.outlinePanelWidth, 320);
    expect(a.effectiveMaxContentWidth, XFormTheme.defaultMaxContentWidth);
    final b = a.copyWith(adaptiveChoiceColumns: false, outlinePanelWidth: 400);
    expect(b.adaptiveChoiceColumns, isFalse);
    expect(a.lerp(b, 0.5).outlinePanelWidth, 360);
    expect(a.lerp(b, 0.4).adaptiveChoiceColumns, isTrue);
    expect(a.lerp(b, 0.6).adaptiveChoiceColumns, isFalse);
  });

  testWidgets('adaptiveChoiceColumns: false keeps one choice per line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await formSession(
      '<c/>',
      '',
      '<select1 ref="/data/c"><label>C</label>'
          '${items(['One', 'Two', 'Three', 'Four'])}</select1>',
    );
    Future<bool> sideBySide(XFormTheme theme) async {
      await tester.pumpWidget(
        app(
          XFormView(session: s, mode: XFormMode.scroll),
          theme: ThemeData(extensions: [theme]),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.text('One')).top ==
          tester.getRect(find.text('Two')).top;
    }

    expect(await sideBySide(const XFormTheme()), isTrue);
    expect(
      await sideBySide(const XFormTheme(adaptiveChoiceColumns: false)),
      isFalse,
    );
  });

  test('XFormController.formChanges hears answers and errors', () async {
    final s = await formSession(
      '<a/>',
      '<bind nodeset="/data/a" type="int" constraint=". &gt; 0"/>',
      '<input ref="/data/a"><label>A</label></input>',
    );
    final controller = XFormController(s);
    addTearDown(controller.dispose);
    var count = 0;
    controller.formChanges.addListener(() => count++);
    controller.answer(question(s, 0).index, const IntegerValue(3));
    expect(count, greaterThan(0));
    final before = count;
    controller.answer(question(s, 0).index, const IntegerValue(-1));
    expect(count, greaterThan(before));
  });
}
