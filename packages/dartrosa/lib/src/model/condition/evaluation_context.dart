import '../../util/measure.dart';
import '../../xpath/expression.dart';
import '../../xpath/nodeset.dart';
import '../data/answer_value.dart';
import '../instance/data_instance.dart';
import '../instance/tree_element.dart';
import '../instance/tree_reference.dart';

/// An argument type a [XPathFunctionHandler] prototype can declare.
///
/// Port of the `Class` entries of JavaRosa prototypes: [boolean],
/// [number], [string] and [date] arguments are converted when needed;
/// other types (including custom ones from [XPathArgType.ofType]) must
/// match as they are.
final class XPathArgType {
  const XPathArgType._(this._name, this._accepts);

  /// A custom type: matches values that are a [T].
  static XPathArgType ofType<T extends Object>() =>
      XPathArgType._('$T', (value) => value is T);

  /// Converted with XPath `boolean()` if needed.
  static const boolean = XPathArgType._('Boolean', _isBool);

  /// Converted with XPath `number()` if needed (a `double`).
  static const number = XPathArgType._('Double', _isDouble);

  /// Converted with XPath `string()` if needed.
  static const string = XPathArgType._('String', _isString);

  /// Converted with `date()` if needed (a `DateTime`).
  static const date = XPathArgType._('Date', _isDate);

  /// Any value, passed unchanged.
  static const any = XPathArgType._('Object', _isAny);

  final String _name;
  final bool Function(Object value) _accepts;

  /// Whether [value] already has this type.
  bool accepts(Object value) => _accepts(value);

  static bool _isBool(Object value) => value is bool;
  static bool _isDouble(Object value) => value is double;
  static bool _isString(Object value) => value is String;
  static bool _isDate(Object value) => value is DateTime;
  static bool _isAny(Object value) => true;

  @override
  String toString() => _name;
}

/// A custom XPath function, such as ODK Collect's `pulldata`.
///
/// Port of `org.javarosa.core.model.condition.IFunctionHandler`.
/// Arguments are matched against [prototypes] in order and converted to the
/// declared types; if none matches and [rawArgs] is set, the unconverted
/// arguments are passed instead.
abstract class XPathFunctionHandler {
  /// The function name as written in XPath, e.g. `pulldata`.
  String get name;

  /// Accepted argument lists.
  List<List<XPathArgType>> get prototypes;

  /// Whether to receive unconverted arguments when no prototype matches.
  bool get rawArgs => false;

  /// Evaluates the function. Must return a `bool`, `double`, `String`,
  /// `DateTime` or [XPathNodeset], never `null`.
  Object eval(List<Object> args, EvaluationContext context);
}

/// Handles any function no built-in or registered handler knows.
///
/// Port of `IFallbackFunctionHandler`.
abstract interface class XPathFallbackFunctionHandler {
  /// Evaluates function [name] with [args].
  Object eval(String name, List<Object> args, EvaluationContext context);
}

/// Filters [children] of [nodeset] by [predicate], or delegates to [next].
///
/// Port of `org.javarosa.core.model.condition.FilterStrategy`; strategies
/// form a chain ending with [RawFilterStrategy].
abstract interface class FilterStrategy {
  /// The children that pass [predicate].
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  );
}

/// Evaluates the predicate for each child. Only a boolean `true` keeps a
/// child, so a numeric predicate such as `[2]` keeps nothing (JavaRosa
/// handles positions through multiplicities, not predicates).
final class RawFilterStrategy implements FilterStrategy {
  /// Creates the strategy.
  const RawFilterStrategy();

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    final passed = <TreeReference>[];
    for (var i = 0; i < children.length; i++) {
      final childContext = context.rescope(children[i], i);
      Measure.log('PredicateEvaluation');
      if (predicate.eval(sourceInstance, childContext) == true) {
        passed.add(children[i]);
      }
    }
    return passed;
  }
}

const List<FilterStrategy> _defaultFilterChain = [RawFilterStrategy()];

