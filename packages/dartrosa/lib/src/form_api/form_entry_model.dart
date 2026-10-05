// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormEntryController, FormEntryModel), Copyright (C)
//  2009 JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:logging/logging.dart';

import '../model/data/answer_value.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/form_index.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import 'form_entry_caption.dart';
import 'form_entry_prompt.dart';

final _log = Logger('dartrosa.form_entry');

/// What is at a form index while filling a form.
///
/// Port of the `FormEntryController.EVENT_*` constants (the [code]s).
enum FormEntryEvent {
  /// Before the first element.
  beginningOfForm(0),

  /// After the last element.
  endOfForm(1),

  /// The point where another repeat instance may be added.
  promptNewRepeat(2),

  /// A question.
  question(4),

  /// A group.
  group(8),

  /// A repeat instance.
  repeat(16),

  /// A repeat juncture (non-linear repeat navigation).
  repeatJuncture(32);

  const FormEntryEvent(this.code);

  /// JavaRosa's constant value.
  final int code;
}

/// How repeats are navigated.
///
/// Port of `FormEntryModel.REPEAT_STRUCTURE_*`.
enum RepeatStructure {
  /// Instances one after another, then a new-repeat prompt (Collect).
  linear,

  /// A juncture before the repeat (from which instances are chosen).
  nonLinear,
}

/// The state of filling a form: the current index and what is at an index
/// (event, prompts, relevance, read-only), plus index arithmetic.
///
/// Port of `org.javarosa.form.api.FormEntryModel`.
final class FormEntryModel {
  /// A model for [form] starting before the first element. Non-linear
  /// repeats fall back to linear when the form has `jr:count` repeats.
  FormEntryModel(
    this.form, {
    RepeatStructure repeatStructure = RepeatStructure.linear,
  }) : repeatStructure =
           repeatStructure == RepeatStructure.nonLinear &&
               _containsRepeatGuesses(form)
           ? RepeatStructure.linear
           : repeatStructure,
       _currentFormIndex = FormIndex.beginningOfForm();

  /// The form being filled.
  final FormDef form;

  /// How repeats are navigated.
  final RepeatStructure repeatStructure;

  FormIndex _currentFormIndex;

  /// App-defined extra state. Port of `getExtras()`.
  final Map<Object, Object?> extras = {};

  /// The current index.
  FormIndex get formIndex => _currentFormIndex;

  /// What is at [index] (by default the current index).
  FormEntryEvent event([FormIndex? index]) {
    index ??= _currentFormIndex;
    if (index.isBeginningOfFormIndex) return FormEntryEvent.beginningOfForm;
    if (index.isEndOfFormIndex) return FormEntryEvent.endOfForm;
    final element = form.elementAt(index);
    if (element is GroupDef) {
      if (!element.isRepeat) return FormEntryEvent.group;
      if (repeatStructure != RepeatStructure.nonLinear &&
          form.mainInstance.resolveReference(form.childInstanceRef(index)!) ==
              null) {
        return FormEntryEvent.promptNewRepeat;
      }
      if (repeatStructure == RepeatStructure.nonLinear &&
          index.elementMultiplicity == TreeReference.indexRepeatJuncture) {
        return FormEntryEvent.repeatJuncture;
      }
      return FormEntryEvent.repeat;
    }
    return FormEntryEvent.question;
  }

  /// The instance node at [index].
  TreeElement? treeElement(FormIndex index) =>
      form.mainInstance.resolveReference(index.reference!);

  /// The form title.
  String? get formTitle => form.title;

  /// The prompt of the question at [index] (by default the current one).
  FormEntryPrompt questionPrompt([FormIndex? index]) {
    index ??= _currentFormIndex;
    if (form.elementAt(index) is! QuestionDef) {
      throw StateError(
        'Invalid query for Question prompt. Non-Question object at the form '
        'index',
      );
    }
    return FormEntryPrompt(form, index);
  }

  /// The caption of the element at [index] (by default the current one).
  FormEntryCaption captionPrompt([FormIndex? index]) =>
      FormEntryCaption(form, index ?? _currentFormIndex);

  /// The form's languages, or `null` without translations.
  List<String>? get languages => form.localizer?.availableLocales;

  /// Always 0, as in JavaRosa.
  int get completedRelevantQuestionCount => 0;

  /// Always 0, as in JavaRosa.
  int get totalRelevantQuestionCount => 0;

  /// The number of elements in the form (deep count).
  int get numQuestions => form.deepChildCount;

  /// The current language.
  String? get language => form.localizer!.locale;

  /// Sets the form's language (ignored without translations).
  set language(String? language) => form.localizer?.locale = language;

  /// Moves to [index], creating `jr:count` repeat instances on the way.
  void setQuestionIndex(FormIndex index) {
    if (_currentFormIndex == index) return;
    _createModelIfNecessary(index);
    _currentFormIndex = index;
  }

