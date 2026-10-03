import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../model/instance/tree_reference.dart';
import '../util/java_double.dart';
import 'exceptions.dart';
import 'qname.dart';

/// A parsed XPath expression.
///
/// Port of `org.javarosa.xpath.expr.XPathExpression` and its subclasses.
/// Expressions are immutable values: equality and [toString] match
/// JavaRosa exactly, because the engine keys its dependency graph on them
/// and conformance tests compare their string form.
@immutable
sealed class XPathExpression {
  const XPathExpression();

  /// Whether evaluating this expression twice in the same form state always
  /// gives the same result (used to cache predicate results).
  bool get isIdempotent;

  /// Whether this expression calls the function named [name] anywhere.
  bool containsFunc(String name);

  /// Structural equality, matching JavaRosa's `equals`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XPathExpression &&
          other.runtimeType == runtimeType &&
          _equals(other));

  /// Compares with [other], which has the same runtime type.
  bool _equals(covariant XPathExpression other);

  /// Hash of [toString], as in JavaRosa.
  @override
  int get hashCode => toString().hashCode;
}

/// A number literal such as `5` or `.25`.
final class XPathNumericLiteral extends XPathExpression {
  /// Creates a literal for [value].
  const XPathNumericLiteral(this.value);

  /// The literal's value.
  final double value;

  @override
  bool get isIdempotent => true;

  @override
  bool containsFunc(String name) => false;

  @override
  String toString() => '{num:${javaDoubleToString(value)}}';

  @override
  bool _equals(XPathNumericLiteral other) =>
      value.isNaN ? other.value.isNaN : value == other.value;
}

/// A string literal such as `'yes'`.
final class XPathStringLiteral extends XPathExpression {
  /// Creates a literal for [value].
  const XPathStringLiteral(this.value);

  /// The literal's value, without quotes.
  final String value;

  @override
  bool get isIdempotent => true;

  @override
  bool containsFunc(String name) => false;

  @override
  String toString() => "{str:'$value'}";

  @override
  bool _equals(XPathStringLiteral other) => value == other.value;
}

/// A variable reference such as `$name`.
final class XPathVariableReference extends XPathExpression {
  /// Creates a reference to the variable [id].
  const XPathVariableReference(this.id);

  /// The variable's name.
  final XPathQName id;

  @override
  bool get isIdempotent => true;

  @override
  bool containsFunc(String name) => false;

  @override
  String toString() => '{var:$id}';

  @override
  bool _equals(XPathVariableReference other) => id == other.id;
}

/// An expression with two operands.
sealed class XPathBinaryOpExpr extends XPathExpression {
  const XPathBinaryOpExpr(this.a, this.b);

  /// Left operand.
  final XPathExpression a;

  /// Right operand.
  final XPathExpression b;

  String get _operatorString;

  @override
  bool get isIdempotent => a.isIdempotent && b.isIdempotent;

  @override
  bool containsFunc(String name) =>
      a.containsFunc(name) || b.containsFunc(name);

  @override
  String toString() => '{binop-expr:$_operatorString,$a,$b}';

  @override
  bool _equals(XPathBinaryOpExpr other) =>
      other._operatorString == _operatorString && a == other.a && b == other.b;
}

/// Arithmetic operators.
enum ArithOp {
  /// `+`
  add('+'),

  /// `-`
  subtract('-'),

  /// `*`
  multiply('*'),

  /// `div`
  divide('/'),

  /// `mod`
  modulo('%');

  const ArithOp(this.symbol);

  /// The symbol JavaRosa uses in `toString()`.
  final String symbol;
}

/// `a + b`, `a - b`, `a * b`, `a div b`, `a mod b`.
final class XPathArithExpr extends XPathBinaryOpExpr {
  /// Creates `a op b`.
  const XPathArithExpr(this.op, super.a, super.b);

  /// The operator.
  final ArithOp op;

  @override
  String get _operatorString => op.symbol;
}

/// Boolean operators.
enum BoolOp {
  /// `and`
  and,

  /// `or`
  or,
}

/// `a and b`, `a or b`.
final class XPathBoolExpr extends XPathBinaryOpExpr {
  /// Creates `a op b`.
  const XPathBoolExpr(this.op, super.a, super.b);

