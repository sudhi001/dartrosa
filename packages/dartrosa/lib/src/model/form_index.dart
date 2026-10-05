// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormIndex), Copyright (C) 2009 JavaRosa; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'form_def.dart';
import 'form_element.dart';
import 'instance/tree_reference.dart';

/// A position in a form: a path of child indices (and repeat instance
/// indices) through the control tree, or the beginning or end of the
/// form.
///
/// Port of `org.javarosa.core.model.FormIndex`. Each level holds the index
/// of a child within its parent ([localIndex]), the repeat instance for
/// repeats ([instanceIndex], else -1), the instance reference of that
/// element, and the next level down.
final class FormIndex implements Comparable<FormIndex> {
  /// A level at child [localIndex] (and [instanceIndex] for a repeat),
  /// with an optional [nextLevel].
  FormIndex(
    this.localIndex, {
    this.instanceIndex = -1,
    this.nextLevel,
    TreeReference? reference,
  }) : _reference = reference,
       isBeginningOfFormIndex = false,
       isEndOfFormIndex = false;

  /// [currentLevel] (or, when `null`, [nextLevel]'s top level) above
  /// [nextLevel]. Port of `FormIndex(FormIndex nextLevel, FormIndex
  /// currentLevel)`.
  factory FormIndex.wrap(FormIndex? nextLevel, FormIndex? currentLevel) =>
      currentLevel == null
      ? FormIndex(
          nextLevel!.localIndex,
          instanceIndex: nextLevel.instanceIndex,
          nextLevel: nextLevel.nextLevel,
          reference: nextLevel._reference,
        )
      : FormIndex(
          currentLevel.localIndex,
          instanceIndex: currentLevel.instanceIndex,
          nextLevel: nextLevel,
          reference: currentLevel._reference,
        );

  FormIndex._special({required bool beginning})
    : localIndex = -1,
      instanceIndex = -1,
      nextLevel = null,
      _reference = null,
      isBeginningOfFormIndex = beginning,
      isEndOfFormIndex = !beginning;

  /// The index before the first element.
  factory FormIndex.beginningOfForm() => FormIndex._special(beginning: true);

  /// The index after the last element.
  factory FormIndex.endOfForm() => FormIndex._special(beginning: false);

  /// Whether this is the beginning-of-form index.
  final bool isBeginningOfFormIndex;

  /// Whether this is the end-of-form index.
  final bool isEndOfFormIndex;

  /// The child index at this level.
  final int localIndex;

  /// The repeat instance index at this level, or -1.
  final int instanceIndex;

  /// The next level down, if any.
  final FormIndex? nextLevel;

  TreeReference? _reference;

  /// Whether this is a position inside the form.
  bool get isInForm => !isBeginningOfFormIndex && !isEndOfFormIndex;

  /// The instance index of the terminal level (the element's multiplicity).
  int get elementMultiplicity => terminal.instanceIndex;

  /// The reference of this level's element.
  TreeReference? get localReference => _reference;

  /// The reference of the terminal level's element.
  TreeReference? get reference => terminal._reference;

  /// The deepest level.
  FormIndex get terminal {
    var walker = this;
    while (walker.nextLevel != null) {
      walker = walker.nextLevel!;
    }
    return walker;
  }

  /// Whether this level is the deepest.
  bool get isTerminal => nextLevel == null;

  /// The number of levels.
  int get depth {
    var depth = 0;
    for (FormIndex? level = this; level != null; level = level.nextLevel) {
      depth++;
    }
    return depth;
  }

  /// This level alone.
  FormIndex snip() => FormIndex(
    localIndex,
    instanceIndex: instanceIndex,
    reference: _reference,
  );

  /// The part of this index above [subIndex], or `null` if [subIndex] is
  /// not a sub-index of this one (or equal to it).
  FormIndex? diff(FormIndex? subIndex) {
    if (subIndex == null) return this;
    if (!isSubIndex(this, subIndex) || subIndex == this) return null;
    return FormIndex.wrap(nextLevel!.diff(subIndex), snip());
  }

  /// This index without its terminal level, or `null` for a terminal
  /// level.
  FormIndex? get previousLevel =>
      isTerminal ? null : FormIndex.wrap(nextLevel!.previousLevel, this);

  /// Sets the reference of every level from [form].
  void assignRefs(FormDef form) {
    final indexes = <int>[];
    final multiplicities = <int>[];
    final elements = <FormElement>[];
    form.collapseIndex(this, indexes, multiplicities, elements);
    final curMults = <int>[];
    final curElems = <FormElement>[];
    var i = 0;
    for (FormIndex? cur = this; cur != null; cur = cur.nextLevel) {
      curMults.add(multiplicities[i]);
      curElems.add(elements[i]);
      cur._reference = form.childInstanceRefOf(curElems, curMults);
      i++;
    }
  }

  /// [index] without a terminal level with a negative local index (or
  /// `null` if it is the only level).
  static FormIndex? trimNegativeIndices(FormIndex index) {
    if (!index.isTerminal) {
      return FormIndex.wrap(trimNegativeIndices(index.nextLevel!), index);
    }
    return index.localIndex < 0 ? null : index;
  }

