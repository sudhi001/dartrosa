// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (CompareToNodeExpression,
//  EqualityExpressionIndexFilterStrategy,
//  ComparisonExpressionCacheFilterStrategy,
//  IdempotentExpressionCacheFilterStrategy), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../../util/java_double.dart';
import '../../util/measure.dart';
import '../../xpath/conversions.dart';
import '../../xpath/expression.dart';
import '../instance/data_instance.dart';
import '../instance/tree_reference.dart';
import 'evaluation_context.dart';

/// A predicate comparing a relative path (evaluated on each candidate
/// node) with a value that doesn't depend on the candidate: `name = 'x'`,
/// `value > /data/limit`, or a two-argument idempotent function such as
/// `selected(choices, /data/q)`.
///
/// Port of `org.javarosa.core.model.CompareToNodeExpression`.
final class CompareToNodeExpression {
  const CompareToNodeExpression._(
    this.nodeSide,
    this.contextSide,
    this.original,
  );

  /// The relative path evaluated on each candidate.
  final XPathPathExpr nodeSide;

  /// The candidate-independent side (absolute path or literal).
  final XPathExpression contextSide;

  /// The whole predicate.
  final XPathExpression original;

  /// [nodeSide] for the [childIndex]-th candidate [child], unpacked.
  Object evalNodeSide(
    DataInstance sourceInstance,
    EvaluationContext context,
    TreeReference child,
    int childIndex,
  ) =>
      unpack(nodeSide.eval(sourceInstance, context.rescope(child, childIndex)));

  /// [contextSide], unpacked when it is a path.
  Object evalContextSide(
    DataInstance sourceInstance,
    EvaluationContext context,
  ) => contextSide is XPathPathExpr
      ? unpack(contextSide.eval(sourceInstance, context))
      : contextSide.eval(sourceInstance, context);

  /// [expression] as a node comparison, if it is one.
  static CompareToNodeExpression? parse(XPathExpression expression) {
    final (XPathExpression? a, XPathExpression? b) = switch (expression) {
      XPathCmpExpr(:final a, :final b) ||
      XPathEqExpr(:final a, :final b) => (a, b),
      XPathFuncExpr(:final args)
          when expression.isIdempotent && args.length == 2 =>
        (args[0], args[1]),
      _ => (null, null),
    };
    XPathPathExpr? node;
    XPathExpression? context;
    for (final sub in [a, b]) {
      if (sub is XPathPathExpr) {
        if (sub.start == PathStart.relative) {
          node = sub;
        } else {
          context = sub;
        }
      } else if (sub is XPathNumericLiteral || sub is XPathStringLiteral) {
        context = sub;
      }
    }
    return node != null && context != null
        ? CompareToNodeExpression._(node, context, expression)
        : null;
  }
}

/// Java's `Object.toString()` for the values XPath evaluation produces
/// (used for index and cache keys).
String _javaToString(Object value) => switch (value) {
  final double d => javaDoubleToString(d),
  final bool b => b ? 'true' : 'false',
  _ => '$value',
};

/// Answers `[relative-path = value]` predicates on a secondary instance
/// from an index of the candidates' values, built on first use.
///
/// Port of `EqualityExpressionIndexFilterStrategy`. Like JavaRosa it can
/// differ from raw evaluation: a candidate whose node side is missing is
/// indexed under its unpacked value, and only string context values use
/// the index.
final class EqualityExpressionIndexFilterStrategy implements FilterStrategy {
  final Map<String, Map<String, List<TreeReference>>> _index = {};

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    if (sourceInstance.instanceId == null || predicate is! XPathEqExpr) {
      return next();
    }
    final candidate = CompareToNodeExpression.parse(predicate);
    if (candidate == null || !predicate.equal) return next();
    final section = '$nodeset${candidate.nodeSide}';
    final sectionIndex = _index.putIfAbsent(section, () {
      final built = <String, List<TreeReference>>{};
      for (var i = 0; i < children.length; i++) {
        Measure.log('IndexEvaluation');
        final value = _javaToString(
          candidate.evalNodeSide(sourceInstance, context, children[i], i),
        );
        (built[value] ??= []).add(children[i]);
      }
      return built;
    });
    final absoluteValue = candidate.evalContextSide(sourceInstance, context);
    if (absoluteValue is! String) return next();
    return sectionIndex[absoluteValue] ?? const [];
  }
}

/// Caches the results of node-comparison predicates (and `and`/`or` of
/// two of them) on secondary instances, keyed by the context value.
///
/// Port of `ComparisonExpressionCacheFilterStrategy`.
final class ComparisonExpressionCacheFilterStrategy implements FilterStrategy {
  final Map<String, List<TreeReference>> _cache = {};

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    if (sourceInstance.instanceId == null) return next();
    final candidate = CompareToNodeExpression.parse(predicate);
    if (candidate != null) {
      return _cache.putIfAbsent(
        _key(sourceInstance, nodeset, predicate, context, candidate),
        next,
      );
    }
    if (predicate is XPathBoolExpr) {
      final candidateA = CompareToNodeExpression.parse(predicate.a);
      final candidateB = CompareToNodeExpression.parse(predicate.b);
      if (candidateA != null && candidateB != null) {
        final key =
            'XPathBoolExpr:${predicate.op}'
            '${_key(sourceInstance, nodeset, predicate.a, context, candidateA)}'
            '${_key(sourceInstance, nodeset, predicate.b, context, candidateB)}';
        return _cache.putIfAbsent(key, next);
      }
    }
    return next();
  }

  static String _key(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    EvaluationContext context,
    CompareToNodeExpression candidate,
  ) =>
      '$nodeset$predicate${candidate.nodeSide}'
      '${_javaToString(candidate.evalContextSide(sourceInstance, context))}';
}

/// Caches the results of idempotent predicates (no `now()`, `random()`,
/// … and no references) for one batch of evaluations.
///
/// Port of `IdempotentExpressionCacheFilterStrategy`; the dependency graph
/// uses a fresh one per batch when predicate caching is on.
final class IdempotentExpressionCacheFilterStrategy implements FilterStrategy {
  final Map<String, List<TreeReference>> _cache = {};

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    final key = '$nodeset$predicate';
    final cached = _cache[key];
    if (cached != null) return cached;
    final filtered = next();
    if (predicate.isIdempotent) _cache[key] = filtered;
    return filtered;
  }
}
