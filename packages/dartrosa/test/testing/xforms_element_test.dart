// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('builds a well-formed form with the standard namespaces', () {
    final form = html(
      head([
        title('Simple'),
        model([
          mainInstance([
            t('data id="simple"', [t('age'), t('name')]),
          ]),
          bind('/data/age')
            ..type('int')
            ..required()
            ..constraint('. > 0'),
        ]),
      ]),
      body([
        input('/data/age', [label('Age')]),
        input('/data/name'),
      ]),
    );

    final xml = form.asXml();
    expect(xml, startsWith('<?xml version="1.0"?><h:html xmlns='));

    final doc = XmlDocument.parse(xml);
    final bindEl = doc.findAllElements('bind').single;
    expect(bindEl.getAttribute('nodeset'), '/data/age');
    expect(bindEl.getAttribute('type'), 'int');
    expect(bindEl.getAttribute('required'), 'true()');
    expect(bindEl.getAttribute('constraint'), '. > 0');
    expect(doc.findAllElements('h:title').single.innerText, 'Simple');
  });

  test('spec parsing keeps spaces inside quoted values', () {
    final el = t('input ref="/data/a" appearance="w2 minimal"');
    expect(el.name, 'input');
    expect(el.attributes, {'ref': '/data/a', 'appearance': 'w2 minimal'});
    expect(el.asXml(), '<input ref="/data/a" appearance="w2 minimal"/>');
  });

  test('spec parsing ignores = inside function calls', () {
    final el = t(
      'bind nodeset="/data/a" relevant="selected(/data/b, \'x\')=true()"',
    );
    expect(el.attributes['relevant'], "selected(/data/b, 'x')=true()");
  });

  test('repeat with count and items', () {
    expect(
      repeat('/data/r', [input('/data/r/q')], '/data/n').asXml(),
      '<repeat nodeset="/data/r" jr:count="/data/n"><input ref="/data/r/q"/></repeat>',
    );
    expect(
      item(1, 'One').asXml(),
      '<item><label>One</label><value>1</value></item>',
    );
  });

  test('secondary instance wraps items in root', () {
    expect(
      instance('towns', [t('item')]).asXml(),
      '<instance id="towns"><root><item/></root></instance>',
    );
  });

  test('random titles are unique', () {
    expect(title().asXml(), isNot(title().asXml()));
  });
}
