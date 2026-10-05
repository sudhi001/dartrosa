// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Added: long children lists use a lookup table (not in JavaRosa); every
// lookup must still return what JavaRosa's linear search returns.
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:test/test.dart';

/// JavaRosa's `TreeElementChildrenList.getChildAndLoc` search (no fast
/// path).
TreeElement? _scan(TreeElement parent, String name, int multiplicity) {
  for (final child in parent.children) {
    if (child.name == name && child.multiplicity == multiplicity) return child;
  }
  return null;
}

/// JavaRosa's `TreeElementChildrenList.get(name)` search (no fast path).
List<TreeElement> _scanName(TreeElement parent, String name) => [
  for (final child in parent.children)
    if (child.multiplicity != TreeReference.indexTemplate &&
        elementMatchesName(child, name))
      child,
];

/// JavaRosa's `TreeElement.getRef`: one step per element, prepended.
TreeReference _javaRosaRef(TreeElement? element) {
  var ref = const TreeReference.self();
  while (element != null) {
    final name = element.name;
    final instanceName = element.instanceName;
    var step = name != null
        ? const TreeReference.self().extend(name, element.multiplicity)
        : const TreeReference.root();
    step = step.withInstanceName(instanceName);
    if (instanceName != null) {
      step = step.withContextType(ReferenceContext.instance);
    }
    ref = ref.parent(step)!;
    element = element.parent;
  }
  return ref;
}

void _expectSameRef(TreeElement element) {
  final built = TreeElement.buildRef(element);
  final expected = _javaRosaRef(element);
  expect(built, expected);
  expect(built.refLevel, expected.refLevel);
  expect(built.contextType, expected.contextType);
  expect(built.instanceName, expected.instanceName);
  expect(
    built.toString(includePredicates: true),
    expected.toString(includePredicates: true),
  );
}

void _expectSameNamesAsScan(TreeElement parent) {
  for (final name in ['r', 'q', 'x', 'p:r', 'p:x', 'o:q', '*', 'none']) {
    for (var round = 0; round < 6; round++) {
      final expected = _scanName(parent, name);
      final found = parent.childrenWithName(name);
      expect(found.length, expected.length, reason: '$name round $round');
      for (var i = 0; i < found.length; i++) {
        expect(identical(found[i], expected[i]), isTrue, reason: name);
      }
      expect(parent.childMultiplicity(name), expected.length, reason: name);
    }
  }
}

void _expectSameAsScan(TreeElement parent, {int upTo = 60}) {
  _expectSameNamesAsScan(parent);
  for (final name in ['r', 'q', 'x']) {
    for (var m = TreeReference.indexTemplate; m < upTo; m++) {
      // Several rounds, so the table is built and then used.
      for (var round = 0; round < 6; round++) {
        expect(
          identical(parent.getChild(name, m), _scan(parent, name, m)),
          isTrue,
          reason: '$name[$m] round $round',
        );
      }
    }
  }
}

TreeElement _repeatParent(int count) {
  final parent = TreeElement('data')..addChild(TreeElement('q'));
  parent.addChild(TreeElement('r', TreeReference.indexTemplate));
  for (var i = 0; i < count; i++) {
    parent.addChild(TreeElement('r', i));
  }
  return parent..addChild(TreeElement('x'));
}

void main() {
  test('lookups in a long list match a linear scan', () {
    _expectSameAsScan(_repeatParent(50));
  });

  test('after inserting and removing children', () {
    final parent = _repeatParent(50);
    _expectSameAsScan(parent);
    parent.addChild(TreeElement('r', 50));
    _expectSameAsScan(parent);
    parent.removeChild(parent.getChild('r', 10)!);
    _expectSameAsScan(parent);
    parent.removeChildAt(0);
    _expectSameAsScan(parent);
    parent.insertChildAt(3, TreeElement('q'));
    _expectSameAsScan(parent);
  });

  test('after children are renumbered or renamed', () {
    final parent = _repeatParent(50);
    _expectSameAsScan(parent);
    // Renumber as removing a repeat instance does.
    parent.removeChild(parent.getChild('r', 0)!);
    var i = 0;
    for (final child in parent.children) {
      if (child.name == 'r' && child.multiplicity >= 0) {
        child.multiplicity = i++;
      }
    }
    _expectSameAsScan(parent);
    parent.getChild('r', 5)!.name = 'x';
    _expectSameAsScan(parent);
  });

  test('duplicates: the first match wins, as in JavaRosa', () {
    final parent = _repeatParent(50);
    // Inserted after r[6], so before the existing r[7].
    parent.addChild(TreeElement('r', 7));
    _expectSameAsScan(parent);
  });

  test('a child shared with a shallow copy is renumbered', () {
    final parent = _repeatParent(50);
    final copy = parent.shallowCopy();
    _expectSameAsScan(copy);
    copy.getChild('r', 3)!.multiplicity = 99;
    _expectSameAsScan(copy, upTo: 100);
    _expectSameAsScan(parent, upTo: 100);
  });

  test('name lookups with namespace prefixes, appends and changes', () {
    final parent = _repeatParent(50);
    _expectSameAsScan(parent);
    parent.getChild('r', 4)!.namespacePrefix = 'p';
    _expectSameAsScan(parent);
    // Appended children update the tables.
    parent.addChild(TreeElement('x', 1)..namespacePrefix = 'p');
    parent.addChild(TreeElement('p:r', 0));
    _expectSameAsScan(parent);
    parent.getChild('x', 0)!.namespacePrefix = 'p';
    _expectSameAsScan(parent);
    parent.getChild('r', 9)!.multiplicity = TreeReference.indexTemplate;
    _expectSameAsScan(parent);
  });

  test('a form root with many differently named questions', () {
    final root = TreeElement('data');
    for (var i = 0; i < 200; i++) {
      root.addChild(TreeElement('q$i'));
      expect(root.childMultiplicity('q$i'), 1);
      expect(root.childMultiplicity('q${i + 1}'), 0);
    }
    for (var i = 0; i < 200; i++) {
      expect(root.childrenWithName('q$i').single.name, 'q$i');
    }
  });

  test('references are built as JavaRosa builds them', () {
    final parent = _repeatParent(3);
    _expectSameRef(parent);
    _expectSameRef(parent.getChild('r', 2)!);
    final leaf = TreeElement('leaf');
    parent.getChild('r', 1)!.addChild(leaf);
    _expectSameRef(leaf);
    _expectSameRef(TreeElement('detached'));
    final main = FormInstance(parent);
    _expectSameRef(main.base);
    _expectSameRef(main.root);
    _expectSameRef(leaf);
    final secondary = TreeElement('item')..addChild(TreeElement('name'));
    final towns = FormInstance(
      TreeElement('root')..addChild(secondary),
      'towns',
    );
    _expectSameRef(towns.base);
    _expectSameRef(secondary.getChild('name', 0)!);
    final named = TreeElement('named')..instanceName = 'x';
    named.addChild(TreeElement('child', 3));
    _expectSameRef(named.getChild('child', 3)!);
  });
}
