// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (TreeReference, TreeReferenceLevel), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../xpath/exceptions.dart';
import '../../xpath/expression.dart';

/// How a [TreeReference] is anchored.
///
/// Port of the `TreeReference.CONTEXT_*` constants.
enum ReferenceContext {
  /// Absolute in the main instance, or a plain relative reference.
  absolute,

  /// Relative to an inherited context (`inherited()` when printed).
  inherited,

  /// Relative to the original context node, from `current()`.
  original,

  /// Absolute in a secondary instance, from `instance('id')`.
  instance,
}

/// One step of a [TreeReference]: a name, a multiplicity and optional
/// predicates.
///
/// Port of `org.javarosa.core.model.instance.TreeReferenceLevel`.
@immutable
final class TreeReferenceLevel {
  /// Creates a level for [name] with [multiplicity] and optional
  /// [predicates].
  TreeReferenceLevel(
    this.name,
    this.multiplicity, [
    List<XPathExpression>? predicates,
  ]) : predicates = predicates == null ? null : List.unmodifiable(predicates);

  // Shares [predicates], already an unmodifiable copy.
  const TreeReferenceLevel._(this.name, this.multiplicity, this.predicates);

  /// Element (or attribute) name, or [TreeReference.nameWildcard].
  final String name;

  /// 0-based position among same-named siblings, or one of the
  /// `TreeReference.index*` sentinels.
  final int multiplicity;

  /// Predicates on this level, or `null` when there are none.
  final List<XPathExpression>? predicates;

  /// A copy with a different [multiplicity].
  TreeReferenceLevel withMultiplicity(int multiplicity) =>
      TreeReferenceLevel._(name, multiplicity, predicates);

  /// A copy with different (or no) [predicates].
  TreeReferenceLevel withPredicates(List<XPathExpression>? predicates) =>
      TreeReferenceLevel(name, multiplicity, predicates);

  /// A copy with a different [name].
  TreeReferenceLevel withName(String name) =>
      TreeReferenceLevel._(name, multiplicity, predicates);

  @override
  bool operator ==(Object other) =>
      other is TreeReferenceLevel &&
      multiplicity == other.multiplicity &&
      name == other.name &&
      const ListEquality<XPathExpression>().equals(
        predicates,
        other.predicates,
      );

  @override
  int get hashCode => Object.hash(
    name,
    multiplicity,
    predicates == null ? null : Object.hashAllUnordered(predicates!),
  );
}

/// A reference to a node (or, with unbound multiplicities, a set of nodes)
/// in an instance, such as `/data/child[2]/name` or `../age`.
///
/// Port of `org.javarosa.core.model.instance.TreeReference`. Unlike the
/// Java class it is immutable: every operation returns a new reference, so
/// references are always safe to use as map keys.
///
/// Multiplicities are 0-based; [toString] prints them 1-based like XPath.
@immutable
final class TreeReference {
  const TreeReference._({
    required this.refLevel,
    required this.contextType,
    required this.instanceName,
    required List<TreeReferenceLevel> levels,
  }) : _levels = levels;

  /// A reference with [levels], which it keeps (the caller must not
  /// modify the list afterwards). For `TreeElement.buildRef`.
  @internal
  const TreeReference.ofLevels(
    List<TreeReferenceLevel> levels, {
    required this.refLevel,
    required this.contextType,
    required this.instanceName,
  }) : _levels = levels;

  /// An empty relative reference (the context node itself).
  const TreeReference.relative({this.refLevel = 0})
    : contextType = ReferenceContext.absolute,
      instanceName = null,
      _levels = const [];

  /// The absolute root reference `/`.
  const TreeReference.root()
    : refLevel = refAbsolute,
      contextType = ReferenceContext.absolute,
      instanceName = null,
      _levels = const [];

  /// The inherited self reference (`inherited()`), used by the parser for
  /// relative binds.
  const TreeReference.self()
    : refLevel = 0,
      contextType = ReferenceContext.inherited,
      instanceName = null,
      _levels = const [];

  /// Default multiplicity: the first node with a given name.
  static const defaultMultiplicity = 0;

  /// All nodes with a given name, e.g. `/data/b` meaning `b[1]`, `b[2]`, ….
  static const indexUnbound = -1;

