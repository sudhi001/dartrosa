// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _fruit = ['Apple', 'Banana', 'Cherry', 'Date', 'Elder'];

Future<FormSession> select(
  String appearance, {
  bool multi = false,
  String extra = '',
}) => formSession(
  '<q/><r/>',
  '<bind nodeset="/data/q" type="string"/>'
      '<bind nodeset="/data/r" type="string"/>',
  '<${multi ? 'select' : 'select1'} ref="/data/q" appearance="$appearance">'
      '<label>Fruit</label>${items(_fruit)}</${multi ? 'select' : 'select1'}>'
      '<input ref="/data/r"><label>Next one</label></input>$extra',
);

Future<void> pumpScroll(WidgetTester tester, FormSession s) =>
    tester.pumpWidget(app(XFormView(session: s, mode: XFormMode.scroll)));

double dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  setUp(Appearance.resetWarnings);

  group('Appearance.parse', () {
    test('tokens, columns and aliases', () {
      final a = Appearance.parse('Columns-3 quickcompact');
      expect(a.columnCount, 3);
      expect(a.has('quick') && a.has('no-buttons'), isTrue);
      expect(Appearance.parse('compact-2').columnCount, 2);
      expect(Appearance.parse('horizontal').has('columns'), isTrue);
      expect(Appearance.parse('horizontal-compact').hasColumns, isTrue);
      expect(
        Appearance.parse("search('f', 'matches', 'a', 'b')").unknown,
        isEmpty,
      );
      expect(Appearance.parse('w2 field-list foo').unknown, ['foo']);
      expect(Appearance.parse('ethiopian month-year').unknown, isEmpty);
    });
  });

  testWidgets('default: radio list, tap selects and re-tap clears', (
    tester,
  ) async {
    final s = await select('');
    await pumpScroll(tester, s);
    expect(find.byType(Radio<String>), findsNWidgets(5));
    await tester.tap(find.text('Banana'));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'banana');
    await tester.tap(find.text('Banana'));
    await tester.pump();
    expect(question(s, 0).value, isNull);
  });

  testWidgets('columns-N lays choices out in N columns', (tester) async {
    final s = await select('columns-3');
    await pumpScroll(tester, s);
    expect(dy(tester, 'Apple'), dy(tester, 'Cherry'));
    expect(dy(tester, 'Date'), greaterThan(dy(tester, 'Apple')));
    expect(dy(tester, 'Date'), dy(tester, 'Elder'));
    expect(
      tester.getTopLeft(find.text('Date')).dx,
      tester.getTopLeft(find.text('Apple')).dx,
    );
  });

  testWidgets('columns fits ~180dp columns; columns-pack wraps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScroll(tester, await select('columns'));
    // (800 - 32 padding) / 180 = 4 columns.
    expect(dy(tester, 'Apple'), dy(tester, 'Date'));
    expect(dy(tester, 'Elder'), greaterThan(dy(tester, 'Apple')));

    await pumpScroll(tester, await select('columns-pack'));
    expect(find.byType(Wrap), findsOneWidget);
    expect(dy(tester, 'Apple'), dy(tester, 'Elder'));
  });

  testWidgets('no-buttons: tiles without radios, multi too', (tester) async {
    final s = await select('no-buttons');
    await pumpScroll(tester, s);
    expect(find.byType(Radio<String>), findsNothing);
    await tester.tap(find.text('Cherry'));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'cherry');

    final m = await select('no-buttons columns-2', multi: true);
    await pumpScroll(tester, m);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Apple'));
    await tester.pump();
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(question(m, 0).value?.displayText, 'apple, date');
  });

  testWidgets('likert: radios side by side above labels', (tester) async {
    final s = await select('likert');
    await pumpScroll(tester, s);
    final radios = find.byType(Radio<String>);
    expect(radios, findsNWidgets(5));
    expect(
      tester.getCenter(radios.at(0)).dy,
      tester.getCenter(radios.at(4)).dy,
    );
    expect(dy(tester, 'Apple'), greaterThan(tester.getCenter(radios.at(0)).dy));
    await tester.tap(find.text('Elder'));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'elder');
  });

  testWidgets('autocomplete filters choices by label', (tester) async {
    final s = await select('autocomplete');
    await pumpScroll(tester, s);
    await tester.enterText(find.byType(TextField).first, 'an');
    await tester.pump();
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    await tester.tap(find.text('Banana'));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'banana');

    final m = await select('autocomplete', multi: true);
    await pumpScroll(tester, m);
    await tester.enterText(find.byType(TextField).first, 'ERR');
    await tester.pump();
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.text('Cherry'));
    await tester.pump();
    expect(question(m, 0).value?.displayText, 'cherry');
  });

  testWidgets('quick advances to the next screen in pager mode', (
    tester,
  ) async {
    final s = await select('quick');
    await tester.pumpWidget(app(XFormView(session: s)));
    expect(find.text('Fruit'), findsOneWidget);
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'date');
    expect(find.text('Next one'), findsOneWidget);
    expect(find.text('Fruit'), findsNothing);
  });

  testWidgets('quick does not advance in scroll mode', (tester) async {
    final s = await select('quick');
    await pumpScroll(tester, s);
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(find.text('Fruit'), findsOneWidget);
  });

  testWidgets('minimal select multiple: dialog of check boxes', (tester) async {
    final s = await select('minimal', multi: true);
    await pumpScroll(tester, s);
    await tester.tap(find.byType(InputDecorator).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pump();
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).where((c) => c.value!),
      hasLength(2),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(question(s, 0).value?.displayText, 'banana, date');
    expect(find.text('Banana, Date'), findsOneWidget);
  });

  testWidgets('minimal select one: dropdown', (tester) async {
    final s = await select('minimal');
    await pumpScroll(tester, s);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cherry').last);
    await tester.pumpAndSettle();
    expect(question(s, 0).value?.displayText, 'cherry');
  });

  testWidgets('list: choices side by side with labels and buttons', (
    tester,
  ) async {
    final s = await select('list');
    await pumpScroll(tester, s);
    expect(dy(tester, 'Apple'), dy(tester, 'Elder'));
    expect(find.byType(Radio<String>), findsNWidgets(5));
    await tester.tap(find.byType(Radio<String>).at(1));
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'banana');
  });

  testWidgets('label and list-nolabel rows', (tester) async {
    final s = await formSession(
      '<g><h/><a/><b/></g>',
      '<bind nodeset="/data/g/h" type="string"/>'
          '<bind nodeset="/data/g/a" type="string"/>'
          '<bind nodeset="/data/g/b" type="string"/>',
      '<group ref="/data/g" appearance="field-list">'
          '<select1 ref="/data/g/h" appearance="label"><label></label>'
          '${items(['Yes', 'No'])}</select1>'
          '<select1 ref="/data/g/a" appearance="list-nolabel">'
          '<label>Rain</label>${items(['Yes', 'No'])}</select1>'
          '<select ref="/data/g/b" appearance="list-nolabel">'
          '<label>Snow</label>${items(['Yes', 'No'])}</select></group>',
    );
    await pumpScroll(tester, s);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNWidgets(2));
    expect(find.byType(Checkbox), findsNWidgets(2));
    // Buttons line up under the header labels.
    expect(
      tester.getCenter(find.byType(Radio<String>).at(1)).dx,
      closeTo(tester.getCenter(find.text('No')).dx, 1),
    );
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    final g = s.root.children[0] as GroupNode;
    expect((g.children[2] as QuestionNode).value?.displayText, 'yes');
  });

  testWidgets('table-list group: one grid with a header', (tester) async {
    final s = await formSession(
      '<g><a/><b/></g><z/>',
      '<bind nodeset="/data/g/a" type="string"/>'
          '<bind nodeset="/data/g/b" type="string"/>'
          '<bind nodeset="/data/z" type="string"/>',
      '<group ref="/data/g" appearance="table-list">'
          '<select1 ref="/data/g/a"><label>Rain</label>'
          '${items(['Often', 'Never'])}</select1>'
          '<select1 ref="/data/g/b"><label>Snow</label>'
          '${items(['Often', 'Never'])}</select1></group>'
          '<input ref="/data/z"><label>After</label></input>',
    );
    await tester.pumpWidget(app(XFormView(session: s)));
    // Pager: the whole table on one screen.
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('Snow'), findsOneWidget);
    expect(find.text('Often'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNWidgets(4));
    await tester.tap(find.byType(Radio<String>).at(3));
    await tester.pump();
    final g = s.root.children[0] as GroupNode;
    expect((g.children[1] as QuestionNode).value?.displayText, 'never');
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('choice images come from the delegates', (tester) async {
    final s = await formSession(
      '<q/>',
      '<bind nodeset="/data/q" type="string"/>',
      '<select1 ref="/data/q" appearance="no-buttons"><label>Pet</label>'
          '<item><label ref="jr:itext(\'cat\')"/><value>cat</value></item>'
          '<item><label>Dog</label><value>dog</value></item></select1>',
      itext:
          '<itext><translation lang="en"><text id="cat">'
          '<value>Cat</value><value form="image">jr://images/cat.png</value>'
          '</text></translation></itext>',
    );
    await tester.pumpWidget(
      app(
        XFormView(
          session: s,
          mode: XFormMode.scroll,
          delegates: const ImageDelegates(),
        ),
      ),
    );
    // no-buttons shows the image instead of the label text.
    expect(find.bySemanticsLabel('Cat'), findsOneWidget);
    expect(find.text('Cat'), findsNothing);
    expect(find.text('Dog'), findsOneWidget);
    await tester.tap(
      find.ancestor(of: find.byType(Image), matching: find.byType(InkWell)),
    );
    await tester.pump();
    expect(question(s, 0).value?.displayText, 'cat');
  });

  testWidgets('unknown appearance: default widget, warned once', (
    tester,
  ) async {
    final printed = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    final s = await select('fancy-thing', extra: '');
    await pumpScroll(tester, s);
    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(find.byType(Radio<String>), findsNWidgets(5));
    debugPrint = original;
    expect(printed.where((m) => m!.contains('fancy-thing')), hasLength(1));
  });

  testWidgets('overrides match any appearance token', (tester) async {
    final s = await select('likert quick');
    await tester.pumpWidget(
      app(
        XFormView(
          session: s,
          mode: XFormMode.scroll,
          widgetOverrides: {
            'selectOne:likert': (context, node) => const Text('custom'),
          },
        ),
      ),
    );
    expect(find.text('custom'), findsOneWidget);
  });
}
