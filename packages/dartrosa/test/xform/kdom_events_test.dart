// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// parseKDocument builds its tree from XML events (for speed); these tests
// check that it builds exactly what the DOM-based conversion builds, for
// every XML file of the conformance corpus and for edge cases.
@TestOn('vm')
library;

import 'dart:io';

import 'package:dartrosa/src/xform/kdom.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

/// Everything [parseKDocument] produces for [e], as text.
String dump(KElement e, [String indent = '']) {
  final out = StringBuffer('$indent<{${e.namespace}}${e.name}');
  for (final a in e.attributes) {
    out.write(' {${a.namespace}}${a.name}="${a.value}"');
  }
  for (final (prefix, uri) in e.namespaceDeclarations) {
    out.write(' xmlns:$prefix="$uri"');
  }
  out.writeln('>');
  for (final child in e.children) {
    switch (child) {
      case KElement():
        if (!identical(child.parent, e)) out.writeln('$indent  BAD PARENT');
        out.write(dump(child, '$indent  '));
      case KText(:final type, :final content):
        out.writeln(
          '$indent  ${type.name}: ${content.replaceAll('\n', r'\n')}',
        );
    }
  }
  return out.toString();
}

String outcome(KElement Function(String) parse, String source) {
  try {
    return dump(parse(source));
  } on Object catch (e) {
    return 'error ${e.runtimeType}: $e';
  }
}

void main() {
  const documents = {
    'namespaces':
        '<h:html xmlns="urn:d" xmlns:h="urn:h" xmlns:jr="urn:jr">'
        '<h:head><model><instance><data jr:a="1" b="2"/></instance></model>'
        '</h:head><h:body xmlns="urn:e"><x xmlns=""/><y xmlns:h="urn:h2">'
        '<h:z/></y><h:w xml:lang="en"/></h:body></h:html>',
    'text kinds':
        '<r>a &amp; b<![CDATA[<c>]]><!-- d -->e<?pi f?>\r\ng'
        '<s></s><t/><u> </u></r>',
    'prolog and epilog':
        '<?xml version="1.0"?><!DOCTYPE r><!-- x --><r/>'
        '<!-- y -->',
    'undeclared prefix': '<r><p:a p:b="1"/></r>',
    'mismatched tags': '<r><a></b></r>',
    'two roots': '<r/><s/>',
    'declaration inside an element': '<r><?xml version="1.0"?></r>',
    'empty': '',
  };
  for (final MapEntry(key: description, value: source) in documents.entries) {
    test(description, () {
      expect(
        outcome(parseKDocument, source),
        outcome(parseKDocumentFromDom, source),
      );
    });
  }

  test('every XML file of the corpus', () {
    final files = Directory('${conformanceDir().path}/forms')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.xml'))
        .toList();
    expect(files.length, greaterThan(300));
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        outcome(parseKDocument, source),
        outcome(parseKDocumentFromDom, source),
        reason: file.path,
      );
    }
  });
}
