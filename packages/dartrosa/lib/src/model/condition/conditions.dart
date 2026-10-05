import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../util/java_lang.dart';
import '../../xpath/conversions.dart';
import '../../xpath/exceptions.dart';
import '../../xpath/expression.dart';
import '../../xpath/parser.dart';
import '../data/answer_value.dart';
import '../instance/data_instance.dart';
import '../instance/tree_reference.dart';
import 'evaluation_context.dart';
import 'pivot.dart';

/// A parsed XPath expression used as a condition, calculation or nodeset,
/// together with its source text.
///
/// Port of `org.javarosa.xpath.XPathConditional` (and `IConditionExpr`).
@immutable
final class XPathConditional {
  /// Wraps an already parsed [expr].
  const XPathConditional(this.expr) : xpath = null, hasNow = false;

  /// Parses [xpath]. Throws [XPathSyntaxException].
  XPathConditional.parse(String this.xpath)
    : expr = parseXPath(xpath),
      hasNow = xpath.contains('now()');

  /// Wraps [expr], already parsed from [xpath].
  XPathConditional.fromParsed(this.expr, String this.xpath)
    : hasNow = xpath.contains('now()');

  /// The expression.
  final XPathExpression expr;

  /// The source text, when parsed from text.
  final String? xpath;

  /// Whether the source text mentions `now()` (used for timestamps).
  final bool hasNow;

  /// The unpacked value. An [XPathUnsupportedException] is re-thrown with
  /// the source text as its detail, as JavaRosa does.
  Object evalRaw(DataInstance? model, EvaluationContext context) {
    try {
      return unpack(expr.eval(model, context));
    } on XPathUnsupportedException {
      if (xpath != null) throw XPathUnsupportedException(xpath);
      rethrow;
    }
  }

  /// The value as a boolean.
  bool eval(DataInstance? model, EvaluationContext context) =>
      toBoolean(evalRaw(model, context));

  /// The value as a string.
  String evalReadable(DataInstance? model, EvaluationContext context) =>
      toXPathString(evalRaw(model, context));

  /// The node references of a path expression.
  List<TreeReference> evalNodeset(
    DataInstance? model,
    EvaluationContext context,
  ) {
    final expr = this.expr;
    if (expr is! XPathPathExpr) {
      throw StateError('evalNodeset: must be path expression');
    }
    return expr.eval(model, context).references!;
  }

  /// The references whose changes can affect this expression, anchored to
  /// [contextRef] (predicates removed; references inside predicates
  /// included).
  Set<TreeReference> triggers(TreeReference? contextRef) {
    final triggers = <TreeReference>{};
    _collectTriggers(expr, contextRef, contextRef, triggers);
    return triggers;
  }

  static void _collectTriggers(
    XPathExpression x,
    TreeReference? contextRef,
    TreeReference? originalContext,
    Set<TreeReference> triggers,
  ) {
    switch (x) {
      case XPathPathExpr():
        final ref = x.toTreeReference();
        var contextualized = ref;
        final isOriginal = ref.contextType == ReferenceContext.original;
        if (contextRef != null || (isOriginal && originalContext != null)) {
          contextualized = ref.contextualize(
            isOriginal ? originalContext! : contextRef!,
          )!;
        }
        triggers.add(contextualized.removePredicates());
        for (var i = 0; i < contextualized.size; i++) {
          final predicates = contextualized.predicatesAt(i);
          if (predicates == null) continue;
          if (!contextualized.isAbsolute) {
            throw ArgumentError("can't get triggers for relative references");
          }
          final predicateContext = contextualized
              .subReference(i)
              .removePredicates();
          for (final predicate in predicates) {
            _collectTriggers(
              predicate,
              predicateContext,
              originalContext,
              triggers,
            );
          }
        }
      case XPathBinaryOpExpr():
        _collectTriggers(x.a, contextRef, originalContext, triggers);
        _collectTriggers(x.b, contextRef, originalContext, triggers);
      case XPathNumNegExpr():
        _collectTriggers(x.a, contextRef, originalContext, triggers);
      case XPathFuncExpr():
        for (final arg in x.args) {
          _collectTriggers(arg, contextRef, originalContext, triggers);
        }
      default:
        break;
    }
  }

