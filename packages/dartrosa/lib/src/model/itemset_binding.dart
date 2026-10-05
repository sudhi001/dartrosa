// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ItemsetBinding), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart' show MapEquality;

import '../i18n/localizer.dart';
import '../util/randomize.dart';
import '../xpath/exceptions.dart';
import '../xpath/expression.dart';
import '../xpath/functions.dart' show toNumericWithLongHash;
import 'condition/conditions.dart';
import 'condition/evaluation_context.dart';
import 'data/answer_value.dart';
import 'form_def.dart';
import 'form_element.dart';
import 'instance/data_instance.dart';
import 'instance/tree_reference.dart';
import 'select_choice.dart';
import 'triggerable_dag.dart';

/// The `<itemset>` of a select question: where its choices come from.
///
/// Port of `org.javarosa.core.model.ItemsetBinding`.
final class ItemsetBinding implements Localizable {
  /// Absolute reference of the source nodes.
  TreeReference? nodesetRef;

  /// Path expression for the source nodes; may be relative and have
  /// predicates (the choice filter).
  XPathConditional? nodesetExpr;

  /// Context of [nodesetExpr]: the question's reference.
  TreeReference? contextRef;

  /// Absolute reference of the label.
  TreeReference? labelRef;

  /// Path expression for the label, relative to a source node.
  XPathConditional? labelExpr;

  /// Whether the label is an itext id (`jr:itext(path)`).
  bool labelIsItext = false;

  /// Absolute reference of the value.
  TreeReference? valueRef;

  /// Path expression for the value.
  XPathConditional? valueExpr;

  TreeReference? _destRef;

  /// The question's reference (plus the copied node in copy mode).
  TreeReference? get destRef => _destRef;

  bool _limitValueToSelectChoices = true;

  /// Whether answers without a matching choice are cleared.
  bool get limitValueToSelectChoices => _limitValueToSelectChoices;

  /// Whether the choices are shuffled (`randomize(...)`).
  bool randomize = false;

  /// The `randomize()` seed expression, if any.
  XPathExpression? randomSeedExpr;

  /// Deprecated `<copy>` mode: copy subtrees instead of values.
  bool copyMode = false;

  /// Deprecated `<copy>` expression.
  XPathConditional? copyExpr;

  /// Deprecated `<copy>` absolute reference.
  TreeReference? copyRef;

  List<SelectChoice>? _cachedChoices;
  Map<TreeReference, AnswerValue?>? _cachedTriggerValues;
  double? _cachedRandomSeed;

  /// The choices for the question at [questionRef], filtered by the
  /// nodeset's predicates (and shuffled for `randomize()`).
  ///
  /// The list is reused while the main-instance values the nodeset depends
  /// on (and the seed) are unchanged. Like JavaRosa, this also drops a
  /// current answer whose choice is no longer available (for
  /// `limitValueToSelectChoices`) and binds the remaining selections to
  /// their choices.
  List<SelectChoice> getChoices(FormDef form, TreeReference questionRef) {
    final triggerValues = _currentTriggerValues(form, questionRef);
    final contextEc = EvaluationContext.withContext(
      form.evaluationContext,
      contextRef!.contextualize(questionRef)!,
    );
    final randomSeed = randomSeedExpr == null
        ? null
        : toNumericWithLongHash(
            randomSeedExpr!.eval(form.mainInstance, contextEc),
          );
    final cached = _cachedChoices;
    if (cached != null &&
        triggerValues != null &&
        const MapEquality<TreeReference, AnswerValue?>().equals(
          triggerValues,
          _cachedTriggerValues,
        ) &&
        randomSeed == _cachedRandomSeed) {
      _bindAnswer(form, questionRef, cached);
      return randomize && _cachedRandomSeed == null ? shuffle(cached) : cached;
    }
    form.publishEvent(
      EvaluationEvent('Dynamic choices', [(ref: questionRef, value: '')]),
    );
    final DataInstance formInstance;
    final instanceName = nodesetRef!.instanceName;
    if (instanceName != null) {
      formInstance =
          form.nonMainInstance(instanceName) ??
          (throw XPathException('Instance $instanceName not found'));
    } else {
      formInstance = form.mainInstance;
    }
    final items = nodesetExpr!.evalNodeset(form.mainInstance, contextEc);
    final choices = [
      for (var i = 0; i < items.length; i++)
        _choiceFor(form, formInstance, i, items[i]),
    ];
    _bindAnswer(form, questionRef, choices);
    _cachedChoices = randomize ? shuffle(choices, randomSeed) : choices;
    if (randomize) {
      // JavaRosa renumbers the unshuffled list (its own TODO doubts this).
      for (var i = 0; i < choices.length; i++) {
        choices[i].index = i;
      }
    }
    final localizer = form.localizer;
    final locale = localizer?.locale;
    if (localizer != null && locale != null) localeChanged(locale, localizer);
    _cachedTriggerValues = triggerValues;
    _cachedRandomSeed = randomSeed;
    return _cachedChoices!;
  }

