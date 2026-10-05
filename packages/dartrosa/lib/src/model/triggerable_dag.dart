// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (EvaluationResult, Event, TriggerableDag), Copyright
//  (C) 2014 University of Washington; Copyright (C) 2009 JavaRosa; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';

import '../util/java_double.dart';
import '../xpath/exceptions.dart';
import 'condition/conditions.dart';
import 'condition/evaluation_context.dart';
import 'condition/filter_strategies.dart';
import 'data/answer_value.dart';
import 'instance/data_instance.dart';
import 'instance/tree_element.dart';
import 'instance/tree_reference.dart';

/// One node a triggerable was applied to, with the value it got.
///
/// Port of `org.javarosa.debug.EvaluationResult`.
typedef EvaluationResult = ({TreeReference ref, Object value});

/// A step of form evaluation, for debugging and tracing.
///
/// Port of `org.javarosa.debug.Event`.
final class EvaluationEvent {
  /// Creates an event.
  const EvaluationEvent(this.message, [this.results = const []]);

  /// What happened, for example `Condition`, `Recalculate` or a summary.
  final String message;

  /// The nodes affected, if any.
  final List<EvaluationResult> results;

  /// `Processing '<message>' for <ref> (<value>), ...`. Port of
  /// `Event.getDisplayMessage` (with `EvaluationResult.toString`).
  String get displayMessage =>
      "Processing '$message' for ${results.map(_resultString).join(', ')}";

  static String _resultString(EvaluationResult result) {
    final value = switch (result.value) {
      final AnswerValue v => v.displayText,
      final double d => javaDoubleToString(d),
      final v => '$v',
    };
    return '${result.ref.toShortString()} ($value)';
  }

  @override
  String toString() => results.isEmpty ? message : '$message: $results';
}

/// The dependency graph of a form's calculations and relevant, required
/// and readonly conditions: which triggerables a change re-evaluates, and
/// in which order.
///
/// Port of `org.javarosa.core.model.TriggerableDag`. JavaRosa wraps each
/// triggerable in a `QuickTriggerable` for identity hashing; Dart's
/// [Triggerable] already uses identity equality, so it is used directly.
/// JavaRosa's sets are ordered by identity hash code (different on every
/// run); DartRosa's keep registration order, one of the orders JavaRosa
/// can produce.
final class TriggerableDag {
  /// Creates an empty graph publishing evaluation events to the given
  /// callback.
  TriggerableDag(this._publish);

  final void Function(EvaluationEvent event) _publish;

  final Set<Triggerable> _allTriggerables = {};
  final Map<int, List<Triggerable>> _triggerablesByKey = {};
  Set<Triggerable> _dag = {};
  final Map<TreeReference, Set<Triggerable>> _triggerablesPerTrigger = {};
  Map<TreeReference, Triggerable> _relevancePerRepeat = {};
  final Map<Triggerable, Set<Triggerable>> _immediateCascades = {};

  /// Whether each batch of evaluations caches idempotent predicate
  /// results (`IdempotentExpressionCacheFilterStrategy`).
  bool predicateCaching = true;

  /// All registered triggerables, in registration order.
  List<Triggerable> get triggerables => List.unmodifiable(_allTriggerables);

  /// The triggerables in evaluation (topological) order, once finalized.
  List<Triggerable> get sorted => List.unmodifiable(_dag);

  /// The triggerables that a change to [trigger] (a generic reference)
  /// directly re-evaluates.
  Set<Triggerable> triggerablesFor(TreeReference trigger) => Set.unmodifiable(
    _triggerablesPerTrigger[trigger] ?? const <Triggerable>{},
  );

  /// The triggerables directly affected by [triggerable]'s targets.
  Set<Triggerable> immediateCascades(Triggerable triggerable) =>
      Set.unmodifiable(
        _immediateCascades[triggerable] ?? const <Triggerable>{},
      );

  // ------------------------------------------------------------ creation

  /// Registers [triggerable], or returns an equal one already registered
  /// (with its context narrowed to cover both).
  Triggerable addTriggerable(Triggerable triggerable) {
    // Only triggerables of the same kind with the same triggers can match,
    // so candidates are looked up by a hash of both (in registration
    // order, so the first match is JavaRosa's).
    final key = Object.hash(
      triggerable.runtimeType,
      const SetEquality<TreeReference>().hash(triggerable.triggers),
    );
    final candidates = _triggerablesByKey[key] ??= [];
    for (final existing in candidates) {
      if (existing.matches(triggerable)) {
        existing.intersectContextWith(triggerable);
        return existing;
      }
    }
    candidates.add(triggerable);
    _allTriggerables.add(triggerable);
    for (final trigger in triggerable.triggers) {
      (_triggerablesPerTrigger[trigger] ??= {}).add(triggerable);
    }
    return triggerable;
  }

