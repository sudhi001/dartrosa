// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Added: long children lists use a lookup table (not in JavaRosa); every
// lookup must still return what JavaRosa's linear search returns.
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

void _expectSameAsScan(TreeElement parent, {int upTo = 60}) {
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
}
