// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormParseInit), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

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
      if (currentQuestion case final question?) return question;
    } while (formEntryController.stepToNextEvent() != FormEntryEvent.endOfForm);
    return null;
  }

  /// The question at the current index, if any.
  QuestionDef? get currentQuestion {
    final element = formEntryModel.captionPrompt().formElement;
    return element is QuestionDef ? element : null;
  }

  /// Moves to the next question; `null` at the end of the form.
  QuestionDef? nextQuestion() {
    if (formEntryController.stepToNextEvent() == FormEntryEvent.endOfForm) {
      return null;
    }
    do {
      if (currentQuestion case final question?) return question;
    } while (formEntryController.stepToNextEvent() != FormEntryEvent.endOfForm);
    return null;
  }
}