  /// The pivots of this expression (see [pivotsOf]).
  List<Object> pivot(DataInstance? model, EvaluationContext context) =>
      pivotsOf(expr, model, context);

  @override
  bool operator ==(Object other) =>
      other is XPathConditional && expr == other.expr;

  @override
  int get hashCode => expr.hashCode;

  @override
  String toString() => 'xpath[$expr]';
}

/// A bind's `constraint` and its message.
///
/// Port of `org.javarosa.core.model.condition.Constraint`.
final class Constraint {
  /// Creates a constraint; a message of the form `jr:itext('id')` is
  /// compiled so it can be localized.
  Constraint(this.constraint, String? message)
    : message = message == null ? null : javaTrim(message),
      _messageExpression = _compile(message == null ? null : javaTrim(message));

  /// The constraint expression.
  final XPathConditional constraint;

  /// The literal `jr:constraintMsg`, if any.
  final String? message;

  final XPathExpression? _messageExpression;

  static XPathExpression? _compile(String? message) {
    if (message == null ||
        !message.startsWith("jr:itext('") ||
        !message.endsWith("')")) {
      return null;
    }
    try {
      return parseXPath('string($message)');
    } on Object {
      return null;
    }
  }

  /// The message to show: the literal message (only for the default
  /// [textForm]), or the localized one for `jr:itext(...)` messages.
  String? constraintMessage(
    EvaluationContext context,
    FormInstance instance,
    String? textForm,
  ) {
    final expression = _messageExpression;
    if (expression == null) return textForm == null ? message : null;
    if (textForm != null) context.outputTextForm = textForm;
    try {
      final value = expression.eval(instance, context);
      return value is String && value.isNotEmpty ? value : null;
    } on Object {
      return message;
    }
  }
}

/// What a relevant/required/readonly condition does when true or false.
///
/// Port of `org.javarosa.core.model.condition.ConditionAction`.
enum ConditionAction {
  /// No action.
  none(0, cascading: false, verb: ''),

  /// Make relevant.
  relevant(1, cascading: true, verb: 'Make relevant'),

  /// Make not relevant.
  notRelevant(2, cascading: true, verb: 'Make not relevant'),

  /// Enable (not read-only).
  enable(3, cascading: false, verb: 'Enable'),

  /// Make read-only.
  readOnly(4, cascading: false, verb: 'Make read-only'),

  /// Lock.
  lock(5, cascading: false, verb: 'Lock'),

  /// Unlock.
  unlock(6, cascading: false, verb: 'Unlock'),

  /// Require.
  require(7, cascading: false, verb: 'Require'),

  /// Make not required.
  dontRequire(8, cascading: false, verb: 'Make not required');

  const ConditionAction(
    this.code, {
    required this.cascading,
    required this.verb,
  });

  /// JavaRosa's numeric code.
  final int code;

  /// Whether the action affects descendants.
  final bool cascading;

  /// Human-readable description.
  final String verb;
}

/// An expression whose result is applied to target nodes: a [Condition]
/// (relevant/required/readonly) or a [Recalculate] (calculate).
///
/// Port of `org.javarosa.core.model.condition.Triggerable` (the dependency
/// graph bookkeeping is added with the DAG in Phase 3).
sealed class Triggerable {
  Triggerable(this.expr, this._contextRef) : originalContext = _contextRef;

  /// The expression.
  final XPathConditional expr;

  TreeReference _contextRef;

  /// The generic reference used to turn triggers into absolute references.
  TreeReference get context => _contextRef;

  /// The bind's reference, as declared.
  final TreeReference originalContext;

  final Set<TreeReference> _targets = {};

  /// The nodes this triggerable sets.
  Set<TreeReference> get targets => Set.unmodifiable(_targets);

  /// Adds a node this triggerable sets.
  void addTarget(TreeReference target) => _targets.add(target);

  /// The references this triggerable depends on.
  Set<TreeReference> get triggers => expr.triggers(originalContext);

  /// Narrows the context to what this and [other] have in common.
  void intersectContextWith(Triggerable other) =>
      _contextRef = _contextRef.intersect(other._contextRef);

  /// Evaluates the expression.
  Object eval(FormInstance instance, EvaluationContext ec);

