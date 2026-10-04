import 'dart:convert';

import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _csv = 'name,label,image\nmango,Mango,mango.png\napple,Apple,\n';

String _form(String control, String appearance) =>
    '<?xml version="1.0"?><h:html xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"><h:head><h:title>T</h:title>'
    '<model><itext><translation lang="en"><text id="c">'
    '<value>label</value><value form="image">jr://images/image</value>'
    '</text></translation></itext><instance><data id="t"><q/></data></instance></model></h:head>'
    '<h:body><$control ref="/data/q" appearance="$appearance">'
    '<label>Fruit</label>'
    '<item><label ref="jr:itext(\'c\')"/><value>name</value></item>'
    '</$control></h:body></h:html>';

Future<FormSession> _session(
  String control,
  String appearance, {
  bool withCsv = true,
}) async {
  final definition = await FormDefinition.parse(
    _form(control, appearance),
    config: DartRosaConfig(
      resolver: MapResourceResolver({
        if (withCsv) 'jr://file/fruits.csv': utf8.encode(_csv),
      }),
      plugins: [
        ExternalDataPlugin(listMedia: (_) => [if (withCsv) 'fruits.csv']),
      ],
    ),
  );
  return definition.createSession();
}

class _Images extends XFormDelegates {
  const _Images();

  @override
  ImageProvider? image(String uri) {
    uris.add(uri);
    return MemoryImage(transparentPng);
  }

  static final List<String> uris = [];
}

Future<void> _pump(WidgetTester tester, FormSession s) => tester.pumpWidget(
  app(
    XFormView(session: s, mode: XFormMode.scroll, delegates: const _Images()),
  ),
);

void main() {
  testWidgets('search(): choices from the CSV', (tester) async {
    final s = await tester.runAsync(
      () => _session('select1', "search('fruits')"),
    );
    await _pump(tester, s!);
    expect(find.text('Mango'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(_Images.uris, contains('jr://images/mango.png'));
    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(question(s, 0).value!.displayText, 'apple');
  });

  testWidgets('search() with autocomplete filters', (tester) async {
    final s = await tester.runAsync(
      () => _session('select', "autocomplete search('fruits')"),
    );
    await _pump(tester, s!);
    await tester.enterText(find.byType(TextField), 'man');
    await tester.pump();
    expect(find.text('Mango'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    await tester.tap(find.text('Mango'));
    await tester.pump();
    expect(question(s, 0).value!.displayText, 'mango');
  });

  testWidgets('search() with minimal', (tester) async {
    final s = await tester.runAsync(
      () => _session('select1', "minimal search('fruits')"),
    );
    await _pump(tester, s!);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mango').last);
    await tester.pumpAndSettle();
    expect(question(s, 0).value!.displayText, 'mango');
  });

  testWidgets('a missing CSV shows a warning', (tester) async {
    final s = await tester.runAsync(
      () => _session('select1', "search('fruits')", withCsv: false),
    );
    await _pump(tester, s!);
    expect(find.text('File: jr://file/fruits.csv is missing.'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNothing);
  });

  test('bare search is autocomplete', () {
    expect(Appearance.parse('search').has('autocomplete'), isTrue);
    expect(Appearance.parse("search('a b')").has('autocomplete'), isFalse);
  });
}
