// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (CsvExternalInstanceTest), Copyright (C) 2009 JavaRosa
//  and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 CsvExternalInstanceTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/instance/external/csv_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:test/test.dart';

import '../../fixtures.dart';

TreeElement parse(String instanceId, String resource) =>
    const CsvExternalInstance().parse(instanceId, resourceBytes(resource));

void main() {
  late TreeElement commaSeparated;
  late TreeElement semicolonSeparated;

  setUp(() {
    commaSeparated = parse('id', 'external-secondary-comma-complex.csv');
    semicolonSeparated = parse(
      'id',
      'external-secondary-semicolon-complex.csv',
    );
  });

  Object? valueAt(TreeElement root, int item, int field) =>
      root.childAt(item).childAt(field).value!.value;

  test('heading has no extra quotes', () {
    expect(commaSeparated.childAt(0).childAt(0).name, 'label');
    expect(semicolonSeparated.childAt(0).childAt(0).name, 'label');
  });

  test('value has no extra quotes', () {
    expect(valueAt(commaSeparated, 0, 0), 'A');
    expect(valueAt(semicolonSeparated, 0, 0), 'A');
  });

  test('quoted string with comma', () {
    expect(valueAt(commaSeparated, 6, 0), '121 Main St, NE');
    expect(valueAt(semicolonSeparated, 6, 0), '121 Main St, NE');
  });

  test('quoted string with semicolon', () {
    expect(valueAt(commaSeparated, 7, 0), 'text; more text');
    expect(valueAt(semicolonSeparated, 7, 0), 'text; more text');
  });

  test('missing fields replaced with empty strings', () {
    for (var field = 1; field < 2; field++) {
      expect(valueAt(commaSeparated, 5, field), '');
      expect(valueAt(semicolonSeparated, 5, field), '');
    }
  });

  test('ignores UTF-8 BOM', () {
    final bytes = resourceBytes('external-secondary-csv-bom.csv');
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(
      parse('id', 'external-secondary-csv-bom.csv').childAt(0).childAt(0).name,
      'name',
    );
  });

  test('parses UTF-8 characters', () {
    final csv = parse('id', 'external-secondary-csv-bom.csv');
    expect(csv.childAt(0).getChild('elevation', 0)!.value!.value, 'testé');
  });

  test('preserves whitespace', () {
    final item = parse('csv', 'whitespace.csv').childAt(0);
    expect(item.getChild('name', 0), isNull);
    expect(item.getChild(' name', 0)!.value!.displayText, ' person1');
    expect(item.getChild('label', 0), isNull);
    expect(item.getChild(' label', 0)!.value!.displayText, ' Person1');
    expect(item.getChild('age', 0), isNull);
    expect(item.getChild('age ', 0)!.value!.displayText, '13 ');
  });
}
