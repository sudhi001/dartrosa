import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _itext =
    '<itext><translation lang="English (en)">'
    '<text id="q"><value>How was the **visit**?</value></text>'
    '<text id="h"><value>Pick *one*</value></text>'
    '<text id="g"><value>Rows</value></text>'
    '</translation><translation lang="Arabic (ar)">'
    '<text id="q"><value>كيف كانت **الزيارة**؟</value></text>'
    '<text id="h"><value>اختر *واحدا*</value></text>'
    '<text id="g"><value>صفوف</value></text>'
    '</translation></itext>';

/// A field-list screen: a required likert select, a table-list group and
/// a range.
Future<FormSession> _screen(String language) => formSession(
  '<p><q/><t><a/><b/></t><r>2</r></p>',
  '<bind nodeset="/data/p/q" type="string" required="true()"/>'
      '<bind nodeset="/data/p/t/a" type="string"/>'
      '<bind nodeset="/data/p/t/b" type="string"/>'
      '<bind nodeset="/data/p/r" type="int"/>',
  '<group ref="/data/p" appearance="field-list">'
      '<select1 ref="/data/p/q" appearance="likert">'
      '<label ref="jr:itext(\'q\')"/><hint ref="jr:itext(\'h\')"/>'
      '${items(['1', '2', '3', '4'])}</select1>'
      '<group ref="/data/p/t" appearance="table-list">'
      '<label ref="jr:itext(\'g\')"/>'
      '<select1 ref="/data/p/t/a"><label>A</label>${items(['X', 'Y'])}'
      '</select1><select1 ref="/data/p/t/b"><label>B</label>'
      '${items(['X', 'Y'])}</select1></group>'
      '<range ref="/data/p/r" start="1" end="5" step="1"><label>R</label>'
      '</range></group>',
  itext: _itext,
  language: language,
);

Future<void> _golden(
  WidgetTester tester, {
  required String name,
  required Brightness brightness,
  String language = 'English (en)',
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await _screen(language);
  await tester.pumpWidget(
    app(
      XFormView(session: s),
      theme: ThemeData(brightness: brightness),
    ),
  );
  // Show a validation error too.
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(XFormView),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  testWidgets('light LTR', (tester) async {
    await _golden(
      tester,
      name: 'screen_light_ltr',
      brightness: Brightness.light,
    );
  });

  testWidgets('dark LTR', (tester) async {
    await _golden(tester, name: 'screen_dark_ltr', brightness: Brightness.dark);
  });

  testWidgets('light RTL', (tester) async {
    await _golden(
      tester,
      name: 'screen_light_rtl',
      brightness: Brightness.light,
      language: 'Arabic (ar)',
    );
  });
}
