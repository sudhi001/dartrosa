// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import 'common.dart';

/// Range: a slider over `start`..`end` by `step`, or `vertical`,
/// `picker` (a drop-down of the values), `rating` (stars) or `no-ticks`.
class RangeInput extends StatelessWidget {
  /// Creates the input for [node].
  const RangeInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final question = node.question;
    final range = question is RangeQuestion ? question : null;
    final start = double.tryParse(range?.rangeStart ?? '') ?? 0;
    final end = double.tryParse(range?.rangeEnd ?? '') ?? 10;
    final step = (double.tryParse(range?.rangeStep ?? '') ?? 1).abs();
    final value = switch (node.value) {
      IntegerValue(:final n) => n.toDouble(),
      DecimalValue(:final d) => d,
      final v? => double.tryParse(v.displayText),
      null => null,
    };
    final appearance = Appearance.parse(node.appearance);
    final values = _values(start, end, step);
    void set(double? v) => answerQuestion(
      context,
      node,
      v == null
          ? null
          : node.dataType == DataType.integer
          ? IntegerValue(v.round())
          : DecimalValue(v),
    );
    if (appearance.has('picker')) {
      return _RangePicker(
        values: values,
        value: value,
        format: _format,
        onChanged: node.isReadonly ? null : set,
      );
    }
    if (appearance.has('rating')) {
      return _Rating(
        values: [
          for (final v in values)
            if (v != 0) v,
        ],
        value: value,
        enabled: !node.isReadonly,
        onChanged: set,
      );
    }
    final low = start <= end ? start : end;
    final high = start <= end ? end : start;
    final divisions = step > 0 ? ((high - low) / step).round() : 0;
    Widget slider = Slider(
      min: low,
      max: high,
      divisions: divisions > 0 ? divisions : null,
      value: (value ?? low).clamp(low, high),
      label: value == null ? null : _format(value),
      onChanged: node.isReadonly ? null : set,
    );
    if (appearance.has('no-ticks')) {
      slider = SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
        child: slider,
      );
    }
    final current = Text(
      value == null ? '' : _format(value),
      style: Theme.of(context).textTheme.titleMedium,
    );
    if (appearance.has('vertical')) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_format(high)),
              SizedBox(
                height: 240,
                child: RotatedBox(quarterTurns: 3, child: slider),
              ),
              Text(_format(low)),
            ],
          ),
          const SizedBox(width: 16),
          current,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: slider),
            current,
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_format(low)), Text(_format(high))],
          ),
        ),
      ],
    );
  }

  /// The values from [start] to [end] (either direction) by [step].
  static List<double> _values(double start, double end, double step) {
    if (step <= 0) return [start];
    final count = ((end - start).abs() / step).round();
    if (count > 1000) return [start, end];
    final sign = end >= start ? 1 : -1;
    return [for (var i = 0; i <= count; i++) start + sign * step * i];
  }

  String _format(double v) => node.dataType == DataType.integer
      ? '${v.round()}'
      : (v == v.roundToDouble() ? '${v.round()}' : '$v');
}

/// A drop-down of a range's [values] (`picker`).
class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.values,
    required this.value,
    required this.format,
    required this.onChanged,
  });

  final List<double> values;
  final double? value;
  final String Function(double value) format;
  final ValueChanged<double?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = values.where((v) => v == value).firstOrNull;
    return DropdownButtonFormField<double>(
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      items: [
        for (final v in values)
          DropdownMenuItem(value: v, child: Text(format(v))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Stars for a `rating` range: tapping the n-th star selects the n-th
/// value.
class _Rating extends StatelessWidget {
  const _Rating({
    required this.values,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<double> values;
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == null ? -1 : values.indexOf(value!);
    final color = Theme.of(context).colorScheme.primary;
    return Wrap(
      children: [
        for (var i = 0; i < values.length; i++)
          IconButton(
            tooltip: '${i + 1}',
            isSelected: i <= selected,
            icon: Icon(Icons.star_border, color: color),
            selectedIcon: Icon(Icons.star, color: color),
            onPressed: enabled
                ? () => onChanged(i == selected ? null : values[i])
                : null,
          ),
      ],
    );
  }
}
