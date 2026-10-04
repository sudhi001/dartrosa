import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Delegates extends XFormDelegates {
  _Delegates({this.bearing});

  final double? bearing;
  final List<Uri> opened = [];

  @override
  bool get canReadBearing => true;

  @override
  Future<double?> compassBearing(BuildContext context) async => bearing;

  @override
  Future<void> openLink(BuildContext context, Uri uri) async => opened.add(uri);
}

Future<FormSession> _one(
  String type,
  String appearance, {
  String value = '',
  bool readonly = false,
}) => formSession(
  '<q>$value</q>',
  '<bind nodeset="/data/q" type="$type"'
      '${readonly ? ' readonly="true()"' : ''}/>',
  '<input ref="/data/q" appearance="$appearance"><label>Q</label></input>',
);

Future<void> _pump(
  WidgetTester tester,
  FormSession s, {
  XFormDelegates delegates = const NoDelegates(),
  Locale? locale,
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('de'), Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: XFormView(session: s, mode: XFormMode.scroll, delegates: delegates),
    ),
  ),
);

void main() {
  testWidgets('url opens the answer through the delegates', (tester) async {
    final s = await _one(
      'string',
      'url',
      value: 'https://getodk.org',
      readonly: true,
    );
    final delegates = _Delegates();
    await _pump(tester, s, delegates: delegates);
    await tester.tap(find.text('Open Url'));
    await tester.pump();
    expect(delegates.opened, [Uri.parse('https://getodk.org')]);
  });

  testWidgets('url without an answer', (tester) async {
    final delegates = _Delegates();
    await _pump(tester, await _one('string', 'url'), delegates: delegates);
    await tester.tap(find.text('Open Url'));
    await tester.pump();
    expect(find.text('No URL set'), findsOneWidget);
    expect(delegates.opened, isEmpty);
  });

  testWidgets('bearing from the compass', (tester) async {
    final s = await _one('decimal', 'bearing');
    await _pump(tester, s, delegates: _Delegates(bearing: 123.45678));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Record Bearing'));
    await tester.pump();
    expect(question(s, 0).value, const DecimalValue(123.457));
    expect(find.text('Replace Bearing'), findsOneWidget);
  });

  testWidgets('bearing without a compass is typed', (tester) async {
    await _pump(tester, await _one('decimal', 'bearing'));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('counter', (tester) async {
    final s = await _one('int', 'counter');
    await _pump(tester, s);
    IconButton button(IconData icon) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
    expect(button(Icons.remove).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(question(s, 0).value, const IntegerValue(1));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(question(s, 0).value, const IntegerValue(0));
    expect(button(Icons.remove).onPressed, isNull);
  });

  testWidgets('counter limits and read-only', (tester) async {
    var s = await _one('int', 'counter', value: '999999999');
    await _pump(tester, s);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    s = await _one('int', 'counter', value: '-3');
    await _pump(tester, s);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(question(s, 0).value, const IntegerValue(1));
    s = await _one('int', 'counter', value: '4', readonly: true);
    await _pump(tester, s);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
  });

  test('thousands separators by locale', () {
    expect(thousandsSeparatorFor('en'), ',');
    expect(thousandsSeparatorFor('de'), ' ');
    expect(thousandsSeparatorFor('fr'), ' ');
    expect(thousandsSeparatorFor('xx-unknown'), ',');
    expect(groupThousands('-1234567.5', ' '), '-1 234 567.5');
  });

  testWidgets('thousands-sep follows the locale', (tester) async {
    final s = await _one('decimal', 'thousands-sep', value: '1234.5');
    await _pump(tester, s, locale: const Locale('de'));
    String text() =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(text(), '1 234.5');
    await tester.enterText(find.byType(TextField), '9876543.25');
    await tester.pump();
    expect(text(), '9 876 543.25');
    expect(question(s, 0).value, const DecimalValue(9876543.25));
  });
}