/// Everything an XPath expression needs to evaluate: the instances, the
/// context node, function handlers, variables and constraint state.
///
/// Port of `org.javarosa.core.model.condition.EvaluationContext`.
final class EvaluationContext {
  /// A context for [mainInstance] with optional secondary [instances]
  /// (keyed by instance id), at the root reference.
  EvaluationContext(
    DataInstance? mainInstance, [
    Map<String, DataInstance>? instances,
  ]) : _mainInstance = mainInstance,
       _instances = instances ?? {},
       contextRef = const TreeReference.root(),
       _functionHandlers = {},
       _variables = {};

  EvaluationContext._copy(EvaluationContext base, {TreeReference? context})
    : _functionHandlers = base._functionHandlers,
      fallbackFunctionHandler = base.fallbackFunctionHandler,
      _instances = base._instances,
      _variables = base._variables,
      contextRef = context ?? base.contextRef,
      _mainInstance = base._mainInstance,
      isConstraint = base.isConstraint,
      candidateValue = base.candidateValue,
      isCheckAddChild = base.isCheckAddChild,
      outputTextForm = base.outputTextForm,
      propertyLookup = base.propertyLookup,
      _original = base._original,
      contextPosition = base.contextPosition,
      _filterStrategyChain = base._filterStrategyChain;

  /// [base] with [context] as the context node.
  EvaluationContext.withContext(EvaluationContext base, TreeReference context)
    : this._copy(base, context: context);

  /// [base] with different secondary [instances] and [context] node.
  factory EvaluationContext.withInstances(
    EvaluationContext base,
    Map<String, DataInstance> instances,
    TreeReference context,
  ) => EvaluationContext._copy(base, context: context).._instances = instances;

  /// [base] evaluating against [mainInstance] and [instances].
  factory EvaluationContext.forInstance(
    DataInstance mainInstance,
    Map<String, DataInstance> instances,
    EvaluationContext base,
  ) => EvaluationContext._copy(base)
    .._instances = instances
    .._mainInstance = mainInstance;

  /// [base] with [strategies] tried before its own filter strategies.
  factory EvaluationContext.withFilterStrategies(
    EvaluationContext base,
    List<FilterStrategy> strategies,
  ) =>
      EvaluationContext._copy(base)
        .._filterStrategyChain = [...strategies, ...base._filterStrategyChain];

  DataInstance? _mainInstance;
  Map<String, DataInstance> _instances;
  final Map<String, XPathFunctionHandler> _functionHandlers;
  final Map<String, Object> _variables;
  TreeReference? _original;
  List<FilterStrategy> _filterStrategyChain = _defaultFilterChain;

  /// The context node for relative references.
  final TreeReference contextRef;

  /// Whether a constraint is being evaluated.
  bool isConstraint = false;

  /// The value being validated, when [isConstraint].
  AnswerValue? candidateValue;

  /// When [isConstraint], whether a parent's child count is being checked.
  bool isCheckAddChild = false;

  /// Looks up device/user properties for `property()` (JavaRosa's
  /// `PropertyManager`), e.g. `deviceid` or `username`.
  String? Function(String name)? propertyLookup;

  /// The itext form requested by `jr:itext()` (e.g. `audio`), if any.
  String? outputTextForm;

  /// 0-based position of the context node within the nodeset being
  /// filtered, or -1.
  int contextPosition = -1;

  /// The main instance.
  DataInstance? get mainInstance => _mainInstance;

  /// The instance with [id]: a secondary instance, or the main instance if
  /// its name is [id].
  DataInstance? instanceNamed(String id) =>
      _instances[id] ??
      (_mainInstance != null && id == _mainInstance!.name
          ? _mainInstance
          : null);

  /// The node `current()` refers to (the original context).
  TreeReference get originalContext => _original ?? contextRef;

  set originalContext(TreeReference ref) => _original = ref;

  /// Registers [handler] under its name.
  void addFunctionHandler(XPathFunctionHandler handler) =>
      _functionHandlers[handler.name] = handler;

  /// The registered function handlers by name.
  Map<String, XPathFunctionHandler> get functionHandlers =>
      Map.unmodifiable(_functionHandlers);

  /// Handles functions that no built-in or registered handler knows.
  XPathFallbackFunctionHandler? fallbackFunctionHandler;

  /// Sets variable [name]; `null` becomes `''` and `int` becomes `double`,
  /// matching XPath's value types.
  void setVariable(String name, Object? value) {
    _variables[name] = switch (value) {
      null => '',
      int() => value.toDouble(),
      _ => value,
    };
  }