  /// The operator.
  final BoolOp op;

  @override
  String get _operatorString => op.name;
}

/// Relational operators.
enum CmpOp {
  /// `<`
  lt('<'),

  /// `>`
  gt('>'),

  /// `<=`
  lte('<='),

  /// `>=`
  gte('>=');

  const CmpOp(this.symbol);

  /// The operator symbol.
  final String symbol;
}

/// `a < b`, `a > b`, `a <= b`, `a >= b`.
final class XPathCmpExpr extends XPathBinaryOpExpr {
  /// Creates `a op b`.
  const XPathCmpExpr(this.op, super.a, super.b);

  /// The operator.
  final CmpOp op;

  @override
  String get _operatorString => op.symbol;
}

/// `a = b` (when [equal]) or `a != b`.
final class XPathEqExpr extends XPathBinaryOpExpr {
  /// Creates an equality ([equal] true) or inequality test.
  const XPathEqExpr(this.equal, super.a, super.b);

  /// `true` for `=`, `false` for `!=`.
  final bool equal;

  @override
  String get _operatorString => equal ? '==' : '!=';
}

/// `a | b`. Parsed, but JavaRosa does not support evaluating it.
final class XPathUnionExpr extends XPathBinaryOpExpr {
  /// Creates `a | b`.
  const XPathUnionExpr(super.a, super.b);

  @override
  String get _operatorString => 'union';
}

/// Unary minus, `-a`.
final class XPathNumNegExpr extends XPathExpression {
  /// Creates `-a`.
  const XPathNumNegExpr(this.a);

  /// The negated operand.
  final XPathExpression a;

  @override
  bool get isIdempotent => a.isIdempotent;

  @override
  bool containsFunc(String name) => a.containsFunc(name);

  @override
  String toString() => '{unop-expr:num-neg,$a}';

  @override
  bool _equals(XPathNumNegExpr other) => a == other.a;
}

/// Functions whose result depends only on their arguments.
///
/// Port of `XPathFuncExpr.IDEMPOTENT_FUNCTIONS`.
const idempotentFunctions = {
  'regex', 'starts-with', 'ends-with', 'contains', 'substr', //
  'substring-before', 'substring-after', 'translate', 'string-length',
  'normalize-space', 'concat', 'join', 'boolean-from-string', 'string',
};

/// Functions that may return a different value on every call. JavaRosa
/// never treats two calls to them as equal.
const _volatileFunctions = {'uuid', 'random', 'once', 'now', 'today'};

/// A function call such as `concat(a, 'b')`.
final class XPathFuncExpr extends XPathExpression {
  /// Creates a call to [id] with [args].
  XPathFuncExpr(this.id, List<XPathExpression> args)
    : args = List.unmodifiable(args);

  /// The function name.
  final XPathQName id;

  /// The arguments, in order.
  final List<XPathExpression> args;

  @override
  bool get isIdempotent =>
      idempotentFunctions.contains(id.toString()) &&
      args.every((arg) => arg.isIdempotent);

  @override
  bool containsFunc(String name) =>
      name == id.name || args.any((arg) => arg.containsFunc(name));

  @override
  String toString() => '{func-expr:$id,{${args.join(',')}}}';

  /// Calls to volatile functions (`uuid`, `random`, `once`, `now`, `today`)
  /// are only equal to themselves, as in JavaRosa (whose `equals` returns
  /// false and relies on Java collections checking identity first).
  @override
  bool _equals(XPathFuncExpr other) =>
      id == other.id &&
      !_volatileFunctions.contains(id.toString()) &&
      const ListEquality<XPathExpression>().equals(args, other.args);
}

/// An expression followed by predicates, such as `f()[1]`.
///
/// Parsed, but JavaRosa only evaluates it as the start of a path
/// (`instance('x')/root`, `current()/..`).
final class XPathFilterExpr extends XPathExpression {
  /// Creates `x[predicates…]`.
  XPathFilterExpr(this.x, List<XPathExpression> predicates)
    : predicates = List.unmodifiable(predicates);

  /// The filtered expression.
  final XPathExpression x;