  /// Orders the triggerables topologically; throws [StateError] with the
  /// nodes involved when there is a cycle.
  void finalizeTriggerables(FormInstance mainInstance, EvaluationContext ec) {
    _dag = _buildDag(_allTriggerables, _dagEdges(mainInstance, ec));
    _relevancePerRepeat = {
      for (final triggerable in _dag)
        if (triggerable is Condition)
          for (final target in triggerable.targets)
            if (mainInstance.getTemplate(target) != null) target: triggerable,
    };
  }

  List<(Triggerable, Triggerable)> _dagEdges(
    FormInstance mainInstance,
    EvaluationContext ec,
  ) {
    final edges = <(Triggerable, Triggerable)>[];
    for (final source in _allTriggerables) {
      final targets = _dependantTriggerables(mainInstance, ec, source);
      // A triggerable affecting its own triggers is a cycle.
      if (targets.contains(source)) _throwCycle(targets);
      for (final target in targets) {
        edges.add((source, target));
      }
      _immediateCascades[source] = targets;
    }
    return edges;
  }

  Set<Triggerable> _dependantTriggerables(
    FormInstance mainInstance,
    EvaluationContext ec,
    Triggerable triggerable,
  ) {
    final targets = <TreeReference>{};
    for (final target in triggerable.targets) {
      targets.add(target);
      // Relevance (and readonly) also affect the target's descendants.
      if (triggerable.isCascadingToChildren) {
        targets.addAll(_childrenOfReference(mainInstance, ec, target));
      }
    }
    final dependants = <Triggerable>{};
    for (final target in targets) {
      // Triggers are keyed on predicate-less generic references.
      final key = target.hasPredicates ? target.removePredicates() : target;
      dependants.addAll(_triggerablesPerTrigger[key] ?? const <Triggerable>{});
    }
    return dependants;
  }

  static Set<TreeReference> _childrenOfReference(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference original,
  ) {
    final descendants = <TreeReference>{};
    final template = mainInstance.getTemplatePath(original);
    if (template != null) {
      for (final child in template.children) {
        descendants
          ..add(child.ref.genericize())
          ..addAll(_childrenRefsOfElement(mainInstance, child));
      }
    } else {
      for (final ref
          in ec.expandReference(original) ?? const <TreeReference>[]) {
        final element = ec.resolveReference(ref);
        if (element is TreeElement) {
          descendants.addAll(_childrenRefsOfElement(mainInstance, element));
        }
      }
    }
    return descendants;
  }

  static Set<TreeReference> _childrenRefsOfElement(
    FormInstance mainInstance,
    TreeElement element,
  ) {
    final refs = <TreeReference>{};
    final template = mainInstance.getTemplatePath(element.ref);
    for (final child in (template ?? element).children) {
      refs
        ..add(child.ref.genericize())
        ..addAll(_childrenRefsOfElement(mainInstance, child));
    }
    return refs;
  }

  static Set<Triggerable> _buildDag(
    Set<Triggerable> vertices,
    List<(Triggerable, Triggerable)> edges,
  ) {
    final dag = <Triggerable>{};
    final remaining = {...vertices};
    var remainingEdges = edges;
    while (remaining.isNotEmpty) {
      // Roots: remaining vertices that are no edge's target.
      final roots = {...remaining};
      for (final (_, target) in remainingEdges) {
        roots.remove(target);
      }
      if (roots.isEmpty) _throwCycle(vertices);
      remaining.removeAll(roots);
      dag.addAll(roots);
      remainingEdges = [
        for (final edge in remainingEdges)
          if (!roots.contains(edge.$1)) edge,
      ];
    }
    return dag;
  }

  static Never _throwCycle(Iterable<Triggerable> triggerables) {
    final hints = StringBuffer();
    for (final triggerable in triggerables) {
      for (final target in triggerable.targets) {
        hints.write('\n${target.toString(includePredicates: true)}');
      }
    }
    var message = "Cycle detected in form's relevant and calculation logic!";
    if (hints.isNotEmpty) {
      message += '\nThe following nodes are likely involved in the loop:$hints';
    }
    throw StateError(message);
  }

  /// Checks the trigger → target graph for cycles. Port of
  /// `reportDependencyCycles` (unused by JavaRosa itself).
  void reportDependencyCycles() {
    final vertices = <TreeReference>{};
    final edges = <(TreeReference, TreeReference)>[];
    for (final MapEntry(key: trigger, value: triggered)
        in _triggerablesPerTrigger.entries) {
      vertices.add(trigger);
      final targets = <TreeReference>{
        for (final triggerable in triggered) ...triggerable.targets,
      };
      for (final target in targets) {
        vertices.add(target);
        edges.add((trigger, target));
      }
    }
    while (vertices.isNotEmpty) {
      final leaves = {...vertices};
      for (final (source, _) in edges) {
        leaves.remove(source);
      }
      if (leaves.isEmpty) {
        throw StateError(
          'Dependency cycles amongst the xpath expressions in '
          'relevant/calculate',
        );
      }
      vertices.removeAll(leaves);
      edges.removeWhere((edge) => leaves.contains(edge.$2));
    }
  }

