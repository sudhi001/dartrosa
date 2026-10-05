// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';
import '../xform_scope.dart';
import 'common.dart';

/// A text question whose answer is a link (`url` appearance), opened with
/// `XFormDelegates.openLink`, like ODK Collect's `UrlWidget`.
class UrlInput extends StatelessWidget {
  /// Creates the input for [node].
  const UrlInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final strings = XFormLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.open_in_browser),
        label: Text(strings.openUrl),
        onPressed: () async {
          final text = node.displayValue;
          final uri = text == null ? null : Uri.tryParse(text);
          if (uri == null) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(strings.noUrl)));
            return;
          }
          await XFormScope.of(context).delegates.openLink(context, uri);
        },
      ),
    );
  }
}

/// A decimal question answered with a compass heading (`bearing`
/// appearance) from `XFormDelegates.compassBearing`, like ODK Collect's
/// `BearingWidget`: the bearing is saved with three decimals.
class BearingInput extends StatelessWidget {
  /// Creates the input for [node].
  const BearingInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final strings = XFormLocalizations.of(context);
    final text = node.displayValue;
    final hasValue = text != null && text.isNotEmpty;
    return AnswerWithActions(
      answer: Text(text ?? ''),
      actions: [
        if (!node.isReadonly)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.explore_outlined),
            label: Text(hasValue ? strings.replaceBearing : strings.getBearing),
            onPressed: () async {
              final degrees = await XFormScope.of(
                context,
              ).delegates.compassBearing(context);
              if (degrees == null || !context.mounted) return;
              answerQuestion(
                context,
                node,
                typedAnswer(node, degrees.toStringAsFixed(3)),
              );
            },
          ),
      ],
    );
  }
}

/// An integer question counted up and down with buttons (`counter`
/// appearance), like ODK Collect's `CounterWidget`: from 0 to
/// [maxValue], `+` on no answer gives 1.
class CounterInput extends StatelessWidget {
  /// Creates the input for [node].
  const CounterInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  /// The largest count.
  static const maxValue = 999999999;

  @override
  Widget build(BuildContext context) {
    final value = switch (node.value) {
      IntegerValue(:final n) ||
      LongValue(:final n) when n >= 0 && n <= maxValue => n,
      _ => null,
    };
    final enabled = !node.isReadonly;
    final strings = XFormLocalizations.of(context);
    void set(int n) => answerQuestion(context, node, IntegerValue(n));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: strings.decrement,
          icon: const Icon(Icons.remove),
          onPressed: enabled && value != null && value > 0
              ? () => set(value - 1)
              : null,
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Text(
              value?.toString() ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: strings.increment,
          icon: const Icon(Icons.add),
          onPressed: enabled && (value == null || value < maxValue)
              ? () => set((value ?? 0) + 1)
              : null,
        ),
      ],
    );
  }
}
