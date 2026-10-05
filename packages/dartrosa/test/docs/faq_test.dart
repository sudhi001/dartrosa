// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of docs/FAQ.md, run as tests so the answers can't rot
// (doc_snippets.dart checks that its snippets are here).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

String form(String binds, String body) =>
    '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>T</h:title><model>
    <instance><data id="t"><a/><b/></data></instance>
    $binds
  </model></h:head>
  <h:body>$body</h:body>
</h:html>''';

/// Opens a form, or explains why it can't be opened.
Future<FormSession?> tryOpen(
  String xml,
  void Function(String message) showError,
) async {
  try {
    final definition = await FormDefinition.parse(xml);
    return definition.createSession();
  } on XFormParseException catch (e) {
    // Not XML, a question bound to a missing node, a cycle in the logic...
    showError("This form can't be opened: ${e.message}");
  } on XPathException catch (e) {
    // An expression that can't be read or run.
    showError('This form has an error: ${e.message}');
  } on Exception catch (e) {
    // A calculation failing when the form starts (an unknown function,
    // a missing secondary instance): TriggerableEvaluationException.
    showError('This form has an error: $e');
  }
  return null;
}

void main() {
  Future<String?> errorOf(String xml) async {
    String? error;
    await tryOpen(xml, (message) => error = message);
    return error;
  }

  test('a good form opens', () async {
    expect(
      await tryOpen(
        form('', '<input ref="/data/a"><label>A</label></input>'),
        (_) {},
      ),
      isNotNull,
    );
  });

  test('not XML', () async {
    expect(await errorOf('<h:html'), contains('XML Syntax Error'));
  });

  test('a question bound to a missing node', () async {
    expect(
      await errorOf(form('', '<input ref="/data/zz"><label>Z</label></input>')),
      contains('Question bound to non-existent node'),
    );
  });

  test('a cycle', () async {
    expect(
      await errorOf(
        form(
          '<bind nodeset="/data/a" calculate="/data/b"/>'
              '<bind nodeset="/data/b" calculate="/data/a"/>',
          '',
        ),
      ),
      contains('Cycle detected'),
    );
  });

  test('an invalid expression', () async {
    expect(
      await errorOf(
        form('<bind nodeset="/data/a" type="int" constraint=". &gt;"/>', ''),
      ),
      contains('invalid constraint expression'),
    );
  });

  test('an unknown function', () async {
    expect(
      await errorOf(
        form('<bind nodeset="/data/a" type="string" calculate="foo(1)"/>', ''),
      ),
      contains("cannot handle function 'foo'"),
    );
  });
}