  // ------------------------------------------------------------ evaluation

  /// Evaluates every triggerable with a target at or under [rootRef]
  /// (and what they cascade to); returns the evaluated triggerables.
  Set<Triggerable> initializeTriggerables(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference rootRef, [
    Set<Triggerable> alreadyEvaluated = const {},
  ]) {
    final genericRoot = rootRef.genericize();
    final applicable = <Triggerable>{
      for (final triggerable in _dag)
        if (triggerable.targets.any(genericRoot.isAncestorOf)) triggerable,
    };
    return _evaluate(
      mainInstance,
      ec,
      _allToTrigger(applicable),
      rootRef,
      const {},
      alreadyEvaluated,
    );
  }

  /// Re-evaluates what depends on the node at [changedRef]; returns the
  /// evaluated triggerables.
  Set<Triggerable> triggerTriggerables(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference changedRef, [
    Set<Triggerable> affectAllRepeatInstances = const {},
    Set<Triggerable> alreadyEvaluated = const {},
  ]) {
    final cascadeRoots = _triggerablesPerTrigger[changedRef.genericize()];
    if (cascadeRoots == null) return alreadyEvaluated;
    return _evaluate(
      mainInstance,
      ec,
      _allToTrigger(cascadeRoots),
      changedRef,
      affectAllRepeatInstances,
      alreadyEvaluated,
    );
  }

  Set<Triggerable> _allToTrigger(Set<Triggerable> cascadeRoots) {
    final toTrigger = {...cascadeRoots};
    var level = {...cascadeRoots};
    while (level.isNotEmpty) {
      final next = <Triggerable>{};
      for (final triggerable in level) {
        for (final cascade
            in _immediateCascades[triggerable] ?? const <Triggerable>{}) {
          if (toTrigger.add(cascade)) next.add(cascade);
        }
      }
      level = next;
    }
    return toTrigger;
  }

  Set<Triggerable> _evaluate(
    FormInstance mainInstance,
    EvaluationContext ec,
    Set<Triggerable> toTrigger,
    TreeReference changedRef,
    Set<Triggerable> affectAllRepeatInstances,
    Set<Triggerable> alreadyEvaluated,
  ) {
    final evaluated = <Triggerable>{};
    if (predicateCaching) {
      ec = EvaluationContext.withFilterStrategies(ec, [
        IdempotentExpressionCacheFilterStrategy(),
      ]);
    }
    // Topological order guarantees dependencies are evaluated first.
    for (final triggerable in _dag) {
      if (toTrigger.contains(triggerable) &&
          !alreadyEvaluated.contains(triggerable)) {
        _evaluateTriggerable(
          mainInstance,
          ec,
          triggerable,
          changedRef,
          affectsAllRepeatInstances: affectAllRepeatInstances.contains(
            triggerable,
          ),
        );
        evaluated.add(triggerable);
      }
    }
    return evaluated;
  }

  void _evaluateTriggerable(
    FormInstance mainInstance,
    EvaluationContext ec,
    Triggerable triggerable,
    TreeReference changedRef, {
    required bool affectsAllRepeatInstances,
  }) {
    // Contextualizing against the changed reference limits triggerables
    // inside a repeat to the changed instance.
    final contextRef = affectsAllRepeatInstances
        ? triggerable.context
        : triggerable.context.contextualize(changedRef)!;
    final results = <EvaluationResult>[];
    for (final qualified
        in ec.expandReference(contextRef) ?? const <TreeReference>[]) {
      try {
        for (final (ref, value) in triggerable.apply(
          mainInstance,
          EvaluationContext.withContext(ec, qualified),
          qualified,
        )) {
          results.add((ref: ref, value: value));
        }
      } on Exception catch (e) {
        throw TriggerableEvaluationException(
          "Error evaluating field '${contextRef.lastName}' ($qualified): "
          '${_message(e)}',
          e,
        );
      }
    }
    if (results.isNotEmpty) {
      _publish(
        EvaluationEvent(
          triggerable is Condition ? 'Condition' : 'Recalculate',
          results,
        ),
      );
    }
  }

  /// Java's `getMessage()` for the exceptions evaluation throws.
  static String _message(Exception e) => switch (e) {
    XPathException(:final message) => '$message',
    _ => '$e',
  };

  void _evaluateChildrenTriggerables(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeElement node,
    Set<Triggerable> alreadyEvaluated, {
    required bool created,
  }) {
    for (final child in [...node.children]) {
      final evaluated = triggerTriggerables(
        mainInstance,
        ec,
        child.ref,
        const {},
        alreadyEvaluated,
      );
      publishSummary(created ? 'Created' : 'Deleted', child.ref, evaluated);
    }
  }