  /// Captions of the groups and the question along [index] (by default
  /// the current index), outermost first.
  List<FormEntryCaption> captionHierarchy([FormIndex? index]) {
    index ??= _currentFormIndex;
    final captions = <FormEntryCaption>[];
    FormIndex? remaining = index;
    while (remaining != null) {
      remaining = remaining.nextLevel;
      final localIndex = index.diff(remaining)!;
      final element = form.elementAt(localIndex);
      if (element is GroupDef) {
        captions.add(FormEntryCaption(form, localIndex));
      } else if (element is QuestionDef) {
        captions.add(FormEntryPrompt(form, localIndex));
      }
    }
    return captions;
  }

  /// Whether the element at [index] (by default the current one) is
  /// read-only; the beginning and end of the form are.
  bool isIndexReadonly([FormIndex? index]) {
    index ??= _currentFormIndex;
    if (!index.isInForm) return true;
    final ref = form.childInstanceRef(index)!;
    final e = event(index);
    if (e == FormEntryEvent.promptNewRepeat ||
        e == FormEntryEvent.repeatJuncture) {
      return false;
    }
    return !form.mainInstance.resolveReference(ref)!.isEnabled;
  }

  /// Whether the element at [index] (by default the current one) is
  /// relevant; a new-repeat prompt is when another instance may be added.
  bool isIndexRelevant([FormIndex? index]) {
    index ??= _currentFormIndex;
    final ref = form.childInstanceRef(index)!;
    final e = event(index);
    if (e == FormEntryEvent.promptNewRepeat) {
      if (!form.canCreateRepeatAt(ref, index)) return false;
      return form.isRepeatRelevant(ref);
    }
    if (e == FormEntryEvent.repeatJuncture) return form.isRepeatRelevant(ref);
    final node = form.mainInstance.resolveReference(ref);
    return node != null && node.isRelevant;
  }

  void _createModelIfNecessary(FormIndex index) {
    if (!index.isInForm) return;
    final element = form.elementAt(index);
    if (element is! GroupDef || !element.isRepeat) return;
    final countRef = element.count;
    if (countRef == null) return;
    final contextualized = countRef.contextualize(index.reference!)!;
    final count = form.mainInstance.resolveReference(contextualized)!.value;
    if (count == null) return;
    final fullCount = answerDataToInt(count);
    final ref = form.childInstanceRef(index)!;
    if (form.mainInstance.resolveReference(ref) == null &&
        index.terminal.instanceIndex < fullCount) {
      try {
        form.createNewRepeat(index);
      } on Exception catch (e) {
        _log.severe('Error', e);
        throw StateError('Invalid Reference while creating new repeat!$e');
      }
    }
  }

  /// Whether the element at [index] (by default the current one) is a
  /// group with `appearance="full"`.
  bool isIndexCompoundContainer([FormIndex? index]) {
    index ??= _currentFormIndex;
    final hint = captionPrompt(index).appearanceHint;
    return event(index) == FormEntryEvent.group &&
        hint != null &&
        hint.toLowerCase() == 'full';
  }

  /// Whether the question at [index] (by default the current one) is
  /// inside a compound container.
  bool isIndexCompoundElement([FormIndex? index]) {
    index ??= _currentFormIndex;
    if (event(index) != FormEntryEvent.question) return false;
    return captionHierarchy(
      index,
    ).any((caption) => isIndexCompoundContainer(caption.index));
  }

  /// The relevant indices inside [container] (by default the current
  /// index).
  List<FormIndex> compoundIndices([FormIndex? container]) {
    container ??= _currentFormIndex;
    final indices = <FormIndex>[];
    var walker = incrementIndex(container);
    while (FormIndex.isSubElement(container, walker)) {
      if (isIndexRelevant(walker)) indices.add(walker);
      walker = incrementIndex(walker);
    }
    return indices;
  }

  /// The index after [index] (into children unless not [descend]).
  FormIndex incrementIndex(FormIndex index, {bool descend = true}) {
    final indexes = <int>[];
    final multiplicities = <int>[];
    final elements = <FormElement>[];
    if (index.isEndOfFormIndex) return index;
    if (index.isBeginningOfFormIndex) {
      if (form.children.isEmpty) return FormIndex.endOfForm();
    } else {
      form.collapseIndex(index, indexes, multiplicities, elements);
    }
    _incrementHelper(indexes, multiplicities, elements, descend: descend);
    if (indexes.isEmpty) return FormIndex.endOfForm();
    return form.buildIndex(indexes, multiplicities, elements)!;
  }

  bool _isRepeat(FormElement e) => e is GroupDef && e.isRepeat;