  /// Main-instance values the nodeset depends on, or `null` if one of them
  /// can't be tracked (an unbound repeat reference).
  Map<TreeReference, AnswerValue?>? _currentTriggerValues(
    FormDef form,
    TreeReference questionRef,
  ) {
    final values = <TreeReference, AnswerValue?>{};
    for (final trigger in nodesetExpr!.triggers(questionRef)) {
      // Secondary instances never change.
      if (trigger.instanceName != null) continue;
      final element = form.mainInstance.resolveReference(trigger);
      if (element == null || element.isRepeatable) return null;
      values[trigger] = element.value;
    }
    return values;
  }

  SelectChoice _choiceFor(
    FormDef form,
    DataInstance formInstance,
    int i,
    TreeReference item,
  ) {
    final ec = EvaluationContext.withContext(form.evaluationContext, item);
    final label = labelExpr!.evalReadable(formInstance, ec);
    final value = valueRef != null
        ? valueExpr!.evalReadable(formInstance, ec)
        : 'dynamic:$i';
    final instanceName = item.instanceName;
    final node = instanceName != null
        ? form.nonMainInstance(instanceName)!.resolveReference(item)
        : form.mainInstance.resolveReference(item);
    final choice = SelectChoice.fromItem(
      label,
      value,
      isLocalizable: labelIsItext,
      item: node,
      labelRefName: labelRef!.lastName,
    )..index = i;
    if (copyMode) {
      choice.copyNode = form.mainInstance.resolveReference(
        copyRef!.contextualize(item)!,
      );
    }
    return choice;
  }

  /// The current answer's values, each mapped to `null` (to be filled
  /// with the matching choice); `null` without an answer.
  static Map<String, SelectChoice?>? _initializeAnswerMap(
    FormDef form,
    TreeReference questionRef,
  ) {
    final raw = form.mainInstance.resolveReference(questionRef)!.value;
    if (raw == null) return null;
    if (raw is MultipleItemsValue) {
      return {
        for (final selection in raw.selections)
          selection.choice?.value ?? selection.xmlValue!: null,
      };
    }
    return {raw.displayText: null};
  }

  void _updateAnswer(
    FormDef form,
    TreeReference questionRef,
    Map<String, SelectChoice?>? answerMap,
  ) {
    final node = form.mainInstance.resolveReference(questionRef)!;
    final raw = node.value;
    if (raw == null || !limitValueToSelectChoices) return;
    final AnswerValue? bound;
    if (raw is MultipleItemsValue) {
      bound = MultipleItemsValue([
        for (final old in raw.selections)
          if (answerMap![old.choice?.value ?? old.xmlValue] case final c?)
            Selection.ofChoice(c),
      ]);
    } else if (answerMap!.containsValue(null)) {
      bound = null;
    } else {
      bound = SelectOneValue(Selection.ofChoice(answerMap[raw.displayText]!));
    }
    node.setAnswer(bound);
  }

  /// Binds the current answer's selections to their [choices], dropping
  /// those without one (see [_updateAnswer]).
  void _bindAnswer(
    FormDef form,
    TreeReference questionRef,
    List<SelectChoice> choices,
  ) {
    final answerMap = _initializeAnswerMap(form, questionRef);
    if (answerMap != null) {
      for (final choice in choices) {
        if (answerMap.containsKey(choice.value)) {
          answerMap[choice.value] = choice;
        }
      }
    }
    _updateAnswer(form, questionRef, answerMap);
  }

  /// The value expression relative to a copied node (deprecated `<copy>`
  /// mode), else the absolute value reference. Port of `getRelativeValue`.
  XPathConditional? get relativeValue {
    final copyRef = this.copyRef;
    final relRef = copyRef == null ? valueRef : valueRef?.relativize(copyRef);
    return relRef == null
        ? null
        : XPathConditional(XPathPathExpr.fromRef(relRef));
  }

  /// Computes the absolute references once the instance exists; with
  /// [question] (on the second pass) also the destination reference.
  void initReferences(QuestionDef? question) {
    nodesetRef = _absoluteRef(nodesetExpr!, contextRef!);
    if (labelExpr != null) labelRef = _absoluteRef(labelExpr!, nodesetRef!);
    if (copyExpr != null) copyRef = _absoluteRef(copyExpr!, nodesetRef!);
    if (valueExpr != null) valueRef = _absoluteRef(valueExpr!, nodesetRef!);
    if (question != null) {
      var dest = question.bind!;
      if (copyMode) {
        dest = dest.extend(copyRef!.lastName, TreeReference.indexUnbound);
      }
      _destRef = dest;
      _limitValueToSelectChoices = question.shouldLimitValueToSelectChoices;
    }
  }

  static TreeReference _absoluteRef(
    XPathConditional expression,
    TreeReference base,
  ) => FormDef.getAbsRef(
    (expression.expr as XPathPathExpr).toTreeReference(),
    base,
  );

  @override
  void localeChanged(String locale, Localizer localizer) {
    // SelectChoice.localeChanged is a no-op in JavaRosa.
  }
}