  /// The template of a repeat, which is never serialized.
  static const indexTemplate = -2;

  /// Marks an attribute step.
  static const indexAttribute = -4;

  /// Marks a repeat juncture in form navigation.
  static const indexRepeatJuncture = -10;

  /// [refLevel] value of an absolute reference.
  static const refAbsolute = -1;

  /// Name of a wildcard (`*`) step.
  static const nameWildcard = '*';

  /// `-1` for absolute references; otherwise how many `..` steps precede
  /// the named steps (0 = context node, 1 = parent, …).
  final int refLevel;

  /// How the reference is anchored.
  final ReferenceContext contextType;

  /// The secondary instance id, or `null` for the main instance.
  final String? instanceName;

  final List<TreeReferenceLevel> _levels;

  /// The named steps, in order.
  List<TreeReferenceLevel> get levels => UnmodifiableListView(_levels);

  /// Number of named steps.
  int get size => _levels.length;

  /// Whether this reference is absolute.
  bool get isAbsolute => refLevel == refAbsolute;

  /// Name of step [i].
  String nameAt(int i) => _levels[i].name;

  /// Multiplicity of step [i].
  int multiplicityAt(int i) => _levels[i].multiplicity;

  /// Predicates of step [i], or `null`.
  List<XPathExpression>? predicatesAt(int i) => _levels[i].predicates;

  /// Name of the last step.
  String get lastName => _levels.last.name;

  /// Multiplicity of the last step.
  int get lastMultiplicity => _levels.last.multiplicity;

  /// Whether any step after the first has an unbound multiplicity, i.e.
  /// whether this reference could match more than one node.
  bool get isAmbiguous {
    for (var i = 1; i < size; i++) {
      if (multiplicityAt(i) == indexUnbound) return true;
    }
    return false;
  }

  /// Whether any step has predicates.
  bool get hasPredicates => _levels.any((level) => level.predicates != null);

  TreeReference _copy({
    int? refLevel,
    ReferenceContext? contextType,
    String? Function()? instanceName,
    List<TreeReferenceLevel>? levels,
  }) => TreeReference._(
    refLevel: refLevel ?? this.refLevel,
    contextType: contextType ?? this.contextType,
    instanceName: instanceName == null ? this.instanceName : instanceName(),
    // Every caller passes a list it just built and never touches again, and
    // `_levels` is never modified, so it needn't be copied.
    levels: levels ?? _levels,
  );

  /// A copy with a different [refLevel].
  TreeReference withRefLevel(int refLevel) => _copy(refLevel: refLevel);

  /// A copy with a different [contextType].
  TreeReference withContextType(ReferenceContext contextType) =>
      _copy(contextType: contextType);

  /// A copy in another instance ([instanceName] `null` = main instance).
  TreeReference withInstanceName(String? instanceName) =>
      _copy(instanceName: () => instanceName);

  /// A copy with one more `..` step, unless absolute.
  TreeReference withIncrementedRefLevel() =>
      isAbsolute ? this : _copy(refLevel: refLevel + 1);

  /// A copy extended by the step [name] with multiplicity [multiplicity].
  TreeReference extend(String name, int multiplicity) =>
      _copy(levels: [..._levels, TreeReferenceLevel(name, multiplicity)]);

  /// A copy with step [i]'s multiplicity set to [multiplicity].
  TreeReference withMultiplicity(int i, int multiplicity) => _copy(
    levels: [..._levels]..[i] = _levels[i].withMultiplicity(multiplicity),
  );

  /// A copy with step [i]'s predicates replaced by [predicates].
  TreeReference withPredicates(int i, List<XPathExpression>? predicates) =>
      _copy(levels: [..._levels]..[i] = _levels[i].withPredicates(predicates));

  /// A copy without predicates on step [i], or on every step when [i] is
  /// omitted.
  TreeReference removePredicates([int? i]) => i != null
      ? withPredicates(i, null)
      : _copy(levels: [for (final l in _levels) l.withPredicates(null)]);

  /// The reference one level up, or `null` for the absolute root.
  ///
  /// Removes the last step; for a relative reference without steps it adds
  /// a `..` instead. Port of `removeLastLevel`/`getParentRef`.
  TreeReference? get parentRef {
    if (_levels.isEmpty) {
      return isAbsolute ? null : _copy(refLevel: refLevel + 1);
    }
    return _copy(levels: _levels.sublist(0, _levels.length - 1));
  }