  void _incrementHelper(
    List<int> indexes,
    List<int> multiplicities,
    List<FormElement> elements, {
    required bool descend,
  }) {
    var i = indexes.length - 1;
    var exitRepeat = false;
    if (i == -1 || elements[i] is GroupDef) {
      if (i >= 0 && _isRepeat(elements[i])) {
        if (repeatStructure == RepeatStructure.nonLinear) {
          if (multiplicities.last == TreeReference.indexRepeatJuncture) {
            descend = false;
            exitRepeat = true;
          }
        } else if (form.mainInstance.resolveReference(
              form.childInstanceRefOf(elements, multiplicities)!,
            ) ==
            null) {
          // The repeat instance doesn't exist: don't descend into it.
          descend = false;
          exitRepeat = true;
        }
      }
      if (descend) {
        final parent = i == -1 ? form : elements[i];
        if (parent.children.isNotEmpty) {
          indexes.add(0);
          multiplicities.add(0);
          elements.add(parent.children[0]);
          if (repeatStructure == RepeatStructure.nonLinear &&
              _isRepeat(elements.last)) {
            multiplicities.last = TreeReference.indexRepeatJuncture;
          }
          return;
        }
      }
    }
    while (i >= 0) {
      if (!exitRepeat && _isRepeat(elements[i])) {
        multiplicities[i] = repeatStructure == RepeatStructure.nonLinear
            ? TreeReference.indexRepeatJuncture
            : multiplicities[i] + 1;
        return;
      }
      final parent = i == 0 ? form : elements[i - 1];
      final curIndex = indexes[i];
      if (curIndex + 1 >= parent.children.length) {
        indexes.removeAt(i);
        multiplicities.removeAt(i);
        elements.removeAt(i);
        i--;
        exitRepeat = false;
      } else {
        indexes[i] = curIndex + 1;
        multiplicities[i] = 0;
        elements[i] = parent.children[curIndex + 1];
        if (repeatStructure == RepeatStructure.nonLinear &&
            _isRepeat(elements.last)) {
          multiplicities.last = TreeReference.indexRepeatJuncture;
        }
        return;
      }
    }
  }

  /// The index before [index].
  FormIndex decrementIndex(FormIndex index) {
    final indexes = <int>[];
    final multiplicities = <int>[];
    final elements = <FormElement>[];
    if (index.isBeginningOfFormIndex) return index;
    if (index.isEndOfFormIndex) {
      if (form.children.isEmpty) return FormIndex.beginningOfForm();
    } else {
      form.collapseIndex(index, indexes, multiplicities, elements);
    }
    _decrementHelper(indexes, multiplicities, elements);
    if (indexes.isEmpty) return FormIndex.beginningOfForm();
    return form.buildIndex(indexes, multiplicities, elements)!;
  }

  void _decrementHelper(
    List<int> indexes,
    List<int> multiplicities,
    List<FormElement> elements,
  ) {
    final i = indexes.length - 1;
    if (i != -1) {
      final curIndex = indexes[i];
      final curMult = multiplicities[i];
      if (repeatStructure == RepeatStructure.nonLinear &&
          _isRepeat(elements.last) &&
          multiplicities.last != TreeReference.indexRepeatJuncture) {
        multiplicities[i] = TreeReference.indexRepeatJuncture;
        return;
      } else if (repeatStructure != RepeatStructure.nonLinear && curMult > 0) {
        multiplicities[i] = curMult - 1;
      } else if (curIndex > 0) {
        indexes[i] = curIndex - 1;
        multiplicities[i] = 0;
        elements[i] = (i == 0 ? form : elements[i - 1]).children[curIndex - 1];
        if (_setRepeatNextMultiplicity(elements, multiplicities)) return;
      } else {
        indexes.removeAt(i);
        multiplicities.removeAt(i);
        elements.removeAt(i);
        return;
      }
    }
    var element = i < 0 ? form : elements[i];
    while (element is! QuestionDef) {
      if (element.children.isEmpty) return;
      final subIndex = element.children.length - 1;
      element = element.children[subIndex];
      indexes.add(subIndex);
      multiplicities.add(0);
      elements.add(element);
      if (_setRepeatNextMultiplicity(elements, multiplicities)) return;
    }
  }

  bool _setRepeatNextMultiplicity(
    List<FormElement> elements,
    List<int> multiplicities,
  ) {
    final nodeRef = form.childInstanceRefOf(elements, multiplicities)!;
    final node = form.mainInstance.resolveReference(nodeRef);
    if (node != null && !node.isRepeatable) return false;
    final last = elements.last;
    // A group without `ref` inside a repeat.
    if (last is GroupDef && !last.isRepeat) return false;
    final int mult;
    if (node == null) {
      mult = 0;
    } else {
      final parentNode = form.mainInstance.resolveReference(
        nodeRef.parentRef!,
      )!;
      mult = parentNode.childMultiplicity(node.name!);
    }
    multiplicities.last = repeatStructure == RepeatStructure.nonLinear
        ? TreeReference.indexRepeatJuncture
        : mult;
    return true;
  }

  static bool _containsRepeatGuesses(FormElement parent) {
    if (parent is GroupDef && parent.isRepeat && parent.count != null) {
      return true;
    }
    return parent.children.any(_containsRepeatGuesses);
  }
}
