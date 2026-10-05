// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (XPathExpressionExt), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// Port of `org.odk.collect.entities.javarosa.parse.XPathExpressionExt`.
library;

import 'package:dartrosa/javarosa.dart';

import '../../storage/query.dart';

/// Converts XPath predicates to [Query]s.
extension XPathExpressionExt on XPathExpression {
  /// Converts this XPath expression to a [Query]. For example:
  /// - `label = 'blah'` will be converted to `StringEqQuery("label",
  ///   "blah")`
  /// - `label = /some/string/ref` will be converted to
  ///   `StringEqQuery("label", "blah")` (where `/some/string/ref`
  ///   evaluates to `"blah"` within the context of the passed
  ///   [DataInstance] and [EvaluationContext])
  ///
  /// `and`, `or`, `=` and `!=` are all supported. If an expression cannot
  /// be converted to a [Query], `null` will be returned.
  Query? toQuery(DataInstance sourceInstance, EvaluationContext context) =>
      switch (this) {
        final XPathBoolExpr e => _boolExprToQuery(e, sourceInstance, context),
        final XPathEqExpr e => _eqExprToQuery(e, sourceInstance, context),
        _ => null,
      };
}

Query? _boolExprToQuery(
  XPathBoolExpr predicate,
  DataInstance sourceInstance,
  EvaluationContext context,
) {
  final queryA = predicate.a.toQuery(sourceInstance, context);
  final queryB = predicate.b.toQuery(sourceInstance, context);

  if (queryA == null || queryB == null) return null;
  return predicate.op == BoolOp.and
      ? AndQuery(queryA, queryB)
      : OrQuery(queryA, queryB);
}

Query? _eqExprToQuery(
  XPathEqExpr predicate,
  DataInstance sourceInstance,
  EvaluationContext context,
) {
  final candidate = CompareToNodeExpression.parse(predicate);
  if (candidate == null) return null;

  final steps = candidate.nodeSide.steps;
  final String? child;
  if (steps.length == 1) {
    child = steps[0].name?.name;
  } else if (_isNodeRelativeExpression(steps)) {
    child = steps[1].name?.name;
  } else {
    child = null;
  }
  if (child == null) return null;

  final value = candidate.evalContextSide(sourceInstance, context);
  if (predicate.equal) {
    return value is double
        ? NumericEqQuery(child, value)
        : StringEqQuery(child, '$value');
  } else {
    return value is double
        ? NumericNotEqQuery(child, value)
        : StringNotEqQuery(child, '$value');
  }
}

bool _isNodeRelativeExpression(List<XPathStep> steps) =>
    steps.length == 2 &&
    steps[0].test == StepTest.node &&
    (steps[0].axis == XPathAxis.self || steps[0].axis == XPathAxis.child);
