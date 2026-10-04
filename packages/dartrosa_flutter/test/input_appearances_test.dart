import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<FormSession> one(String type, String control, {String value = ''}) =>
    formSession(
      '<q>$value</q>',
      '<bind nodeset="/data/q" type="$type"/>',
      control.replaceFirst('>', ' ref="/data/q">'),
    );

Future<void> pump(WidgetTester tester, FormSession s) =>
    tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));

TextField field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('thousands-sep', () {
    test('groupThousands', () {
      expect(groupThousands('1234567'), '1,234,567');
      expect(groupThousands('-1234.567'), '-1,234.567');
      expect(groupThousands('123'), '123');
      expect(groupThousands(''), '');
    });

    test('formatter keeps the cursor after the same digit', () {
      final f = ThousandsSeparatorFormatter(decimal: false);
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1,2345',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(out.text, '12,345');
      expect(out.selection.baseOffset, 4);
      expect(
        f
            .formatEditUpdate(
              const TextEditingValue(text: '12'),
              const TextEditingValue(text: '12a'),
            )
            .text,
        '12',
      );
    });

    testWidgets('integer: grouped display, plain answer', (tester) async {
      final s = await one(
        'int',
        '<input appearance="thousands-sep"><label>N</label></input>',
        value: '1234',
      );
      await pump(tester, s);
      expect(find.text('1,234'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234567');
      await tester.pump();
      expect(find.text('1,234,567'), findsOneWidget);
      expect(question(s, 0).value, const IntegerValue(1234567));
    });

    testWidgets('decimal', (tester) async {
      final s = await one(
        'decimal',
        '<input appearance="thousands-sep"><label>N</label></input>',
      );
      await pump(tester, s);
      await tester.enterText(find.byType(TextField), '12345.5');
      await tester.pump();
      expect(find.text('12,345.5'), findsOneWidget);
      expect(question(s, 0).value, const DecimalValue(12345.5));
    });
  });

  testWidgets('masked hides the text; multiline grows', (tester) async {
    await pump(
      tester,
      await one(
        'string',
        '<input appearance="masked"><label>P</label></input>',
      ),
    );
    expect(field(tester).obscureText, isTrue);
    await pump(
      tester,
      await one(
        'string',
        '<input appearance="multiline"><label>M</label></input>',
      ),
    );
    expect(field(tester).obscureText, isFalse);
    expect(field(tester).maxLines, isNull);
  });

  group('dates', () {
    testWidgets('month-year saves the first of the month', (tester) async {
      final s = await one(
        'date',
        '<input appearance="month-year"><label>D</label></input>',
        value: '2020-05-17',
      );
      await pump(tester, s);
      expect(find.text('May 2020'), findsOneWidget);
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('month')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('March').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(question(s, 0).value, DateValue(DateTime(2020, 3)));
      expect(find.text('March 2020'), findsOneWidget);
    });

    testWidgets('year saves January 1st', (tester) async {
      final s = await one(
        'date',
        '<input appearance="year"><label>D</label></input>',
        value: '2020-05-17',
      );
      await pump(tester, s);
      expect(find.text('2020'), findsOneWidget);
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('month')), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(question(s, 0).value, DateValue(DateTime(2020)));
    });

    testWidgets('no-calendar types the date', (tester) async {
      final s = await one(
        'date',
        '<input appearance="no-calendar"><label>D</label></input>',
        value: '2020-05-17',
      );
      await pump(tester, s);
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(question(s, 0).value, DateValue(DateTime(2020, 5, 17)));
    });
  });

  group('range', () {
    String range(String appearance) =>
        '<range start="1" end="5" step="1" appearance="$appearance">'
        '<label>R</label></range>';

    testWidgets('default slider shows start and end', (tester) async {
      await pump(tester, await one('int', range('')));
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('rating: stars', (tester) async {
      final s = await one('int', range('rating'));
      await pump(tester, s);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      await tester.tap(find.byTooltip('3'));
      await tester.pump();
      expect(question(s, 0).value, const IntegerValue(3));
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('picker: a drop-down of the values', (tester) async {
      final s = await one('int', range('picker'));
      await pump(tester, s);
      await tester.tap(find.byType(DropdownButtonFormField<double>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      expect(question(s, 0).value, const IntegerValue(4));
    });

    testWidgets('vertical and no-ticks', (tester) async {
      await pump(tester, await one('int', range('vertical')));
      expect(
        find.ancestor(
          of: find.byType(Slider),
          matching: find.byType(RotatedBox),
        ),
        findsOneWidget,
      );
      await pump(tester, await one('int', range('no-ticks')));
      final theme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byType(Slider),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(theme.data.tickMarkShape, SliderTickMarkShape.noTickMark);
    });
  });
}
