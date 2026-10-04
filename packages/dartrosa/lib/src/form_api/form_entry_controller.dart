import '../model/condition/evaluation_context.dart';
import '../model/data/answer_value.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/form_index.dart';
import '../model/instance/tree_element.dart';
import 'form_entry_model.dart';

/// The outcome of answering a question.
///
/// Port of `FormEntryController.ANSWER_*`.
enum AnswerStatus {
  /// Saved.
  ok,

  /// Not saved: the question is required and the answer is empty.
  requiredButEmpty,

  /// Not saved: the answer violates the constraint.
  constraintViolated,
}

/// Runs after [FormEntryController.finalizeFormEntry] (for example ODK
/// Collect's entities).
///
/// Port of `org.javarosa.form.api.FormEntryFinalizationProcessor`.
abstract interface class FormEntryFinalizationProcessor {
  /// Processes the finalized form.
  void processForm(FormEntryModel model);
}

/// Navigates a form and answers its questions.
///
/// Port of `org.javarosa.form.api.FormEntryController`.
final class FormEntryController {
  /// A controller for [model].
  FormEntryController(this.model);

  /// The form state.
  final FormEntryModel model;

  final List<FormEntryFinalizationProcessor> _finalizationProcessors = [];

  FormDef get _form => model.form;

  /// Answers the question at [index] (by default the current one) with
  /// [data] if it is non-empty for a required question and satisfies the
  /// constraint.
  AnswerStatus answerQuestion(
    AnswerValue? data, {
    FormIndex? index,
    bool midSurvey = false,
  }) {
    index ??= model.formIndex;
    final question = model.questionPrompt(index).question;
    if (model.event(index) != FormEntryEvent.question) {
      throw StateError('Non-Question object at the form index.');
    }
    final element = model.treeElement(index)!;
    final complex = question.isComplex;
    if (element.isRequired && data == null) {
      return AnswerStatus.requiredButEmpty;
    }
    if (!complex && !_form.evaluateConstraint(index.reference!, data)) {
      return AnswerStatus.constraintViolated;
    }
    if (!complex) {
      _commitAnswer(element, index, data, midSurvey: midSurvey);
    } else {
      _form.copyItemsetAnswer(question, element, data);
    }
    return AnswerStatus.ok;
  }

  /// Saves [data] at [index] (by default the current question) without
  /// checks; whether anything was saved.
  bool saveAnswer(
    AnswerValue? data, {
    FormIndex? index,
    bool midSurvey = false,
  }) {
    index ??= model.formIndex;
    if (model.event(index) != FormEntryEvent.question) {
      throw StateError('Non-Question object at the form index.');
    }
    return _commitAnswer(
      model.treeElement(index)!,
      index,
      data,
      midSurvey: midSurvey,
    );
  }

  bool _commitAnswer(
    TreeElement element,
    FormIndex index,
    AnswerValue? data, {
    required bool midSurvey,
  }) {
    if (data == null && element.value == null) return false;
    _form.setValue(data, index.reference!, midSurvey: midSurvey);
    return true;
  }

  /// Moves to the next relevant element; returns what is there.
  FormEntryEvent stepToNextEvent() => _stepEvent(forward: true);

  /// Moves to the previous relevant element; returns what is there.
  FormEntryEvent stepToPreviousEvent() => _stepEvent(forward: false);

  /// Finalizes the form (end timestamps, revalidation actions), then runs
  /// the finalization processors.
  void finalizeFormEntry() {
    _form.postProcessInstance();
    for (final processor in _finalizationProcessors) {
      processor.processForm(model);
    }
  }

  /// Adds a processor run by [finalizeFormEntry].
  void addPostProcessor(FormEntryFinalizationProcessor processor) =>
      _finalizationProcessors.add(processor);

  FormEntryEvent _stepEvent({required bool forward}) {
    var index = model.formIndex;
    do {
      index = forward
          ? model.incrementIndex(index)
          : model.decrementIndex(index);
    } while (index.isInForm && !model.isIndexRelevant(index));
    return jumpToIndex(index);
  }

