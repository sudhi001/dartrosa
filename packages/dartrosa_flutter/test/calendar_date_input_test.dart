// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<FormSession> dateQuestion(String appearance, {String value = ''}) =>
    formSession(
      '<q>$value</q>',
      '<bind nodeset="/data/q" type="date"/>',
      '<input ref="/data/q" appearance="$appearance"><label>D</label></input>',
    );

Future<void> pump(WidgetTester tester, FormSession s) =>
    tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Select date'));
  await tester.pumpAndSettle();
}

/// Picks [label] in the dropdown with key `calendar-<name>`.
Future<void> choose(WidgetTester tester, String name, String label) async {
  await tester.tap(find.byKey(ValueKey('calendar-$name')));
  await tester.pumpAndSettle();
  // The menu only builds the items around the selected one.
  final menu = find.byType(ListView).last;
  for (final dy in [300.0, -600.0, -600.0]) {
    if (find.text(label).hitTestable().evaluate().isNotEmpty) break;
    await tester.drag(menu, Offset(0, dy));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).hitTestable().last);
  await tester.pumpAndSettle();
}

String dialogLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('calendar-label'))).data!;

void main() {
  group('calendar appearances show the answer as Collect does', () {
    const cases = {
      'ethiopian': '4 Ginbot 2012 (May 12, 2020)',
      'coptic': '4 Pashons 1736 (May 12, 2020)',
      'islamic': '19 Ramadan 1441 (May 12, 2020)',
      'bikram-sambat': '30 बैशाख 2077 (May 12, 2020)',
      'myanmar': '21 ကဆုန် 1382 (May 12, 2020)',
      'persian': '23 Ordibehesht 1399 (May 12, 2020)',
      'buddhist': '12 พฤษภาคม 2563 (May 12, 2020)',
      'ethiopian month-year': 'Ginbot 2012 (May 2020)',
      'year persian': '1399 (2020)',
    };
    cases.forEach((appearance, label) {
      testWidgets(appearance, (tester) async {
        await pump(tester, await dateQuestion(appearance, value: '2020-05-12'));
        expect(find.text(label), findsOneWidget);
      });
    });
  });

  testWidgets('the picker opens on the answer with the calendar spinners', (
    tester,
  ) async {
    final s = await dateQuestion('ethiopian', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    expect(find.byType(CalendarDatePicker), findsNothing);
    for (final name in ['day', 'month', 'year']) {
      expect(find.byKey(ValueKey('calendar-$name')), findsOneWidget);
    }
    expect(dialogLabel(tester), '4 Ginbot 2012 (May 12, 2020)');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value, DateValue(DateTime(2020, 5, 12)));
  });

  testWidgets('picking an Ethiopian date stores the Gregorian date', (
    tester,
  ) async {
    final s = await dateQuestion('ethiopian', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    await choose(tester, 'month', 'Meskerem');
    expect(dialogLabel(tester), '4 Meskerem 2012 (Sep 15, 2019)');
    await choose(tester, 'day', '1');
    expect(dialogLabel(tester), '1 Meskerem 2012 (Sep 12, 2019)');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value, DateValue(DateTime(2019, 9, 12)));
    expect(find.text('1 Meskerem 2012 (Sep 12, 2019)'), findsOneWidget);
  });

  testWidgets('the month clamps the day (Persian)', (tester) async {
    final s = await dateQuestion('persian', value: '2020-09-21');
    await pump(tester, s);
    await openPicker(tester);
    expect(dialogLabel(tester), '31 Shahrivar 1399 (Sep 21, 2020)');
    await choose(tester, 'month', 'Mehr');
    expect(dialogLabel(tester), '30 Mehr 1399 (Oct 21, 2020)');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value, DateValue(DateTime(2020, 10, 21)));
  });

  testWidgets('month-year hides the day and saves the first day', (
    tester,
  ) async {
    final s = await dateQuestion('month-year islamic', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    expect(find.byKey(const ValueKey('calendar-day')), findsNothing);
    expect(dialogLabel(tester), 'Ramadan 1441 (Apr 2020)');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value, DateValue(DateTime(2020, 4, 24)));
  });

  testWidgets('year mode shows the year only (Myanmar quirk kept)', (
    tester,
  ) async {
    final s = await dateQuestion('myanmar year', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    expect(find.byKey(const ValueKey('calendar-day')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-month')), findsNothing);
    // Collect saves day 1 of the year's first month, which falls before
    // the Myanmar new year.
    expect(dialogLabel(tester), '1381 (2020)');
  });

  testWidgets('Myanmar month spinner follows the year', (tester) async {
    final s = await dateQuestion('myanmar', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    await choose(tester, 'year', '1380');
    expect(dialogLabel(tester), contains('1380'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final stored = (question(s, 0).value! as DateValue).date;
    expect(stored.year, 2018);
  });

  testWidgets('Bikram Sambat picks with Nepali month names', (tester) async {
    final s = await dateQuestion('bikram-sambat', value: '2020-05-12');
    await pump(tester, s);
    await openPicker(tester);
    await choose(tester, 'month', 'जेठ');
    expect(dialogLabel(tester), '30 जेठ 2077 (Jun 12, 2020)');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value, DateValue(DateTime(2020, 5, 12)));
  });

  testWidgets('an unanswered question opens on today', (tester) async {
    final s = await dateQuestion('coptic');
    await pump(tester, s);
    expect(find.text('—'), findsOneWidget);
    await openPicker(tester);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(
      question(s, 0).value,
      DateValue(DateTime(now.year, now.month, now.day)),
    );
  });

  testWidgets('Bikram Sambat outside its range opens on a supported date', (
    tester,
  ) async {
    final s = await dateQuestion('bikram-sambat', value: '1900-01-01');
    await pump(tester, s);
    expect(find.text(' (Jan 01, 1900)'), findsOneWidget);
    await openPicker(tester);
    expect(dialogLabel(tester), '1 बैशाख 1970 (Apr 13, 1913)');
  });

  testWidgets('date-time questions keep the Gregorian pickers', (tester) async {
    final s = await formSession(
      '<q>2020-05-12T10:00:00.000Z</q>',
      '<bind nodeset="/data/q" type="dateTime"/>',
      '<input ref="/data/q" appearance="ethiopian"><label>D</label></input>',
    );
    await pump(tester, s);
    expect(find.textContaining('Ginbot'), findsNothing);
  });
}