  /// Predicates, in order.
  final List<XPathExpression> predicates;

  @override
  bool get isIdempotent =>
      x.isIdempotent && predicates.every((p) => p.isIdempotent);

  @override
  bool containsFunc(String name) =>
      x.containsFunc(name) || predicates.any((p) => p.containsFunc(name));

  @override
  String toString() => '{filt-expr:$x,{${predicates.join(',')}}}';

  @override
  bool _equals(XPathFilterExpr other) =>
      x == other.x &&
      const ListEquality<XPathExpression>().equals(
        predicates,
        other.predicates,
      );
}

/// Where a location path starts.
enum PathStart {
  /// `/a/b`
  root,

  /// `a/b`, `./a`, `../a`
  relative,

  /// `instance('x')/a`, `current()/a`: starts at [XPathPathExpr.filterExpr].
  expression,
}

/// A location path such as `/data/age` or `../name[1]`.
final class XPathPathExpr extends XPathExpression {
  /// Creates a path starting at the root or the context node.
  XPathPathExpr(this.start, List<XPathStep> steps)
    : assert(start != PathStart.expression, 'use XPathPathExpr.fromFilter'),
      filterExpr = null,
      steps = List.unmodifiable(steps);

  /// Creates a path starting at the result of [filterExpr].
  XPathPathExpr.fromFilter(
    XPathFilterExpr this.filterExpr,
    List<XPathStep> steps,
  ) : start = PathStart.expression,
      steps = List.unmodifiable(steps);

  /// The relative or absolute path for [ref], with plain child steps.
  ///
  /// Port of `XPathPathExpr.fromRef`.
  factory XPathPathExpr.fromRef(TreeReference ref) =>
      XPathPathExpr(ref.isAbsolute ? PathStart.root : PathStart.relative, [
        for (var i = 0; i < ref.size; i++)
          ref.nameAt(i) == TreeReference.nameWildcard
              ? XPathStep.typed(XPathAxis.child, StepTest.nameWildcard)
              : XPathStep.named(
                  XPathAxis.child,
                  XPathQName.parse(ref.nameAt(i)),
                ),
      ]);

  /// Where the path starts.
  final PathStart start;

  /// The starting expression when [start] is [PathStart.expression].
  final XPathFilterExpr? filterExpr;

  /// The steps, in order.
  final List<XPathStep> steps;

  @override
  bool get isIdempotent =>
      (filterExpr?.isIdempotent ?? true) &&
      steps.every((step) => step.predicates.every((p) => p.isIdempotent));

  @override
  bool containsFunc(String name) =>
      (filterExpr?.containsFunc(name) ?? false) ||
      steps.any((step) => step.predicates.any((p) => p.containsFunc(name)));

  @override
  String toString() {
    final head = switch (start) {
      PathStart.root => 'abs',
      PathStart.relative => 'rel',
      PathStart.expression => filterExpr.toString(),
    };
    return '{path-expr:$head,{${steps.join(',')}}}';
  }

  @override
  bool _equals(XPathPathExpr other) =>
      start == other.start &&
      const ListEquality<XPathStep>().equals(steps, other.steps) &&
      (start != PathStart.expression || filterExpr == other.filterExpr);