  // ------------------------------------------------------------ repeats

  /// Updates the form after the repeat instance [createdElement] was
  /// added at [createdRef].
  void createRepeatInstance(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference createdRef,
    TreeElement createdElement,
  ) {
    final affectAll = _triggerablesAffectingAllInstances(
      createdRef.genericize(),
    );
    // Conditions depending on the new node's existence (count(), …).
    final phase1 = triggerTriggerables(mainInstance, ec, createdRef, affectAll);
    publishSummary('Created (phase 1)', createdRef, phase1);
    // Conditions of the node and its descendants.
    final phase2 = initializeTriggerables(mainInstance, ec, createdRef);
    publishSummary('Created (phase 2)', createdRef, phase2);
    _evaluateChildrenTriggerables(mainInstance, ec, createdElement, {
      ...phase1,
      ...phase2,
    }, created: true);
  }

  /// Updates the form after the repeat instance [deletedElement] at
  /// [deleteRef] was removed.
  void deleteRepeatInstance(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference deleteRef,
    TreeElement deletedElement,
  ) {
    final affectAll = _triggerablesAffectingAllInstances(
      deleteRef.genericize(),
    );
    final evaluated = triggerTriggerables(
      mainInstance,
      ec,
      deleteRef,
      affectAll,
    );
    _evaluateChildrenTriggerables(
      mainInstance,
      ec,
      deletedElement,
      evaluated,
      created: false,
    );
  }

  /// Triggerables inside the repeat that depend on its instance count
  /// (directly or through a triggerable outside the repeat), which must
  /// be re-evaluated in every instance.
  Set<Triggerable> _triggerablesAffectingAllInstances(
    TreeReference genericRepeatRef,
  ) {
    final result = <Triggerable>{};
    final cascadeRoots = _triggerablesPerTrigger[genericRepeatRef];
    if (cascadeRoots == null) return result;
    final outsideRepeat = <Triggerable>{};
    for (final root in cascadeRoots) {
      if (genericRepeatRef.isAncestorOf(root.context)) result.add(root);
    }
    var toConsider = cascadeRoots;
    while (toConsider.isNotEmpty) {
      final next = <Triggerable>{};
      for (final triggerable in toConsider) {
        if (!genericRepeatRef.isAncestorOf(triggerable.context, proper: true)) {
          outsideRepeat.add(triggerable);
        } else if (_cascadesTo(outsideRepeat, triggerable) ||
            _cascadesTo(result, triggerable)) {
          result.add(triggerable);
        }
        next.addAll(_immediateCascades[triggerable] ?? const <Triggerable>{});
      }
      toConsider = next;
    }
    return result;
  }

  /// Whether any of [parents] immediately cascades to [triggerable].
  bool _cascadesTo(Set<Triggerable> parents, Triggerable triggerable) {
    for (final parent in parents) {
      if (_immediateCascades[parent]?.contains(triggerable) ?? false) {
        return true;
      }
    }
    return false;
  }

  /// The relevance condition of the repeat at [genericRepeatRef], if any.
  Triggerable? relevanceForRepeat(TreeReference genericRepeatRef) =>
      _relevancePerRepeat[genericRepeatRef];

  /// Updates the form after itemset copies were made at [copyRef]
  /// (deprecated `<copy>` itemsets).
  void copyItemsetAnswer(
    FormInstance mainInstance,
    EvaluationContext ec,
    TreeReference copyRef,
    TreeElement copyToElement,
  ) {
    final targetRef = copyToElement.ref;
    final phase1 = triggerTriggerables(mainInstance, ec, copyRef);
    publishSummary('Copied itemset answer (phase 1)', targetRef, phase1);
    final phase2 = initializeTriggerables(mainInstance, ec, copyRef, phase1);
    publishSummary('Copied itemset answer (phase 2)', targetRef, phase2);
  }

  /// Publishes how many triggerables an operation fired.
  void publishSummary(
    String lead,
    TreeReference? ref,
    Iterable<Triggerable> triggerables,
  ) => _publish(
    EvaluationEvent(
      '$lead: ${ref != null ? '${ref.toShortString()}: ' : ''}'
      '${triggerables.length} triggerables were fired.',
    ),
  );
}

/// An error evaluating a calculation or condition, naming the field.
///
/// JavaRosa throws a `RuntimeException` with the same message.
final class TriggerableEvaluationException implements Exception {
  /// Creates the exception.
  const TriggerableEvaluationException(this.message, [this.cause]);

  /// The message, `Error evaluating field 'name' (ref): cause`.
  final String message;

  /// The underlying exception.
  final Object? cause;

  @override
  String toString() => message;
}
