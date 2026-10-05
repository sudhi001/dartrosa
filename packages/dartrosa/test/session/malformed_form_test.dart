// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Forms missing their structure fail with a typed parse error.
import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml"';

const _model =
    '<model><instance><data id="f"><a/></data></instance>'
    '<bind nodeset="/data/a" type="string"/></model>';

const _body = '<h:body><input ref="/data/a"><label>A</label></input></h:body>';

Matcher _parseError(Object message) => throwsA(
  isA<XFormParseException>().having((e) => e.message, 'message', message),
);

final _noMainInstance = contains('no main instance');

void main() {
  group('FormDefinition.parse', () {
    test('no <model>', () {
      expect(
        FormDefinition.parse(
          '<h:html $_ns><h:head><h:title>T</h:title></h:head>$_body</h:html>',
        ),
        _parseError(_noMainInstance),
      );
    });

    test('no <model> and no body', () {
      expect(
        FormDefinition.parse(
          '<h:html $_ns><h:head><h:title>T</h:title></h:head></h:html>',
        ),
        _parseError(_noMainInstance),
      );
    });

    test('a <model> without <instance>', () {
      expect(
        FormDefinition.parse(
          '<h:html $_ns><h:head><h:title>T</h:title><model/></h:head>'
          '<h:body/></h:html>',
        ),
        _parseError(_noMainInstance),
      );
    });

    test('binds but no <instance>', () {
      expect(
        FormDefinition.parse(
          '<h:html $_ns><h:head><h:title>T</h:title>'
          '<model><bind nodeset="/data/a" type="string"/></model>'
          '</h:head><h:body/></h:html>',
        ),
        _parseError(_noMainInstance),
      );
    });

    test('no <h:head>', () {
      expect(
        FormDefinition.parse('<h:html $_ns>$_body</h:html>'),
        _parseError(_noMainInstance),
      );
    });

    test('<h:html> alone', () {
      expect(
        FormDefinition.parse('<h:html $_ns/>'),
        _parseError(_noMainInstance),
      );
    });

    test('a document that is not an XForm', () {
      expect(FormDefinition.parse('<foo/>'), _parseError(_noMainInstance));
    });

    test('the body before the model', () {
      expect(
        FormDefinition.parse(
          '<h:html $_ns>$_body<h:head><h:title>T</h:title>$_model</h:head>'
          '</h:html>',
        ),
        _parseError(_noMainInstance),
      );
    });

    test('an empty document', () {
      expect(FormDefinition.parse(''), _parseError(startsWith('XML Syntax')));
    });

    test('whitespace only', () {
      expect(
        FormDefinition.parse('  \n '),
        _parseError(startsWith('XML Syntax')),
      );
    });

    test('text that is not XML', () {
      expect(
        FormDefinition.parse('hello world'),
        _parseError(startsWith('XML Syntax')),
      );
    });

    test('truncated XML', () {
      expect(
        FormDefinition.parse('<h:html $_ns><h:head>'),
        _parseError(isNotEmpty),
      );
    });

    test('no body is a valid (empty) form', () async {
      final definition = await FormDefinition.parse(
        '<h:html $_ns><h:head><h:title>T</h:title>$_model</h:head></h:html>',
      );
      final session = definition.createSession();
      expect(session.root.children, isEmpty);
      expect(session.finalize(), isA<FinalizeSuccess>());
    });
  });
}
