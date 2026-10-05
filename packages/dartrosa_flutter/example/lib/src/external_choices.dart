// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart' show FormEntryPrompt;
import 'package:dartrosa_collect/dartrosa_collect.dart'
    show isFastExternalItemsetUsed, loadItemsetChoices;
import 'package:dartrosa_external_data/dartrosa_external_data.dart'
    show ExternalDataUtil, loadSelectChoices;
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';

/// Question overrides for selects whose choices come from form media:
/// `search()` appearances (external data) and `itemsets.csv` (fast
/// external itemsets). Other selects keep the renderer's widgets.
const Map<String, QuestionWidgetBuilder> externalChoiceOverrides = {
  'selectOne': _build,
  'selectMulti': _build,
};

Widget _build(BuildContext context, Object node) =>
    ExternalChoicesQuestion(node as QuestionNode);

/// The choices of [prompt] read from form media, or `null` when they are
/// the form's own.
List<SelectChoice>? externalChoices(FormEntryPrompt prompt) {
  if (ExternalDataUtil.getSearchXPathExpression(prompt.appearanceHint) !=
      null) {
    return loadSelectChoices(prompt);
  }
  if (isFastExternalItemsetUsed(prompt)) return loadItemsetChoices(prompt);
  return null;
}

/// A select showing choices from form media.
class ExternalChoicesQuestion extends StatelessWidget {
  /// Creates the question for [node].
  const ExternalChoicesQuestion(this.node, {super.key});

  /// The select.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final scope = XFormScope.of(context);
    final controller = scope.controller;
    final prompt = FormEntryPrompt(
      controller.session.definition.formDef,
      node.index,
    );
    List<SelectChoice>? choices;
    Object? error;
    try {
      choices = externalChoices(prompt);
    } on Object catch (e) {
      error = e;
    }
    if (choices == null && error == null) {
      // The renderer's own widget, without this override.
      return XFormScope(
        controller: controller,
        delegates: scope.delegates,
        overrides: const {},
        guidanceHints: scope.guidanceHints,
        child: QuestionWidget(node),
      );
    }
    final multi = node.controlType == ControlType.selectMulti;
    final selected = switch (node.value) {
      MultipleItemsValue(:final selections) => {
        for (final s in selections) s.value,
      },
      SelectOneValue(:final selection) => {selection.value},
      _ => <String>{},
    };
    void toggle(SelectChoice choice) {
      final values = multi ? {...selected} : <String>{};
      if (!values.remove(choice.value)) values.add(choice.value);
      final picked = [
        for (final c in choices!)
          if (values.contains(c.value)) Selection(c.value),
      ];
      controller.answer(
        node.index,
        picked.isEmpty
            ? null
            : multi
            ? MultipleItemsValue(picked)
            : SelectOneValue(picked.single),
      );
    }

    final failure = controller.errorFor(node.index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          XFormLabel(node.label, required: node.isRequired),
          XFormHint(node),
          if (error != null)
            Text(
              'Choices unavailable: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final c in choices ?? const <SelectChoice>[])
            CheckboxListTile(
              value: selected.contains(c.value),
              title: Text(prompt.selectChoiceText(c) ?? c.value),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: node.isReadonly ? null : (_) => toggle(c),
            ),
          if (failure != null)
            Text(
              failure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
