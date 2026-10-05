// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

typedef _Call = ({String intent, Map<String, Object?> params, String? data});

class _AppDelegates extends XFormDelegates {
  _AppDelegates({this.result, this.missing = false});

  final Map<String, Object?>? result;
  final bool missing;
  final List<_Call> calls = [];
  final List<String> printed = [];

  @override
  bool get canLaunchExternalApps => true;

  @override
  bool get canPrint => true;

  @override
  Future<Map<String, Object?>?> launchExternalApp(
    BuildContext context, {
    required String intent,
    required Map<String, Object?> params,
    String? data,
  }) async {
    calls.add((intent: intent, params: params, data: data));
    if (missing) throw const ExternalAppNotFoundException();
    return result;
  }

  @override
  Future<void> print(BuildContext context, String content) async =>
      printed.add(content);
}

Future<void> _pump(
  WidgetTester tester,
  FormSession s,
  XFormDelegates delegates, {
  XFormMode mode = XFormMode.scroll,
}) => tester.pumpWidget(
  app(XFormView(session: s, mode: mode, delegates: delegates)),
);

void _expectCounterParameters(Map<String, String> result) => expect(result, {
  'form_id': "'counter-form'",
  'form_name': "'Counter Form'",
  'question_id': "'1'",
  'question_name': "'Counter 1'",
  'increment': 'true()',
});

