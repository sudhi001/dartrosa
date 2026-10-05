// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (XPathExpressionExtTest), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.entities.javarosa.parse.XPathExpressionExtTest.
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

void main() {
  final sourceInstance = FormInstance();
  final evaluationContext = EvaluationContext(sourceInstance);

  Query? toQuery(String xpath) =>
      parseXPath(xpath).toQuery(sourceInstance, evaluationContext);

  test('#toQuery returns Query when node side is qualified relative '
      'expression', () {
    expect(toQuery("./label = 'blah'"), const StringEqQuery('label', 'blah'));
  });

  test('#toQuery returns Query when node side is node() expression', () {
    expect(
      toQuery("node()/label = 'blah'"),
      const StringEqQuery('label', 'blah'),
    );
  });

  test('#toQuery returns null when node side is multiple levels', () {
    expect(toQuery("one/two = 'blah'"), isNull);
  });

  test('#toQuery returns null when node side is multiple levels and contains '
      'level called node', () {
    expect(toQuery("node/two = 'blah'"), isNull);
  });

  test('#toQuery returns null when node side is self expression', () {
    expect(toQuery(". = 'blah'"), isNull);
  });

  test('#toQuery returns null when node side is relative self expression', () {
    expect(toQuery("./. = 'blah'"), isNull);
  });

  // Added coverage of the other conversions.
  test('#toQuery converts !=, numbers, and/or', () {
    expect(toQuery("a != 'x'"), const StringNotEqQuery('a', 'x'));
    expect(toQuery('a = 2'), const NumericEqQuery('a', 2));
    expect(toQuery('a != 2'), const NumericNotEqQuery('a', 2));
    expect(
      toQuery("a = 'x' and (b = 'y' or c = 'z')"),
      const AndQuery(
        StringEqQuery('a', 'x'),
        OrQuery(StringEqQuery('b', 'y'), StringEqQuery('c', 'z')),
      ),
    );
    expect(toQuery("a = 'x' and starts-with(b, 'y')"), isNull);
  });
}
