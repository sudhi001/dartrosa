// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _itext =
    '<itext><translation lang="English (en)"><text id="n"><value>Name</value>'
    '</text></translation><translation lang="Arabic (ar)"><text id="n">'
    '<value>الاسم</value></text></translation></itext>';

Future<FormSession> named({String? language}) => formSession(
  '<n/><g><x/></g>',
  '<bind nodeset="/data/n" type="string" required="true()"/>'
      '<bind nodeset="/data/g/x" type="string"/>',
  '<input ref="/data/n"><label ref="jr:itext(\'n\')"/></input>'
      '<group ref="/data/g"><label>Box</label>'
      '<input ref="/data/g/x"><label>X</label></input></group>',
  itext: _itext,
  language: language,
);

class _French extends XFormLocalizations {
  const _French();

  @override
  String get next => 'Suivant';

  @override
  String get requiredDefault => 'Réponse obligatoire';
}

class _FrenchDelegate extends LocalizationsDelegate<XFormLocalizations> {
  const _FrenchDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<XFormLocalizations> load(Locale locale) =>
      SynchronousFuture(const _French());

  @override
  bool shouldReload(_FrenchDelegate old) => false;
}

void main() {
  test('text direction of form languages', () {
    expect(textDirectionOfLanguage(null), isNull);
    expect(textDirectionOfLanguage('ar'), TextDirection.rtl);
    expect(textDirectionOfLanguage('Arabic (ar)'), TextDirection.rtl);
    expect(textDirectionOfLanguage('fa-IR'), TextDirection.rtl);
    expect(textDirectionOfLanguage('Hebrew'), TextDirection.rtl);
    expect(textDirectionOfLanguage('dv'), TextDirection.rtl);
    expect(textDirectionOfLanguage('English (en)'), TextDirection.ltr);
    expect(textDirectionOfLanguage('French'), TextDirection.ltr);
  });

  testWidgets('RTL follows the form language', (tester) async {
    final s = await named(language: 'Arabic (ar)');
    await tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));
    TextDirection direction() =>
        Directionality.of(tester.element(find.byType(TextField).first));
    expect(find.text('* الاسم'), findsOneWidget);
    expect(direction(), TextDirection.rtl);
    await tester.enterText(find.byType(TextField).first, 'abc');
    s.language = 'English (en)';
    await tester.pump();
    expect(find.text('* Name'), findsOneWidget);
    expect(direction(), TextDirection.ltr);
    // Switching direction keeps the field's state.
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('UI strings come from XFormLocalizations', (tester) async {
    final s = await named();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          _FrenchDelegate(),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: XFormView(session: s)),
      ),
    );
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    expect(find.text('Réponse obligatoire'), findsOneWidget);
    // Unchanged strings keep the English default.
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('XFormTheme styles errors, spacing and cards', (tester) async {
    const errorColor = Color(0xFF123456);
    const cardColor = Color(0xFFABCDEF);
    final s = await named();
    await tester.pumpWidget(
      app(
        XFormView(session: s, mode: XFormMode.scroll),
        theme: ThemeData(
          extensions: const [
            XFormTheme(
              errorColor: errorColor,
              cardColor: cardColor,
              questionSpacing: 20,
            ),
          ],
        ),
      ),
    );
    expect(tester.widget<Card>(find.byType(Card)).color, cardColor);
    await tester.enterText(find.byType(TextField).first, 'a');
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    final error = tester.widget<Text>(
      find.text('Sorry, this response is required!'),
    );
    expect(error.style?.color, errorColor);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.symmetric(vertical: 20),
      ),
      findsWidgets,
    );
  });

  test('XFormTheme copyWith and lerp', () {
    const a = XFormTheme(questionSpacing: 10);
    final b = a.copyWith(questionSpacing: 20, errorColor: Colors.red);
    expect(b.questionSpacing, 20);
    expect(b.errorColor, Colors.red);
    expect(a.lerp(b, 0.5).questionSpacing, 15);
    expect(a.lerp(null, 0.5), same(a));
    expect(a.maxContentWidth, isNull);
    final c = a.copyWith(maxContentWidth: 600);
    expect(c.maxContentWidth, 600);
    expect(c.copyWith(questionSpacing: 1).maxContentWidth, 600);
    expect(c.lerp(a.copyWith(maxContentWidth: 800), 0.5).maxContentWidth, 700);
  });

  test('XFormTheme.pagePaddingFor centers content of maxContentWidth', () {
    const theme = XFormTheme(pagePadding: EdgeInsets.all(16));
    expect(theme.pagePaddingFor(1280), const EdgeInsets.all(16));
    final capped = theme.copyWith(maxContentWidth: 600);
    expect(
      capped.pagePaddingFor(1280),
      const EdgeInsets.fromLTRB(340, 16, 340, 16),
    );
    // Narrower than the maximum: the page padding only.
    expect(capped.pagePaddingFor(400), const EdgeInsets.all(16));
    expect(capped.pagePaddingFor(double.infinity), const EdgeInsets.all(16));
  });
}
