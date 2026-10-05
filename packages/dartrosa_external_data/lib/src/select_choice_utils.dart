// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (SelectChoiceUtils, ExternalDataUtil), Copyright (C)
//  2014 University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'external_data_exception.dart';
import 'external_data_handler_search.dart';
import 'external_data_manager.dart';
import 'external_data_util.dart';

/// The choices to show for [prompt]: those of its `search()` appearance if
/// it has one, else its own.
///
/// Port of the `search()` part of Collect's `SelectChoiceUtils
/// .loadSelectChoices` (fast external itemsets are a separate feature).
/// Throws [ExternalDataFileMissingException] or [ExternalDataException]
/// like [populateExternalChoices].
List<SelectChoice> loadSelectChoices(FormEntryPrompt prompt) {
  final search = ExternalDataUtil.getSearchXPathExpression(
    prompt.appearanceHint,
  );
  if (search != null) return populateExternalChoices(prompt, search);
  return prompt.selectChoices;
}

/// The choices of a select with the `search()` appearance [xpathFuncExpr]:
/// static choices with integer values are kept; each other choice is a
/// configuration row (value column, label columns, image column) expanded
/// into one choice per CSV row. Choices matching the current answer are
/// attached to it (so its label can be shown).
///
/// Port of Collect's `ExternalDataUtil.populateExternalChoices`. The
/// form's [ExternalDataManager] comes from its extras (see
/// `ExternalDataPlugin`). Throws [ExternalDataFileMissingException] when
/// the CSV is missing (or there is no configuration row and the CSV is
/// missing), and [ExternalDataException] for other errors.
List<SelectChoice> populateExternalChoices(
  FormEntryPrompt prompt,
  XPathFuncExpr xpathFuncExpr,
) {
  final form = prompt.form;
  final manager = form.extras.get<ExternalDataManager>();
  try {
    if (manager == null) {
      throw ExternalDataException(
        'The ExternalDataManager has not been initialized.',
      );
    }
    final answer = prompt.answerValue;
    final selections = switch (answer) {
      SelectOneValue(:final selection) => [selection],
      MultipleItemsValue(:final selections) => selections,
      _ => const <Selection>[],
    };
    final attached = <int, Selection>{};
    void attachChoiceToSelectionIfMatch(SelectChoice choice) {
      for (var i = 0; i < selections.length; i++) {
        final selection = selections[i];
        if (selection.index == -1 &&
            !attached.containsKey(i) &&
            selection.xmlValue == choice.value) {
          attached[i] = Selection.ofChoice(choice);
        }
      }
    }

    final selectChoices = prompt.selectChoices;
    if (selectChoices.every((c) => ExternalDataUtil.isAnInteger(c.value))) {
      throw ExternalDataFileMissingException(
        _filePath(xpathFuncExpr, form, manager),
      );
    }
    final returnedChoices = <SelectChoice>[];
    for (final selectChoice in selectChoices) {
      final value = selectChoice.value;
      if (ExternalDataUtil.isAnInteger(value)) {
        // A static choice.
        attachChoiceToSelectionIfMatch(selectChoice);
        returnedChoices.add(selectChoice);
        continue;
      }
      final displayColumns = prompt.selectChoiceText(selectChoice);
      var imageColumn = prompt.specialFormSelectChoiceText(
        selectChoice,
        'image',
      );
      if (imageColumn != null &&
          imageColumn.startsWith(ExternalDataUtil.jrImagesPrefix)) {
        imageColumn = imageColumn.substring(
          ExternalDataUtil.jrImagesPrefix.length,
        );
      }
      final formInstance = form.mainInstance;
      final evaluationContext = EvaluationContext.withContext(
        EvaluationContext(formInstance),
        prompt.index.reference!,
      );
      final handler = ExternalDataHandlerSearch(
        manager,
        displayColumns,
        value,
        imageColumn,
      );
      evaluationContext.addFunctionHandler(handler);
      final args = [
        for (final arg in xpathFuncExpr.args)
          arg.eval(formInstance, evaluationContext),
      ];
      for (final dynamicChoice in handler.eval(args, evaluationContext)) {
        attachChoiceToSelectionIfMatch(dynamicChoice);
        returnedChoices.add(dynamicChoice);
      }
    }
    if (attached.isNotEmpty && answer != null) {
      final updated = [
        for (var i = 0; i < selections.length; i++)
          attached[i] ?? selections[i],
      ];
      prompt.treeElement.value = switch (answer) {
        SelectOneValue() => SelectOneValue(updated.single),
        SelectMultiValue() => SelectMultiValue(updated),
        _ => MultipleItemsValue(updated),
      };
    }
    return returnedChoices;
  } on Object catch (e) {
    final fileName = _fileName(xpathFuncExpr, form);
    if (manager == null || !manager.hasMediaFile(fileName)) {
      throw ExternalDataFileMissingException(
        manager?.mediaUri(fileName) ??
            ExternalDataManager.defaultMediaUri(fileName),
      );
    }
    if (e is ExternalDataFileMissingException) {
      // Collect: the FileNotFoundException's message is the file path.
      throw ExternalDataException(e.path, e);
    }
    throw ExternalDataException(
      e is ExternalDataException ? e.message : '$e',
      e,
    );
  }
}

String _fileName(XPathFuncExpr xpathFuncExpr, FormDef form) {
  String fileName;
  try {
    fileName = toXPathString(
      xpathFuncExpr.args[0].eval(form.mainInstance, EvaluationContext(null)),
    );
  } on Object {
    fileName = '${xpathFuncExpr.args[0]}';
  }
  return fileName.endsWith('.csv') ? fileName : '$fileName.csv';
}

String _filePath(
  XPathFuncExpr xpathFuncExpr,
  FormDef form,
  ExternalDataManager manager,
) => manager.mediaUri(_fileName(xpathFuncExpr, form));