  /// This reference anchored to [base], which may be relative.
  ///
  /// When this reference has `..` steps, [base] must be a relative
  /// reference made only of `..` steps; otherwise returns `null`.
  /// `'../../a'.parent('..')` is `'../../../a'`.
  TreeReference? parent(TreeReference base) {
    if (isAbsolute) return this;
    var newRef = base;
    if (refLevel > 0) {
      if (base.isAbsolute || base.size != 0) return null;
      newRef = base._copy(refLevel: base.refLevel + refLevel);
    }
    return newRef._copy(levels: [...newRef._levels, ..._levels]);
  }

  /// This reference anchored to the absolute [base]:
  /// `'../../d/e'.anchor('/a/b/c')` is `'/a/d/e'`.
  ///
  /// Works when [base] has unbound multiplicities (conditions rely on it).
  /// Throws [XPathException] if [base] is relative or there are more `..`
  /// steps than [base] has levels.
  TreeReference anchor(TreeReference base) {
    if (isAbsolute) return this;
    if (!base.isAbsolute) {
      throw XPathException(
        '${base.toString(includePredicates: true)} is not an absolute '
        'reference',
      );
    }
    if (refLevel > base.size) {
      throw XPathException(
        'Attempt to parent past the root node '
        '${toString(includePredicates: true)}',
      );
    }
    return base._copy(
      levels: [
        for (var i = 0; i < base.size - refLevel; i++) base._levels[i],
        ..._levels,
      ],
    );
  }

  /// This reference anchored to [context], taking multiplicities,
  /// predicates and wildcard names from [context] where the paths agree.
  ///
  /// Returns `null` if [context] is relative.
  TreeReference? contextualize(TreeReference context) {
    if (!context.isAbsolute) return null;
    final anchored = anchor(context);
    // Levels are adjusted in one working copy (JavaRosa mutates its clone):
    // the list [anchor] just built, or a copy of this reference's own.
    final levels = identical(anchored, this)
        ? [...anchored._levels]
        : anchored._levels;
    for (var i = 0; i < context.size && i < levels.length; i++) {
      var level = levels[i];
      // Fill in a wildcard name from the context.
      if (level.name == nameWildcard && context.nameAt(i) != nameWildcard) {
        level = level.withName(context.nameAt(i));
      }
      if (context.nameAt(i) != level.name) break;
      if (level.predicates == null && context.predicatesAt(i) != null) {
        // A predicate wins over a multiplicity; never keep both.
        level = level
            .withPredicates(context.predicatesAt(i))
            .withMultiplicity(indexUnbound);
      }
      if (level.predicates == null && i < context.size - refLevel) {
        level = level.withMultiplicity(context.multiplicityAt(i));
      }
      levels[i] = level;
    }
    return anchored._copy(levels: levels);
  }

  /// This reference relative to its ancestor [parent], with unbound
  /// multiplicities; `null` if [parent] is not an ancestor.
  TreeReference? relativize(TreeReference parent) {
    if (!parent.isAncestorOf(this)) return null;
    var relative = const TreeReference.self();
    for (var i = parent.size; i < size; i++) {
      relative = relative.extend(nameAt(i), indexUnbound);
    }
    return relative;
  }

  /// A copy with every multiplicity unbound (matching all repeat
  /// instances).
  TreeReference genericize() => _copy(
    levels: [for (final l in _levels) l.withMultiplicity(indexUnbound)],
  );

  /// Whether this reference is an ancestor of [child], or equal to it
  /// unless [proper] is set.
  bool isAncestorOf(TreeReference child, {bool proper = false}) {
    if (refLevel != child.refLevel) return false;
    if (child.size < size + (proper ? 1 : 0)) return false;
    for (var i = 0; i < size; i++) {
      if (nameAt(i) != child.nameAt(i)) return false;
      final parentMult = multiplicityAt(i);
      final childMult = child.multiplicityAt(i);
      if (parentMult != indexUnbound &&
          parentMult != childMult &&
          !(i == 0 && parentMult == 0 && childMult == indexUnbound)) {
        return false;
      }
    }
    return true;
  }