  /// Applies [result] to the node at [ref].
  void applyResult(TreeReference ref, Object result, FormInstance instance);

  /// Whether applying this can change values others depend on.
  bool get canCascade;

  /// Whether applying this affects the targets' descendants.
  bool get isCascadingToChildren;

  /// Evaluates in [context] (a concrete instance of [originalContext]) and
  /// applies the result to every matching target; returns the affected
  /// references with the result.
  List<(TreeReference, Object)> apply(
    FormInstance instance,
    EvaluationContext parentContext,
    TreeReference context,
  ) {
    final ungenericised = originalContext.contextualize(context)!;
    final ec = EvaluationContext.withContext(parentContext, ungenericised);
    final result = eval(instance, ec);
    final affected = <(TreeReference, Object)>[];
    for (final target in _targets) {
      final targetRef = target.contextualize(ec.contextRef)!;
      for (final ref in ec.expandReference(targetRef)!) {
        applyResult(ref, result, instance);
        affected.add((ref, result));
      }
    }
    return affected;
  }

  /// Whether [other] is the same kind of triggerable with an equal
  /// expression and the same triggers (contexts and targets are ignored).
  ///
  /// JavaRosa's `Triggerable.equals`, used to share one triggerable
  /// between binds; identity equality is kept for collections.
  bool matches(Triggerable other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          expr == other.expr &&
          const SetEquality<TreeReference>().equals(triggers, other.triggers));

  String get _targetList => _targets.isEmpty
      ? 'unknown refs (no targets added yet)'
      : _targets
            .map(
              (t) => t.toString(
                includePredicates: true,
                zeroIndexMultiplicity: true,
              ),
            )
            .join(', ');
}

/// A relevant, required or readonly condition. Port of `Condition`.
final class Condition extends Triggerable {
  /// Creates a condition applying [trueAction] or [falseAction].
  Condition(
    super.expr,
    super.contextRef, {
    required this.trueAction,
    required this.falseAction,
  });

  /// Applied when the expression is true.
  final ConditionAction trueAction;

  /// Applied when the expression is false.
  final ConditionAction falseAction;

  @override
  Object eval(FormInstance instance, EvaluationContext ec) {
    try {
      return expr.eval(instance, ec);
    } on XPathException catch (e) {
      e.source =
          'Condition expression for '
          '${context.toString(includePredicates: true)}';
      rethrow;
    }
  }

  @override
  void applyResult(TreeReference ref, Object result, FormInstance instance) {
    final element = instance.resolveReference(ref)!;
    switch ((result as bool) ? trueAction : falseAction) {
      case ConditionAction.relevant:
        element.isRelevant = true;
      case ConditionAction.notRelevant:
        element.isRelevant = false;
      case ConditionAction.enable:
        element.setEnabled(true);
      case ConditionAction.readOnly:
        element.setEnabled(false);
      case ConditionAction.require:
        element.isRequired = true;
      case ConditionAction.dontRequire:
        element.isRequired = false;
      default:
        break;
    }
  }

  @override
  bool get canCascade => trueAction.cascading;

  @override
  bool get isCascadingToChildren => trueAction.cascading;

  @override
  bool matches(Triggerable other) =>
      other is Condition &&
      super.matches(other) &&
      trueAction == other.trueAction &&
      falseAction == other.falseAction;

  @override
  String toString() => '${trueAction.verb} $_targetList if (${expr.xpath})';
}

/// A calculate. Port of `Recalculate`.
final class Recalculate extends Triggerable {
  /// Creates a calculation.
  Recalculate(super.expr, super.contextRef);

  @override
  Object eval(FormInstance instance, EvaluationContext ec) {
    try {
      return expr.evalRaw(instance, ec);
    } on XPathException catch (e) {
      e.source =
          'Calculate expression for '
          '${context.toString(includePredicates: true)}';
      rethrow;
    }
  }

  @override
  void applyResult(TreeReference ref, Object result, FormInstance instance) {
    final element = instance.resolveReference(ref)!;
    element.setAnswer(wrapData(result, element.dataType));
  }

  @override
  bool get canCascade => true;

  @override
  bool get isCascadingToChildren => false;

  @override
  String toString() => 'Recalculate $_targetList with (${expr.xpath})';
}