  /// This path as a [TreeReference].
  ///
  /// Only the subset JavaRosa supports is allowed: `child::name`, `*`,
  /// `@name`, `.` and leading `..` steps (with predicates), starting at the
  /// root, the context node, `instance('id')` or `current()`. Anything else
  /// throws [XPathUnsupportedException].
  ///
  /// Port of `XPathPathExpr.getReference`.
  TreeReference toTreeReference() {
    TreeReference ref;
    bool parentsAllowed;
    switch (start) {
      case PathStart.root:
        ref = const TreeReference.root();
        parentsAllowed = false;
      case PathStart.relative:
        ref = const TreeReference.relative();
        parentsAllowed = true;
      case PathStart.expression:
        final x = filterExpr!.x;
        if (x is! XPathFuncExpr) {
          // Also reached when a boolean operator is missing.
          throw XPathUnsupportedException('filter expression: $this');
        }
        switch (x.id.toString()) {
          case 'instance':
            parentsAllowed = false;
            if (x.args.length != 1) {
              throw XPathUnsupportedException(
                'instance() function used with ${x.args.length} arguments. '
                'Expecting 1 argument',
              );
            }
            final arg = x.args.first;
            if (arg is! XPathStringLiteral) {
              throw XPathUnsupportedException(
                'instance() function expecting 1 string literal argument',
              );
            }
            ref = const TreeReference.root()
                .withContextType(ReferenceContext.instance)
                .withInstanceName(arg.value);
          case 'current':
            // current() in a calculate is the node itself; in a choice
            // filter it is the select question, not the itemset node.
            parentsAllowed = true;
            ref = const TreeReference.relative().withContextType(
              ReferenceContext.original,
            );
          default:
            throw XPathUnsupportedException('filter expression');
        }
    }

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      const unsupported = "step other than 'child::name', '.', '..'";
      switch (step.axis) {
        case XPathAxis.self:
          if (step.test != StepTest.node) {
            throw XPathUnsupportedException(unsupported);
          }
        case XPathAxis.parent:
          if (!parentsAllowed || step.test != StepTest.node) {
            throw XPathUnsupportedException(unsupported);
          }
          ref = ref.withIncrementedRefLevel();
        case XPathAxis.attribute:
          if (step.test != StepTest.name) {
            throw XPathUnsupportedException(
              "attribute step other than 'attribute::name",
            );
          }
          ref = ref.extend(step.name.toString(), TreeReference.indexAttribute);
          parentsAllowed = false;
        case XPathAxis.child:
          if (step.test == StepTest.name) {
            ref = ref.extend(step.name.toString(), TreeReference.indexUnbound);
          } else if (step.test == StepTest.nameWildcard) {
            ref = ref.extend(
              TreeReference.nameWildcard,
              TreeReference.indexUnbound,
            );
          } else {
            throw XPathUnsupportedException(unsupported);
          }
          parentsAllowed = true;
        default:
          throw XPathUnsupportedException(unsupported);
      }
      if (step.predicates.isNotEmpty) {
        // ".." steps add no level, so shift the index back by refLevel.
        final level = ref.refLevel > 0 ? i - ref.refLevel : i;
        ref = ref.withPredicates(level, step.predicates);
      }
    }
    return ref;
  }

  /// Like `==`, but a named step also matches a wildcard (`*`) step.
  ///
  /// Reflexive and symmetric but not transitive. Port of
  /// `XPathPathExpr.matches`.
  bool matches(XPathExpression other) {
    if (other is! XPathPathExpr ||
        start != other.start ||
        steps.length != other.steps.length) {
      return false;
    }
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i].matches(other.steps[i])) return false;
    }
    return start != PathStart.expression || filterExpr == other.filterExpr;
  }
}

/// XPath axes.
enum XPathAxis {
  /// `child::`
  child('child'),

  /// `descendant::`
  descendant('descendant'),

  /// `parent::`
  parent('parent'),

  /// `ancestor::`
  ancestor('ancestor'),

  /// `following-sibling::`
  followingSibling('following-sibling'),

  /// `preceding-sibling::`
  precedingSibling('preceding-sibling'),

  /// `following::`
  following('following'),

  /// `preceding::`
  preceding('preceding'),

  /// `attribute::` or `@`
  attribute('attribute'),

  /// `namespace::`
  namespace('namespace'),

  /// `self::`
  self('self'),

  /// `descendant-or-self::`
  descendantOrSelf('descendant-or-self'),

  /// `ancestor-or-self::`
  ancestorOrSelf('ancestor-or-self');

  const XPathAxis(this.xpathName);

  /// The axis name as written in XPath.
  final String xpathName;

  /// Looks up an axis by its XPath name, or returns `null`.
  static XPathAxis? fromName(String name) =>
      values.firstWhereOrNull((axis) => axis.xpathName == name);
}

/// Kinds of node test in a step.
enum StepTest {
  /// A name such as `age` or `jr:x`.
  name,

  /// `*`
  nameWildcard,

  /// `prefix:*`
  namespaceWildcard,

  /// `node()`
  node,

  /// `text()`
  text,

  /// `comment()`
  comment,

  /// `processing-instruction()`
  processingInstruction,
}

