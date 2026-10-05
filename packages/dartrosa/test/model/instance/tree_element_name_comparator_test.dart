// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (TreeElementNameComparatorTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 TreeElementNameComparatorTest.
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:test/test.dart';

const nsOrx = 'http://openrosa.org/xforms';
const prefixOrx = 'orx';

/// JavaRosa's TreeElements carry the namespace associated with the prefix,
/// not the prefix in the name.
TreeElement createTreeElement(String name, String namespace, String prefix) =>
    TreeElement(name)
      ..namespace = namespace
      ..namespacePrefix = prefix;

bool matches(TreeElement e, String name) => elementMatchesName(e, name);

void main() {
  test(
    'wildcard matches',
    () => expect(matches(TreeElement('a'), '*'), isTrue),
  );
  test('simple matches', () => expect(matches(TreeElement('a'), 'a'), isTrue));
  test('simple mismatches', () {
    expect(matches(TreeElement('a'), 'b'), isFalse);
  });
  test('explicit matches', () {
    expect(matches(createTreeElement('a', nsOrx, prefixOrx), 'orx:a'), isTrue);
  });
  test('explicit mismatches name', () {
    expect(matches(createTreeElement('a', nsOrx, prefixOrx), 'orx:b'), isFalse);
  });
  test('explicit mismatches prefix', () {
    expect(
      matches(createTreeElement('a', nsOrx, prefixOrx), 'orx2:b'),
      isFalse,
    );
  });
  test('explicit mismatches element without namespace', () {
    expect(matches(TreeElement('a'), 'orx:a'), isFalse);
  });
}
