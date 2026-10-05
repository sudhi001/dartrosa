/// Port of JavaRosa's `org.javarosa.test.FormParseInit` (VM only).
library;

import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/form_index.dart';

import 'forms.dart';

/// A parsed (not initialized) form with a model and controller.
final class FormParseInit {
  FormParseInit._(this.formDef)
    : formEntryController = FormEntryController(FormEntryModel(formDef));

  /// Parses the conformance form [name].
  static Future<FormParseInit> load(String name) async =>
      FormParseInit._(await parseForm(name));

  /// The form.
  final FormDef formDef;

  /// The controller.
  final FormEntryController formEntryController;

  /// The model.
  FormEntryModel get formEntryModel => formEntryController.model;

  /// The first question, from the beginning of the form.
  QuestionDef? get firstQuestionDef {
    formEntryController.jumpToIndex(FormIndex.beginningOfForm());
    do {
      final element = formEntryModel.captionPrompt().formElement;
      if (element is QuestionDef) return element;
    } while (formEntryController.stepToNextEvent() != FormEntryEvent.endOfForm);
    return null;
  }

  /// The question at the current index, if any.
  QuestionDef? get currentQuestion {
    final caption = formEntryModel.captionPrompt();
    final element = caption.formElement;
    return element is QuestionDef ? element : null;
  }

  /// Moves to the next question; `null` at the end of the form.
  QuestionDef? nextQuestion() {
    if (formEntryController.stepToNextEvent() == FormEntryEvent.endOfForm) {
      return null;
    }
    final caption = formEntryModel.captionPrompt();
    do {
      if (caption.formElement is QuestionDef) {
        return caption.formElement as QuestionDef;
      }
    } while (formEntryController.stepToNextEvent() != FormEntryEvent.endOfForm);
    return null;
  }
}