/// One step of a location path, such as `child::age[1]`.
///
/// Port of `org.javarosa.xpath.expr.XPathStep`.
@immutable
final class XPathStep {
  /// A name-test step such as `age` or `@id`.
  XPathStep.named(
    this.axis,
    XPathQName this.name, [
    List<XPathExpression> predicates = const [],
  ]) : test = StepTest.name,
       namespace = null,
       literal = null,
       predicates = List.unmodifiable(predicates);

  /// A `prefix:*` step.
  XPathStep.namespaceWildcard(
    this.axis,
    String this.namespace, [
    List<XPathExpression> predicates = const [],
  ]) : test = StepTest.namespaceWildcard,
       name = null,
       literal = null,
       predicates = List.unmodifiable(predicates);

  /// A `*`, `node()`, `text()`, `comment()` or
  /// `processing-instruction(literal)` step.
  XPathStep.typed(
    this.axis,
    this.test, {
    this.literal,
    List<XPathExpression> predicates = const [],
  }) : assert(
         test != StepTest.name && test != StepTest.namespaceWildcard,
         'use XPathStep.named or XPathStep.namespaceWildcard',
       ),
       name = null,
       namespace = null,
       predicates = List.unmodifiable(predicates);

  /// `.`
  XPathStep.abbreviatedSelf() : this.typed(XPathAxis.self, StepTest.node);

  /// `..`
  XPathStep.abbreviatedParent() : this.typed(XPathAxis.parent, StepTest.node);

  /// The step inserted for `//`.
  XPathStep.abbreviatedDescendants()
    : this.typed(XPathAxis.descendantOrSelf, StepTest.node);

  /// The axis.
  final XPathAxis axis;

  /// The kind of node test.
  final StepTest test;

  /// The name, for [StepTest.name] only.
  final XPathQName? name;

  /// The namespace prefix, for [StepTest.namespaceWildcard] only.
  final String? namespace;

  /// The literal, for [StepTest.processingInstruction] only.
  final String? literal;

  /// Predicates, in order.
  final List<XPathExpression> predicates;

  /// The node test as JavaRosa prints it.
  String get testString => switch (test) {
    StepTest.name => name.toString(),
    StepTest.nameWildcard => '*',
    StepTest.namespaceWildcard => '$namespace:*',
    StepTest.node => 'node()',
    StepTest.text => 'text()',
    StepTest.comment => 'comment()',
    StepTest.processingInstruction =>
      "proc-instr(${literal == null ? '' : "'$literal'"})",
  };

  @override
  String toString() {
    final predicateString = predicates.isEmpty
        ? ''
        : ',{${predicates.join(',')}}';
    return '{step:${axis.xpathName},$testString$predicateString}';
  }

  @override
  bool operator ==(Object other) =>
      other is XPathStep &&
      axis == other.axis &&
      test == other.test &&
      _sameTestDetail(other) &&
      const ListEquality<XPathExpression>().equals(
        predicates,
        other.predicates,
      );

  @override
  int get hashCode => Object.hash(
    axis,
    test,
    name,
    literal,
    namespace,
    Object.hashAllUnordered(predicates),
  );

  /// Like `==`, but a name test also matches `*`. Port of
  /// `XPathStep.matches`.
  bool matches(XPathStep other) {
    final nameVsWildcard =
        (test == StepTest.name && other.test == StepTest.nameWildcard) ||
        (test == StepTest.nameWildcard && other.test == StepTest.name);
    if (axis != other.axis ||
        (test != other.test && !nameVsWildcard) ||
        predicates.length != other.predicates.length) {
      return false;
    }
    if (test == StepTest.name &&
        other.test != StepTest.nameWildcard &&
        name != other.name) {
      return false;
    }
    if (test != StepTest.name && !_sameTestDetail(other)) return false;
    return const ListEquality<XPathExpression>().equals(
      predicates,
      other.predicates,
    );
  }

  bool _sameTestDetail(XPathStep other) => switch (test) {
    StepTest.name => name == other.name,
    StepTest.namespaceWildcard => namespace == other.namespace,
    StepTest.processingInstruction => literal == other.literal,
    _ => true,
  };
}
