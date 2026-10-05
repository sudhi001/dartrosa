// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The exceptions the session API throws can be caught by type with only
// package:dartrosa/dartrosa.dart imported.
import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"';

String _form({String binds = '', String itext = ''}) =>
    '<h:html $_ns><h:head><h:title>T</h:title><model>'
    '<instance><data id="f"><a/><b/></data></instance>'
    '$itext<bind nodeset="/data/a" type="string"/>$binds</model></h:head>'
    '<h:body><input ref="/data/a"><label>A</label></input></h:body></h:html>';

const _translations =
    '<itext><translation lang="en"><text id="t"><value>A</value></text>'
    '</translation></itext>';

void main() {
  test('createSession: an unknown function in a calculate', () async {
    final definition = await FormDefinition.parse(
      _form(binds: '<bind nodeset="/data/b" calculate="nope(1)"/>'),
    );
    expect(
      definition.createSession,
      throwsA(
        isA<TriggerableEvaluationException>()
            .having((e) => e.message, 'message', contains("field 'b'"))
            .having((e) => e.cause, 'cause', isA<XPathUnhandledException>()),
      ),
    );
  });

  test('answer: a calculate failing on the new value', () async {
    final definition = await FormDefinition.parse(
      _form(
        binds:
            '<bind nodeset="/data/b" '
            'calculate="if(/data/a = \'x\', nope(1), 0)"/>',
      ),
    );
    final session = definition.createSession();
    final a = session.root.visibleChildren.single.index;
    expect(
      () => session.answer(a, const StringValue('x')),
      throwsA(isA<TriggerableEvaluationException>()),
    );
  });

  test('answer and finalize: a failing constraint', () async {
    final definition = await FormDefinition.parse(
      _form(binds: '<bind nodeset="/data/a" constraint="nope(.)"/>'),
    );
    final session = definition.createSession();
    final a = session.root.visibleChildren.single.index;
    expect(
      () => session.answer(a, const StringValue('x')),
      throwsA(isA<XPathException>()),
    );
    session.answer(a, const StringValue('x'), validate: false);
    expect(session.finalize, throwsA(isA<XPathException>()));
  });

  test('createSession: malformed existing instance XML', () async {
    final definition = await FormDefinition.parse(_form());
    expect(
      () => definition.createSession(existingInstance: '<data><a>'),
      throwsA(isA<XFormParseException>()),
    );
    expect(
      () => definition.createSession(existingInstance: ''),
      throwsA(
        isA<XFormParseException>().having(
          (e) => e.message,
          'message',
          startsWith('XML Syntax Error'),
        ),
      ),
    );
  });

  test('createSession: an instance of another form', () async {
    final definition = await FormDefinition.parse(_form());
    expect(
      () => definition.createSession(existingInstance: '<other><a/></other>'),
      throwsStateError,
    );
  });

  test('an unknown language', () async {
    final definition = await FormDefinition.parse(_form(itext: _translations));
    expect(
      () => definition.createSession(language: 'xx'),
      throwsA(isA<UnregisteredLocaleException>()),
    );
    final session = definition.createSession();
    expect(
      () => session.language = 'xx',
      throwsA(isA<UnregisteredLocaleException>()),
    );
    expect(session.language, 'en');
  });

  test('a failed createSession leaves the definition usable', () async {
    final definition = await FormDefinition.parse(_form(itext: _translations));
    expect(
      () => definition.createSession(language: 'xx'),
      throwsA(isA<UnregisteredLocaleException>()),
    );
    final session = definition.createSession(language: 'en');
    expect(session.isClosed, isFalse);
  });

  test('parse: a jr:itext() label without translations', () {
    expect(
      FormDefinition.parse(
        '<h:html $_ns><h:head><h:title>T</h:title><model>'
        '<instance><data id="f"><a/></data></instance></model></h:head>'
        '<h:body><input ref="/data/a"><label ref="jr:itext(\'a\')"/></input>'
        '</h:body></h:html>',
      ),
      throwsA(
        isA<XFormParseException>().having(
          (e) => e.message,
          'message',
          contains('no <itext>'),
        ),
      ),
    );
  });
}