  /// Moves to [index]; returns what is there.
  FormEntryEvent jumpToIndex(FormIndex index) {
    model.setQuestionIndex(index);
    return model.event(index);
  }

  /// Moves into instance [n] of the current repeat.
  FormIndex descendIntoRepeat(int n) {
    jumpToIndex(_form.descendIntoRepeat(model.formIndex, n));
    return model.formIndex;
  }

  /// Adds an instance to the current repeat and moves into it.
  FormIndex descendIntoNewRepeat() {
    jumpToIndex(_form.descendIntoRepeat(model.formIndex, -1));
    newRepeat(model.formIndex);
    return model.formIndex;
  }

  /// Adds the repeat instance at [index] (by default the current one).
  void newRepeat([FormIndex? index]) =>
      _form.createNewRepeat(index ?? model.formIndex);

  /// Deletes the repeat instance at [index] (by default the current
  /// one); returns the deleted instance's index.
  FormIndex deleteRepeat([FormIndex? index]) =>
      _form.deleteRepeat(index ?? model.formIndex);

  /// Deletes instance [n] of the current repeat.
  void deleteRepeatAt(int n) =>
      deleteRepeat(_form.descendIntoRepeat(model.formIndex, n));

  /// The form's current language.
  String? get language => model.language;

  /// Sets the form's language.
  set language(String? language) => model.language = language;

  /// Moves forward to the new-repeat prompt of the repeat containing the
  /// current index.
  void jumpToNewRepeatPrompt() {
    final repeatIndex = _repeatGroupIndex(model.formIndex, _form);
    if (repeatIndex == null) return;
    final repeatDepth = repeatIndex.depth;
    do {
      stepToNextEvent();
    } while (model.event() != FormEntryEvent.promptNewRepeat ||
        model.formIndex.depth != repeatDepth);
  }

  static FormIndex? _repeatGroupIndex(FormIndex index, FormDef form) {
    final element = form.elementAt(index);
    if (element is GroupDef && element.isRepeat) return index;
    final previous = index.previousLevel;
    return previous == null ? null : _repeatGroupIndex(previous, form);
  }

  /// Adds a predicate filter strategy to the form.
  void addFilterStrategy(FilterStrategy strategy) =>
      _form.addFilterStrategy(strategy);

  /// Adds a custom XPath function to the form.
  void addFunctionHandler(XPathFunctionHandler handler) =>
      _form.addFunctionHandler(handler);
}

/// Where validating a form stopped: the failing question and why.
///
/// Port of `org.javarosa.core.model.ValidateOutcome`.
final class ValidateOutcome {
  /// Creates an outcome.
  const ValidateOutcome(this.failedPrompt, this.outcome);

  /// The index of the first question failing validation.
  final FormIndex failedPrompt;

  /// Why it failed.
  final AnswerStatus outcome;

  @override
  String toString() => 'ValidateOutcome($failedPrompt, $outcome)';
}

/// Whole-form validation.
extension FormDefValidation on FormDef {
  /// Re-answers every relevant question with its current answer (running
  /// required and constraint checks); the first failure, or `null` when
  /// the form is valid. Port of `FormDef.validate` /
  /// `TriggerableDag.validate`.
  ValidateOutcome? validate({bool markCompleted = true}) {
    final controller = FormEntryController(FormEntryModel(this))
      ..jumpToIndex(FormIndex.beginningOfForm());
    FormEntryEvent event;
    while ((event = controller.stepToNextEvent()) != FormEntryEvent.endOfForm) {
      if (event != FormEntryEvent.question) continue;
      final index = controller.model.formIndex;
      final status = controller.answerQuestion(
        controller.model.questionPrompt().answerValue,
        index: index,
      );
      if (markCompleted && status != AnswerStatus.ok) {
        return ValidateOutcome(index, status);
      }
    }
    return null;
  }
}
