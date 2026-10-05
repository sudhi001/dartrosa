// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// parseTreeElement reads XML events instead of a DOM (for speed); these
// tests check that it builds exactly what the DOM-based parser builds and
// fails the same way.
library;

import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/xml/tree_element_parser.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Everything parsing sets on [e] and its subtree, as text.
String dump(TreeElement e, [String indent = '']) {
  final out = StringBuffer(
    '$indent${e.name}[${e.multiplicity}] ${e.instanceName}'
    ' value=${e.value?.displayText}',
  );
  for (final a in e.attributes) {
    out.write(' {${a.namespace}}${a.name}=${a.attributeValue}');
  }
  out.writeln();
  for (final child in e.children) {
    out.write(dump(child, '$indent  '));
  }
  return out.toString();
}

/// The result of [parse] on [xml]: the dump, or the error's type and text.
String outcome(TreeElement Function(String xml) parse, String xml) {
  try {
    return dump(parse(xml));
  } on Object catch (e) {
    return 'error ${e.runtimeType}: $e';
  }
}

String viaDom(String xml) => outcome(
  (xml) => parseTreeElementFrom(
    XmlDocument.parse(xml).rootElement,
    multiplicity: 2,
    instanceId: 'towns',
  ),
  xml,
);

String viaEvents(String xml) => outcome(
  (xml) => parseTreeElement(xml, multiplicity: 2, instanceId: 'towns'),
  xml,
);

void main() {
  const documents = {
    'items': '<?xml version="1.0"?><!-- c --><root><item><name>a</name>'
        '<label> A </label></item><item><name>b</name><label>B</label>'
        '</item><other/><item><name>c</name></item></root>',
    'attributes and namespaces':
        '<r xmlns="urn:d" xmlns:x="urn:x" x:a="1" b="2"><x:c x:d="3"/>'
        '<e xmlns:y="urn:y" y:f="4"><y:g xml:lang="en">t</y:g></e></r>',
    'text forms': '<r><a>one &amp; <![CDATA[<two>]]><!-- c --> three</a>'
        '<b>  </b><c></c><d><?pi x?></d><e>&#65;&lt;</e></r>',
    'doctype and trailing comment':
        '<!DOCTYPE r><r><a>1</a></r><!-- after -->',
    'undeclared element prefix': '<r><p:a/></r>',
    'undeclared attribute prefix': '<r><a p:b="1"/></r>',
    'prefix declared on a sibling only':
        '<r><a xmlns:p="urn:p"/><p:b/></r>',
    'text before a child': '<r><a>x<b/></a></r>',
    'text after a child': '<r><a><b/>x</a></r>',
    'mismatched tags': '<r><a></b></r>',
    'unclosed': '<r><a>',
    'two roots': '<r/><s/>',
    'undeclared prefix, then malformed': '<r><p:a/><b></c></r>',
    'declaration inside an element': '<r><a><?xml version="1.0"?></a></r>',
    'doctype inside an element': '<r><!DOCTYPE r></r>',
    'empty': '',
  };
  for (final MapEntry(key: description, value: xml) in documents.entries) {
    test(description, () => expect(viaEvents(xml), viaDom(xml)));
  }

  test('a long list', () {
    final xml = StringBuffer('<root>');
    for (var i = 0; i < 500; i++) {
      xml.write('<item><name>n$i</name><v>${i % 7}</v></item>');
    }
    xml.write('</root>');
    expect(viaEvents('$xml'), viaDom('$xml'));
  });
}