void main() {
  // Collect's ExternalAppUtilsTest.
  group('ExternalAppsUtils', () {
    test('extractIntentName', () {
      for (final spec in [
        "org.opendatakit.counter(form_id='counter-form', increment=true())",
        'org.opendatakit.counter()',
        'org.opendatakit.counter',
      ]) {
        expect(
          ExternalAppsUtils.extractIntentName(spec),
          'org.opendatakit.counter',
        );
      }
    });

    test('extractParameters', () {
      _expectCounterParameters(
        ExternalAppsUtils.extractParameters(
          "org.opendatakit.counter(form_id='counter-form', form_name='Counter "
          "Form', question_id='1', question_name='Counter 1', "
          'increment=true())',
        ),
      );
      _expectCounterParameters(
        ExternalAppsUtils.extractParameters(
          "org.opendatakit.counter(form_id='counter-form',form_name='Counter "
          "Form',question_id='1',question_name='Counter 1',increment=true())",
        ),
      );
      _expectCounterParameters(
        ExternalAppsUtils.extractParameters(
          "   org.opendatakit.counter ( form_id = 'counter-form' , form_name "
          "= 'Counter Form' , question_id = '1' , question_name = 'Counter 1' "
          ', increment = true()   )   ',
        ),
      );
      expect(
        ExternalAppsUtils.extractParameters(
          "org.companyX.appX(parameter1='value1', "
          "parameter2='value2a, value2b'",
        ),
        {'parameter1': "'value1'", 'parameter2': "'value2a, value2b'"},
      );
      expect(
        ExternalAppsUtils.extractParameters(
          'android.intent.action.SENDTO(sms_body= /send/message , '
          'uri_data= /send/send_to )',
        ),
        {'sms_body': '/send/message', 'uri_data': '/send/send_to'},
      );
      expect(
        ExternalAppsUtils.extractParameters(
          'ex:ch.novelt.odkcompanion.OPEN(current_value=/afp/cn, '
          r"match='^[0-9]{4}W[0-9]{2}-[0-9]{1,5}$', "
          "filter='^AFP:([0-9]{4}W[0-9]{2}-[0-9]{1,5})')",
        ),
        {
          'current_value': '/afp/cn',
          'match': r"'^[0-9]{4}W[0-9]{2}-[0-9]{1,5}$'",
          'filter': "'^AFP:([0-9]{4}W[0-9]{2}-[0-9]{1,5})'",
        },
      );
      // Java's split drops trailing empty strings.
      expect(ExternalAppsUtils.extractParameters('a(b=, c=d)'), {'c': 'd'});
    });

    test('as...Data', () {
      expect(ExternalAppsUtils.asStringData(null), isNull);
      expect(
        ExternalAppsUtils.asStringData(' Test Value 4 '),
        const StringValue(' Test Value 4 '),
      );
      expect(ExternalAppsUtils.asIntegerData(''), isNull);
      expect(ExternalAppsUtils.asIntegerData('5.4'), isNull);
      expect(ExternalAppsUtils.asIntegerData('-5'), const IntegerValue(-5));
      expect(ExternalAppsUtils.asDecimalData('5..24'), isNull);
      expect(ExternalAppsUtils.asDecimalData('5.24c'), isNull);
      expect(ExternalAppsUtils.asDecimalData('05'), const DecimalValue(5));
      expect(
        ExternalAppsUtils.asDecimalData('-27.333'),
        const DecimalValue(-27.333),
      );
    });

    test('getValueRepresentedBy (Collect ExternalAppsUtilsTest)', () async {
      final s = await formSession(
        '<label/><rep><name/></rep>',
        '',
        '<input ref="/data/label"><label>L</label></input>'
            '<repeat nodeset="/data/rep"><input ref="/data/rep/name">'
            '<label>N</label></input></repeat>',
      );
      s.answer(question(s, 0).index, const StringValue('foo'));
      final rep = s.root.children[1] as RepeatNode;
      final name = rep.instances.first.children.first as QuestionNode;
      s.answer(name.index, const StringValue('bar'));
      final form = s.definition.formDef;
      Object? value(String text, String ref) =>
          ExternalAppsUtils.getValueRepresentedBy(
            text,
            ref == '/data/label' ? question(s, 0).ref : name.ref,
            form,
          );
      expect(value('../name', '/data/rep[1]/name'), 'bar');
      expect(value('../label', '/data/label'), 'foo');
      expect(value('/data/label', '/data/rep[1]/name'), 'foo');
      expect(value('true()', '/data/rep[1]/name'), true);
      expect(value("'hello'", '/data/rep[1]/name'), 'hello');
      expect(value("'open", '/data/label'), 'open');
      expect(value('instanceProviderID()', '/data/label'), '-1');
    });
  });

  test('externalAppSpec', () {
    expect(
      externalAppSpec("ex:a.B(x='1 2', y=/data/q) thousands-sep"),
      "a.B(x='1 2', y=/data/q)",
    );
    expect(externalAppSpec('thousands-sep ex:a.B other'), 'a.B');
    expect(externalAppSpec('minimal'), isNull);
    final a = Appearance.parse("ex:a.B(x='1 2') thousands-sep");
    expect(a.tokens, {'ex:', 'thousands-sep'});
    expect(a.unknown, isEmpty);
  });

  Future<FormSession> exForm(String type, {String value = ''}) => formSession(
    '<other>7</other><q>$value</q>',
    '<bind nodeset="/data/q" type="$type"/>'
        '<bind nodeset="/data/other" type="int"/>',
    '<input ref="/data/q" appearance="'
        "ex:org.app.ACTION(k='v', n=/data/other, uri_data='tel:1') "
        'thousands-sep"><label ref="jr:itext(\'q\')"/></input>',
    itext:
        '<itext><translation lang="en"><text id="q"><value>Q</value>'
        '<value form="buttonText">Get it</value>'
        '<value form="noAppErrorString">No app here</value>'
        '</text></translation></itext>',
  );

  testWidgets('ex: integer: parameters, value in and out', (tester) async {
    final s = await exForm('int', value: '1234');
    final delegates = _AppDelegates(result: {'value': '56789'});
    await _pump(tester, s, delegates);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Get it'));
    await tester.pump();
    final call = delegates.calls.single;
    expect(call.intent, 'org.app.ACTION');
    expect(call.params, {'k': 'v', 'n': 7.0, 'value': 1234});
    expect(call.data, 'tel:1');
    expect(question(s, 0).value, const IntegerValue(56789));
    expect(find.text('56,789'), findsOneWidget);
  });

  testWidgets('ex: decimal and text', (tester) async {
    var s = await exForm('decimal');
    var delegates = _AppDelegates(result: {'value': 2.5});
    await _pump(tester, s, delegates);
    await tester.tap(find.text('Get it'));
    await tester.pump();
    expect(question(s, 0).value, const DecimalValue(2.5));
    s = await exForm('string', value: 'old');
    delegates = _AppDelegates(result: {'value': 'new'});
    await _pump(tester, s, delegates);
    await tester.tap(find.text('Get it'));
    await tester.pump();
    expect(delegates.calls.single.params['value'], 'old');
    expect(question(s, 0).value, const StringValue('new'));
  });

  testWidgets('ex: missing app allows typing', (tester) async {
    final s = await exForm('string');
    await _pump(tester, s, _AppDelegates(missing: true));
    await tester.tap(find.text('Get it'));
    await tester.pump();
    expect(find.text('No app here'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'typed');
    expect(question(s, 0).value, const StringValue('typed'));
  });

  testWidgets('ex: without delegates is a text field', (tester) async {
    await _pump(tester, await exForm('string'), const NoDelegates());
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Get it'), findsNothing);
  });

  testWidgets('printer prints the answer', (tester) async {
    for (final appearance in ['printer', 'printer:org.zebra.PRINT']) {
      final s = await formSession(
        '<q>&lt;b&gt;hi&lt;/b&gt;</q>',
        '<bind nodeset="/data/q" type="string" readonly="true()"/>',
        '<input ref="/data/q" appearance="$appearance"><label>P</label></input>',
      );
      final delegates = _AppDelegates();
      await _pump(tester, s, delegates);
      await tester.tap(find.text('Print'));
      await tester.pump();
      expect(delegates.printed, ['<b>hi</b>']);
    }
  });

  Future<FormSession> intentForm({String appearance = 'field-list'}) =>
      formSession(
        '<g><t>a</t><n>3</n><d/><when/></g>',
        '<bind nodeset="/data/g/t" type="string"/>'
            '<bind nodeset="/data/g/n" type="int"/>'
            '<bind nodeset="/data/g/d" type="decimal"/>'
            '<bind nodeset="/data/g/when" type="date"/>',
        '<group ref="/data/g" appearance="$appearance" '
            "intent=\"org.app.FILL(mode='x', t2=t)\">"
            '<label ref="jr:itext(\'g\')"/>'
            '<input ref="/data/g/t"><label>T</label></input>'
            '<input ref="/data/g/n"><label>N</label></input>'
            '<input ref="/data/g/d"><label>D</label></input>'
            '<input ref="/data/g/when"><label>W</label></input></group>',
        itext:
            '<itext><translation lang="en"><text id="g"><value>G</value>'
            '<value form="buttonText">Fill</value></text></translation>'
            '</itext>',
      );

  QuestionNode inGroup(FormSession s, int i) =>
      (s.root.children.first as GroupNode).children[i] as QuestionNode;

  testWidgets('intent group: answers out, results in', (tester) async {
    final s = await intentForm();
    final delegates = _AppDelegates(
      result: {'t': 'b', 'n': '42', 'd': 'x', 'unknown': 1, 'when': null},
    );
    await _pump(tester, s, delegates);
    await tester.tap(find.text('Fill'));
    await tester.pump();
    final call = delegates.calls.single;
    expect(call.intent, 'org.app.FILL');
    expect(call.params, {'mode': 'x', 't2': 'a', 't': 'a', 'n': 3, 'd': null});
    expect(inGroup(s, 0).value, const StringValue('b'));
    expect(inGroup(s, 1).value, const IntegerValue(42));
    expect(inGroup(s, 2).value, isNull);
  });

  testWidgets('intent group questions are read-only', (tester) async {
    final s = await intentForm();
    await _pump(tester, s, _AppDelegates());
    await tester.enterText(find.byType(TextField).first, 'typed');
    expect(inGroup(s, 0).value, const StringValue('a'));
  });

  testWidgets('intent group: values the app cannot set', (tester) async {
    final s = await intentForm();
    await _pump(tester, s, _AppDelegates(result: {'when': '2020-01-01'}));
    await tester.tap(find.text('Fill'));
    await tester.pump();
    expect(
      find.text("Cannot assign the value at '/data/g/when'."),
      findsOneWidget,
    );
  });

  testWidgets('intent group in pager mode: one question per screen', (
    tester,
  ) async {
    final s = await intentForm(appearance: '');
    final delegates = _AppDelegates(result: {'t': 'z'});
    await _pump(tester, s, delegates, mode: XFormMode.pager);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill'));
    await tester.pump();
    expect(delegates.calls.single.params, {'mode': 'x', 't2': 'a', 't': 'a'});
    expect(inGroup(s, 0).value, const StringValue('z'));
  });
}