  /// Whether [child] is [parent] or one of its lower levels.
  static bool isSubIndex(FormIndex? parent, FormIndex child) {
    if (child == parent) return true;
    if (parent == null) return false;
    return isSubIndex(parent.nextLevel, child);
  }

  /// Whether [child] is inside the element at [parent] (an unspecified
  /// repeat instance in [parent] matches any).
  static bool isSubElement(FormIndex parent, FormIndex child) {
    var p = parent;
    var c = child;
    while (!p.isTerminal && !c.isTerminal) {
      if (p.localIndex != c.localIndex) return false;
      if (p.instanceIndex != c.instanceIndex) return false;
      p = p.nextLevel!;
      c = c.nextLevel!;
    }
    if (!p.isTerminal && c.isTerminal) return false;
    if (p.localIndex != c.localIndex) return false;
    if (p.instanceIndex != -1 && p.instanceIndex != c.instanceIndex) {
      return false;
    }
    return true;
  }

  @override
  int compareTo(FormIndex b) {
    final a = this;
    if (a.isBeginningOfFormIndex) return b.isBeginningOfFormIndex ? 0 : -1;
    if (a.isEndOfFormIndex) return b.isEndOfFormIndex ? 0 : 1;
    if (b.isBeginningOfFormIndex) return 1;
    if (b.isEndOfFormIndex) return -1;
    if (a.localIndex != b.localIndex) {
      return a.localIndex < b.localIndex ? -1 : 1;
    }
    if (a.instanceIndex != b.instanceIndex) {
      return a.instanceIndex < b.instanceIndex ? -1 : 1;
    }
    if ((a.nextLevel == null) != (b.nextLevel == null)) {
      return a.nextLevel == null ? -1 : 1;
    }
    return a.nextLevel?.compareTo(b.nextLevel!) ?? 0;
  }

  // Equality only uses the immutable fields; the lazily assigned reference
  // is not part of it.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) => other is FormIndex && compareTo(other) == 0;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(
    isBeginningOfFormIndex,
    isEndOfFormIndex,
    localIndex,
    instanceIndex,
    nextLevel,
  );

  /// This index as a string that [FormIndex.parse] reads back (the
  /// replacement for JavaRosa's Java serialization of `FormIndex`):
  /// `BEGINNING`, `END`, or the levels as `local[_instance][=ref]` joined
  /// by `,`, where `ref` is the level's absolute reference written as
  /// `/name#multiplicity` steps (`/` for the root).
  String toPathString() {
    if (isBeginningOfFormIndex) return 'BEGINNING';
    if (isEndOfFormIndex) return 'END';
    final levels = <String>[];
    for (FormIndex? level = this; level != null; level = level.nextLevel) {
      final b = StringBuffer('${level.localIndex}');
      if (level.instanceIndex != -1) b.write('_${level.instanceIndex}');
      final ref = level._reference;
      if (ref != null) b.write('=${_refToPathString(ref)}');
      levels.add('$b');
    }
    return levels.join(',');
  }

  /// Reads an index written by [toPathString].
  static FormIndex parse(String path) {
    if (path == 'BEGINNING') return FormIndex.beginningOfForm();
    if (path == 'END') return FormIndex.endOfForm();
    FormIndex? index;
    for (final level in path.split(',').reversed) {
      final eq = level.indexOf('=');
      final indices = (eq == -1 ? level : level.substring(0, eq)).split('_');
      if (indices.length > 2) throw FormatException('Bad level', path);
      index = FormIndex(
        int.parse(indices[0]),
        instanceIndex: indices.length == 2 ? int.parse(indices[1]) : -1,
        nextLevel: index,
        reference: eq == -1
            ? null
            : _refFromPathString(level.substring(eq + 1)),
      );
    }
    return index!;
  }

  static String _refToPathString(TreeReference ref) {
    if (!ref.isAbsolute ||
        ref.instanceName != null ||
        ref.contextType != ReferenceContext.absolute ||
        ref.hasPredicates) {
      throw ArgumentError.value(ref, 'ref', 'not a plain absolute reference');
    }
    if (ref.size == 0) return '/';
    return [
      for (var i = 0; i < ref.size; i++)
        '/${ref.nameAt(i)}#${ref.multiplicityAt(i)}',
    ].join();
  }

  static TreeReference _refFromPathString(String path) {
    var ref = const TreeReference.root();
    if (path == '/') return ref;
    for (final step in path.substring(1).split('/')) {
      final hash = step.lastIndexOf('#');
      ref = ref.extend(
        step.substring(0, hash),
        int.parse(step.substring(hash + 1)),
      );
    }
    return ref;
  }

  /// Levels as `local[_instance], `, e.g. `0, 1_2, 0, `.
  @override
  String toString() {
    final b = StringBuffer();
    for (FormIndex? level = this; level != null; level = level.nextLevel) {
      b.write(level.localIndex);
      if (level.instanceIndex != -1) b.write('_${level.instanceIndex}');
      b.write(', ');
    }
    return '$b';
  }
}