  /// The longest common absolute prefix of this reference and [other];
  /// the root reference if either is relative or they share no steps.
  TreeReference intersect(TreeReference other) {
    if (!isAbsolute || !other.isAbsolute) return const TreeReference.root();
    if (this == other) return this;
    var (a, b) = size < other.size ? (other, this) : (this, other);
    a = a._copy(levels: a._levels.sublist(0, b.size));
    while (a.size > 0) {
      if (a == b) return a;
      a = a.parentRef!;
      b = b.parentRef!;
    }
    return a == b ? a : const TreeReference.root();
  }

  /// The absolute prefix up to and including step [level].
  TreeReference subReference(int level) {
    if (!isAbsolute) {
      throw ArgumentError('Cannot subreference a non-absolute ref');
    }
    return _copy(levels: _levels.sublist(0, level + 1));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TreeReference ||
        instanceName != other.instanceName ||
        refLevel != other.refLevel ||
        size != other.size) {
      return false;
    }
    for (var i = 0; i < size; i++) {
      final multA = multiplicityAt(i);
      final multB = other.multiplicityAt(i);
      if (nameAt(i) != other.nameAt(i)) return false;
      if (multA != multB) {
        // `/data` and `/data[1]` are the same root.
        final bothRoot =
            i == 0 &&
            (multA == 0 || multA == indexUnbound) &&
            (multB == 0 || multB == indexUnbound);
        if (!bothRoot) return false;
      } else if (!const ListEquality<XPathExpression>().equals(
        predicatesAt(i),
        other.predicatesAt(i),
      )) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(refLevel, instanceName);
    for (var i = 0; i < size; i++) {
      var mult = multiplicityAt(i);
      if (i == 0 && mult == indexUnbound) mult = 0;
      hash = Object.hash(hash, nameAt(i), mult);
      final predicates = predicatesAt(i);
      if (predicates != null) {
        hash = Object.hash(hash, Object.hashAll(predicates));
      }
    }
    return hash;
  }

  /// The last name with the 1-based positions of the bound steps, such as
  /// `name [2_3]`; for event summaries. Port of `toShortString`.
  String toShortString() {
    final sb = StringBuffer();
    for (var i = 0; i < size; i++) {
      final mult = multiplicityAt(i);
      switch (mult) {
        case indexUnbound:
          break;
        case indexTemplate:
          sb.write('[@template]');
        case indexRepeatJuncture:
          sb.write('[@juncture]');
        default:
          if ((i > 0 || mult != 0) && mult != indexAttribute) {
            if (sb.isNotEmpty) sb.write('_');
            sb.write(mult + 1);
          }
      }
    }
    return '$lastName [$sb]';
  }

  /// Prints the reference as JavaRosa does: multiplicities 1-based (or
  /// 0-based with [zeroIndexMultiplicity]), `[@template]`, `[@juncture]`,
  /// `@` for attributes, and `instance(id)`, `current()` or `inherited()`
  /// prefixes.
  @override
  String toString({
    bool includePredicates = true,
    bool zeroIndexMultiplicity = false,
  }) {
    final sb = StringBuffer();
    if (instanceName != null) {
      sb.write('instance($instanceName)');
    } else if (contextType == ReferenceContext.original) {
      sb.write('current()');
    } else if (contextType == ReferenceContext.inherited) {
      sb.write('inherited()');
    }
    if (isAbsolute) {
      sb.write('/');
    } else {
      for (var i = 0; i < refLevel; i++) {
        sb.write('../');
      }
    }
    for (var i = 0; i < size; i++) {
      final mult = multiplicityAt(i);
      if (mult == indexAttribute) sb.write('@');
      sb.write(nameAt(i));
      if (includePredicates) {
        switch (mult) {
          case indexUnbound:
            break;
          case indexTemplate:
            sb.write('[@template]');
          case indexRepeatJuncture:
            sb.write('[@juncture]');
          default:
            if ((i > 0 || mult != 0) && mult != indexAttribute) {
              sb.write('[${mult + (zeroIndexMultiplicity ? 0 : 1)}]');
            }
        }
      }
      if (i < size - 1) sb.write('/');
    }
    return sb.toString();
  }
}