  /// Sets several variables.
  void setVariables(Map<String, Object?> variables) =>
      variables.forEach(setVariable);

  /// The value of variable [name], or `null` if undefined.
  Object? variable(String name) => _variables[name];

  /// The concrete references matching the absolute [ref], with predicates
  /// applied; repeat templates are included when [includeTemplates].
  /// Returns `null` for a relative [ref].
  List<TreeReference>? expandReference(
    TreeReference ref, {
    bool includeTemplates = false,
  }) {
    if (!ref.isAbsolute) return null;
    final instance = ref.instanceName != null
        ? instanceNamed(ref.instanceName!)
        : _mainInstance;
    if (instance == null) {
      throw StateError(
        'Unable to expand reference ${ref.toString(includePredicates: true)}, '
        'no appropriate instance in evaluation context',
      );
    }
    final refs = <TreeReference>[];
    _expand(ref, instance, instance.root!.ref, refs, includeTemplates);
    return refs;
  }

  void _expand(
    TreeReference source,
    DataInstance instance,
    TreeReference working,
    List<TreeReference> refs,
    bool includeTemplates,
  ) {
    final depth = working.size;
    if (depth == source.size) {
      refs.add(working);
      return;
    }
    final name = source.nameAt(depth);
    final predicates = source.predicatesAt(depth);
    final multiplicity = source.multiplicityAt(depth);
    var matches = <TreeReference>[];
    final node = instance.resolveReference(working)!;

    if (node.numChildren > 0) {
      if (multiplicity == TreeReference.indexUnbound) {
        final children = node.childrenWithName(name);
        for (var i = 0; i < children.length; i++) {
          if (children[i].multiplicity != i) {
            throw StateError('Unexpected multiplicity mismatch');
          }
          matches.add(children[i].ref);
        }
        if (includeTemplates) {
          final template = node.getChild(name, TreeReference.indexTemplate);
          if (template != null) matches.add(template.ref);
        }
      } else if (multiplicity != TreeReference.indexAttribute) {
        final child = node.getChild(name, multiplicity);
        if (child != null) matches.add(child.ref);
      }
    }
    if (multiplicity == TreeReference.indexAttribute) {
      final attribute = node.getAttribute(null, name);
      if (attribute != null) matches.add(attribute.ref);
    }

    if (predicates != null) {
      final nodeset = working.extend(name, TreeReference.indexUnbound);
      for (var i = 0; i < predicates.length; i++) {
        final chain = i == 0 && _hasNoPredicates(nodeset)
            ? _filterStrategyChain
            : _defaultFilterChain;
        matches = _filter(instance, nodeset, predicates[i], matches, 0, chain);
      }
    }

    for (final match in matches) {
      _expand(source, instance, match, refs, includeTemplates);
    }
  }

  static bool _hasNoPredicates(TreeReference nodeset) {
    for (var i = 1; i < nodeset.size; i++) {
      if (nodeset.multiplicityAt(i) > -1) return false;
    }
    return true;
  }

  List<TreeReference> _filter(
    DataInstance instance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    int i,
    List<FilterStrategy> chain,
  ) => chain[i].filter(
    instance,
    nodeset,
    predicate,
    children,
    this,
    () => _filter(instance, nodeset, predicate, children, i + 1, chain),
  );

  /// A context for evaluating a predicate on [ref], the
  /// [position]-th (0-based) node of a nodeset.
  EvaluationContext rescope(TreeReference ref, int position) {
    final context = EvaluationContext.withContext(this, ref)
      ..contextPosition = position;
    if (_original != null) {
      context.originalContext = originalContext;
    } else if (contextRef == const TreeReference.root()) {
      // No context yet: the nodeset itself is the original context.
      context.originalContext = ref;
    } else {
      context.originalContext = contextRef;
    }
    return context;
  }

  /// The element [ref] points to, in the main or the named instance.
  TreeElement? resolveReference(TreeReference ref) {
    final instance = ref.instanceName != null
        ? instanceNamed(ref.instanceName!)
        : _mainInstance;
    return instance!.resolveReference(ref);
  }
}
