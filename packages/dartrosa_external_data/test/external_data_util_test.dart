// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalDataUtilTest), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of Collect's ExternalDataUtilTest, plus DartRosa tests of the other
// ExternalDataUtil helpers.
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

void main() {
  test('testSafeColumnName', () {
    // This is likely bad behavior: the method does not check the input for
    // null or empty strings.
    expect(ExternalDataUtil.toSafeColumnName(''), 'c_');

    // casing
    expect(ExternalDataUtil.toSafeColumnName('simplename'), 'c_simplename');
    expect(ExternalDataUtil.toSafeColumnName('CamelCase'), 'c_camelcase');

    // whitespace
    expect(
      ExternalDataUtil.toSafeColumnName('trailingwhitespace '),
      'c_trailingwhitespace',
    );
    expect(
      ExternalDataUtil.toSafeColumnName(' leadingwhitespace'),
      'c_leadingwhitespace',
    );
    expect(
      ExternalDataUtil.toSafeColumnName('middle whitespace'),
      'c_middle_whitespace',
    );

    // numbers
    expect(ExternalDataUtil.toSafeColumnName('0123456789'), 'c_0123456789');

    // specials
    expect(ExternalDataUtil.toSafeColumnName('a*b'), 'c_a_b');
    expect(ExternalDataUtil.toSafeColumnName('new\nline'), 'c_new_line');
    expect(ExternalDataUtil.toSafeColumnName('double"quote'), 'c_double_quote');
    expect(ExternalDataUtil.toSafeColumnName('café'), 'c_caf_');
  });

  test('findMatchingColumnsAfterSafeningNames', () {
    expect(
      ExternalDataUtil.findMatchingColumnsAfterSafeningNames(['a', 'b', ' ']),
      isNull,
    );
    expect(
      ExternalDataUtil.findMatchingColumnsAfterSafeningNames([
        'a b',
        'c',
        'A_B',
      ]),
      ['a b', 'A_B'],
    );
  });

  group('getSearchXPathExpression', () {
    test('finds search() in an appearance', () {
      final expr = ExternalDataUtil.getSearchXPathExpression(
        "minimal search('fruits')",
      );
      expect(expr!.id.name, 'search');
      expect(expr.args, hasLength(1));
    });

    test('accepts 1, 4 or 6 arguments', () {
      expect(
        ExternalDataUtil.getSearchXPathExpression(
          "search('f', 'contains', 'name', /data/q)",
        ),
        isNotNull,
      );
      expect(
        ExternalDataUtil.getSearchXPathExpression(
          "search('f', 'contains', 'name', /data/q, 'type', 'fruit')",
        ),
        isNotNull,
      );
      expect(
        ExternalDataUtil.getSearchXPathExpression("search('f', 'contains')"),
        isNull,
      );
    });

    test('ignores appearances without a search() call', () {
      expect(ExternalDataUtil.getSearchXPathExpression(null), isNull);
      expect(ExternalDataUtil.getSearchXPathExpression('search'), isNull);
      expect(ExternalDataUtil.getSearchXPathExpression('minimal'), isNull);
    });

    test('rejects what is not a single search() call', () {
      expect(
        ExternalDataUtil.getSearchXPathExpression("search('a') and true()"),
        isNull,
      );
      expect(ExternalDataUtil.getSearchXPathExpression("search('a'"), isNull);
      expect(ExternalDataUtil.getSearchXPathExpression('search(()'), isNull);
    });
  });

  test('createMapWithDisplayingColumns', () {
    expect(
      ExternalDataUtil.createMapWithDisplayingColumns(' name ', 'label, ,x'),
      {'c_name': 'name', 'c_label': 'label', 'c_x': 'x'},
    );
    // SCTO-584: falls back to spaces.
    expect(ExternalDataUtil.createMapWithDisplayingColumns('name', 'label x'), {
      'c_name': 'name',
      'c_label': 'label',
      'c_x': 'x',
    });
    // The value column keeps its position when repeated.
    expect(
      ExternalDataUtil.createMapWithDisplayingColumns('name', 'name,label'),
      {'c_name': 'name', 'c_label': 'label'},
    );
    expect(ExternalDataUtil.createMapWithDisplayingColumns('name', null), {
      'c_name': 'name',
    });
  });

  test('createListOfColumns', () {
    expect(ExternalDataUtil.createListOfColumns('a,b'), ['c_a', 'c_b']);
    expect(ExternalDataUtil.createListOfColumns('a b'), ['c_a', 'c_b']);
    expect(ExternalDataUtil.createListOfColumns('a b, c'), ['c_a_b', 'c_c']);
  });

  test('row helpers', () {
    expect(ExternalDataUtil.containsAnyData(null), isFalse);
    expect(ExternalDataUtil.containsAnyData([]), isFalse);
    expect(ExternalDataUtil.containsAnyData([' ', '']), isFalse);
    expect(ExternalDataUtil.containsAnyData([' ', 'x']), isTrue);
    expect(ExternalDataUtil.fillUpNullValues(['a'], ['x', 'y', 'z']), [
      'a',
      '',
      '',
    ]);
    expect(ExternalDataUtil.nullSafe(null), '');
    expect(ExternalDataUtil.isAnInteger(' 12 '), isTrue);
    expect(ExternalDataUtil.isAnInteger('-3'), isTrue);
    expect(ExternalDataUtil.isAnInteger('1.0'), isFalse);
    expect(ExternalDataUtil.isAnInteger('99999999999'), isFalse);
    expect(ExternalDataUtil.isAnInteger('name'), isFalse);
    expect(ExternalDataUtil.isAnInteger(null), isFalse);
  });
}
