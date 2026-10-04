/// Constraint hints: deriving "value must be between X and Y" from a
/// constraint expression.
///
/// Port of `org.javarosa.core.model.condition.pivot`. A constraint is
/// *pivoted* around the node being validated (the sentinel): each
/// comparison of that node with a number yields a [CmpPivot], and a
/// [RangeHint] probes the constraint just below, at and just above each
/// pivot to find the bounds.
library;

import '../../util/java_lang.dart';
import '../../xpath/conversions.dart';
import '../../xpath/expression.dart';
import '../data/answer_value.dart';
import '../instance/data_instance.dart';
import 'evaluation_context.dart';

/// The expression can't be turned into hints.
final class UnpivotableExpressionException implements Exception {
  /// Creates the exception with an optional [message].
  const UnpivotableExpressionException([this.message]);

  /// Why the expression couldn't be pivoted, if known.
  final String? message;

  @override
  String toString() => message ?? 'UnpivotableExpressionException';
}

/// A comparison of the validated node with [value] using [op].
final class CmpPivot {
  /// Creates a pivot.
  const CmpPivot(this.value, this.op);

  /// The number the node is compared with.
  final double value;

  /// The comparison operator (as written; not normalized for the node's
  /// side).
  final CmpOp op;
}

/// Collects the pivots of [expression] around the context node of
/// [context].
///
/// Port of `XPathExpression.pivot(DataInstance, EvaluationContext)`: any
/// error while pivoting becomes an [UnpivotableExpressionException].
List<Object> pivotsOf(
  XPathExpression expression,
  DataInstance? model,
  EvaluationContext context,
) {
  final pivots = <Object>[];
  try {
    expression.pivot(model, context, pivots, context.contextRef);
  } on UnpivotableExpressionException {
    rethrow;
  } on Object catch (e) {
    throw UnpivotableExpressionException('$e');
  }
  return pivots;
}

/// Information derived from a constraint, such as a range.
///
/// Port of `ConstraintHint`.
abstract interface class ConstraintHint {
  /// Analyses [constraint] (evaluated with [context], whose context node is
  /// the question) against [instance]. Throws
  /// [UnpivotableExpressionException] if it can't.
  void init(
    EvaluationContext context,
    XPathExpression constraint,
    FormInstance instance,
  );
}

/// A minimum and/or maximum derived from a constraint.
///
/// Port of `RangeHint`. Up to two comparisons are supported, e.g.
/// `. >= 1 and . < 10`.
abstract class RangeHint<T extends AnswerValue> implements ConstraintHint {
  double? _min;
  double? _max;
  T? _minCast;
  T? _maxCast;

  /// Whether the minimum itself is allowed.
  bool minInclusive = false;

  /// Whether the maximum itself is allowed.
  bool maxInclusive = false;

  /// The minimum, or `null` if none.
  T? get min => _min == null ? null : _minCast;

  /// The maximum, or `null` if none.
  T? get max => _max == null ? null : _maxCast;

  @override
  void init(
    EvaluationContext context,
    XPathExpression constraint,
    FormInstance instance,
  ) {
    final pivots = pivotsOf(constraint, instance, context);
    if (pivots.any((p) => p is! CmpPivot) || pivots.length > 2) {
      throw const UnpivotableExpressionException();
    }
    for (final pivot in pivots.cast<CmpPivot>()) {
      _evaluate(pivot, constraint, context, instance);
    }
  }

  void _evaluate(
    CmpPivot pivot,
    XPathExpression constraint,
    EvaluationContext context,
    FormInstance instance,
  ) {
    final value = pivot.value;
    bool passes(double candidate) {
      context
        ..isConstraint = true
        ..candidateValue = castToValue(candidate);
      return toBoolean(constraint.eval(instance, context));
    }

    final eq = passes(value);
    final below = passes(value - unit);
    final above = passes(value + unit);
    if (below && !above) {
      _max = value;
      maxInclusive = eq;
      _maxCast = castToValue(value);
    }
    if (!below && above) {
      _min = value;
      minInclusive = eq;
      _minCast = castToValue(value);
    }
  }

  /// The answer for a probed [value].
  T castToValue(double value);

  /// The probing step.
  double get unit;
}

/// Integer bounds. Port of `IntegerRangeHint`.
final class IntegerRangeHint extends RangeHint<IntegerValue> {
  @override
  IntegerValue castToValue(double value) =>
      IntegerValue(javaIntCast(value.floorToDouble()));

  @override
  double get unit => 1;
}

/// Decimal bounds. Port of `DecimalRangeHint`.
///
/// JavaRosa probes with `Double.MIN_VALUE`, which is lost in rounding for
/// most values, so this rarely finds bounds; ported as is.
final class DecimalRangeHint extends RangeHint<DecimalValue> {
  @override
  DecimalValue castToValue(double value) => DecimalValue(value);

  @override
  double get unit => 5e-324;
}

/// Date bounds (days since the epoch). Port of `DateRangeHint`.
final class DateRangeHint extends RangeHint<DateValue> {
  @override
  DateValue castToValue(double value) =>
      DateValue(toDate(value.floorToDouble(), preserveTime: false) as DateTime);

  @override
  double get unit => 1;
}

/// String length bounds, e.g. from `string-length(.) <= 10`. Port of
/// `StringLengthRangeHint`.
final class StringLengthRangeHint extends RangeHint<StringValue> {
  @override
  StringValue castToValue(double value) =>
      StringValue('X' * javaIntCast(value).clamp(0, 1 << 30));

  @override
  double get unit => 1;
}
