import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../xform_scope.dart';
import 'label.dart';

/// A question: label, hint, the input widget for its control type and
/// appearance, and the error of a rejected answer. Rebuilds only when its
/// node changes.
class QuestionWidget extends StatelessWidget {
  /// Creates the widget for [node].
  const QuestionWidget(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final scope = XFormScope.of(context);
    final controller = scope.controller;
    return ListenableBuilder(
      listenable: controller.listenableFor(node.ref),
      builder: (context, _) {
        final appearance = node.appearance?.toLowerCase();
        final override =
            scope.overrides['${node.controlType.name}:$appearance'] ??
            scope.overrides[node.controlType.name];
        if (override != null) return override(context, node);
        final error = controller.errorFor(node.index);
        final theme = Theme.of(context);
        return Semantics(
          container: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                XFormLabel(node.label, required: node.isRequired),
                if (node.hint case final hint? when hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(hint, style: theme.textTheme.bodySmall),
                  ),
                if (!node.isNote)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _input(context),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _input(BuildContext context) => switch (node.controlType) {
    ControlType.selectOne => _SelectOne(node),
    ControlType.selectMulti => _SelectMulti(node),
    ControlType.rank => _Rank(node),
    ControlType.trigger => _Trigger(node),
    ControlType.range => _Range(node),
    ControlType.imageChoose ||
    ControlType.audioCapture ||
    ControlType.videoCapture ||
    ControlType.fileCapture ||
    ControlType.upload ||
    ControlType.osmCapture => _Media(node),
    _ => switch (node.dataType) {
      DataType.date || DataType.time || DataType.dateTime => _DateTime(node),
      DataType.geopoint || DataType.geotrace || DataType.geoshape => _Geo(node),
      DataType.barcode => _Barcode(node),
      _ => _TextInput(node),
    },
  };
}

void _answer(BuildContext context, QuestionNode node, AnswerValue? value) =>
    XFormScope.of(context).controller.answer(node.index, value);

/// Text, integer, decimal and long inputs.
class _TextInput extends StatefulWidget {
  const _TextInput(this.node);

  final QuestionNode node;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.node.value?.displayText ?? '',
  );

  @override
  void didUpdateWidget(covariant _TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculated (or read-only) values replace the text.
    final value = widget.node.value?.displayText ?? '';
    if (widget.node.isReadonly && _text.text != value) _text.text = value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  AnswerValue? _parse(String text) {
    if (text.isEmpty) return null;
    return switch (widget.node.dataType) {
      DataType.integer => switch (int.tryParse(text)) {
        final n? => IntegerValue(n),
        null => UncastValue(text),
      },
      DataType.long => switch (int.tryParse(text)) {
        final n? => LongValue(n),
        null => UncastValue(text),
      },
      DataType.decimal => switch (double.tryParse(text)) {
        final d? => DecimalValue(d),
        null => UncastValue(text),
      },
      _ => StringValue(text),
    };
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final appearance = node.appearance?.toLowerCase() ?? '';
    final numeric =
        node.dataType == DataType.integer ||
        node.dataType == DataType.long ||
        node.dataType == DataType.decimal ||
        appearance.contains('numbers');
    return TextField(
      controller: _text,
      enabled: !node.isReadonly,
      obscureText: node.controlType == ControlType.secret,
      maxLines: appearance.contains('multiline') ? null : 1,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(
              decimal: node.dataType == DataType.decimal,
              signed: true,
            )
          : TextInputType.text,
      inputFormatters: [
        if (node.dataType == DataType.integer || node.dataType == DataType.long)
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      decoration: const InputDecoration(border: OutlineInputBorder()),
      onChanged: (text) => _answer(context, node, _parse(text)),
    );
  }
}

/// Select one: radio buttons, or a dropdown for `minimal`.
class _SelectOne extends StatelessWidget {
  const _SelectOne(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final choices = node.choices;
    final selected = switch (node.value) {
      SelectOneValue(:final selection) => selection.value,
      final v? => v.displayText,
      null => null,
    };
    void select(SelectChoice? choice) => _answer(
      context,
      node,
      choice == null ? null : SelectOneValue(Selection.ofChoice(choice)),
    );
    if (node.appearance?.toLowerCase().contains('minimal') ?? false) {
      return DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        items: [
          for (final c in choices)
            DropdownMenuItem(
              value: c.value,
              child: Text(node.choiceLabel(c) ?? c.value),
            ),
        ],
        onChanged: node.isReadonly
            ? null
            : (value) => select(choices.firstWhere((c) => c.value == value)),
      );
    }
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (node.isReadonly) return;
        select(choices.where((c) => c.value == value).firstOrNull);
      },
      child: Column(
        children: [
          for (final c in choices)
            RadioListTile<String>(
              value: c.value,
              enabled: !node.isReadonly,
              title: Text(node.choiceLabel(c) ?? c.value),
              toggleable: true,
            ),
        ],
      ),
    );
  }
}

/// Select multiple: check boxes.
class _SelectMulti extends StatelessWidget {
  const _SelectMulti(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final selected = switch (node.value) {
      MultipleItemsValue(:final selections) => {
        for (final s in selections) s.value,
      },
      _ => <String>{},
    };
    final choices = node.choices;
    return Column(
      children: [
        for (final c in choices)
          CheckboxListTile(
            value: selected.contains(c.value),
            enabled: !node.isReadonly,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(node.choiceLabel(c) ?? c.value),
            onChanged: (on) {
              final values = {...selected};
              on! ? values.add(c.value) : values.remove(c.value);
              _answer(
                context,
                node,
                values.isEmpty
                    ? null
                    : MultipleItemsValue([
                        for (final choice in choices)
                          if (values.contains(choice.value))
                            Selection.ofChoice(choice),
                      ]),
              );
            },
          ),
      ],
    );
  }
}

/// Rank: a reorderable list.
class _Rank extends StatelessWidget {
  const _Rank(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final byValue = {for (final c in node.choices) c.value: c};
    final order = switch (node.value) {
      MultipleItemsValue(:final selections) => [
        for (final s in selections) ?byValue[s.value],
      ],
      _ => node.choices,
    };
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (from, to) {
        if (node.isReadonly) return;
        final list = [...order];
        final moved = list.removeAt(from);
        list.insert(to, moved);
        _answer(
          context,
          node,
          MultipleItemsValue([for (final c in list) Selection.ofChoice(c)]),
        );
      },
      children: [
        for (final c in order)
          ListTile(
            key: ValueKey(c.value),
            title: Text(node.choiceLabel(c) ?? c.value),
            trailing: const Icon(Icons.drag_handle),
          ),
      ],
    );
  }
}

/// Trigger: an acknowledgement (answer `OK`).
class _Trigger extends StatelessWidget {
  const _Trigger(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: node.value != null,
    enabled: !node.isReadonly,
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text('OK'),
    onChanged: (on) =>
        _answer(context, node, on! ? const StringValue('OK') : null),
  );
}

/// Range: a slider over `start`..`end` by `step`.
class _Range extends StatelessWidget {
  const _Range(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final question = node.question;
    final range = question is RangeQuestion ? question : null;
    final start = double.tryParse(range?.rangeStart ?? '') ?? 0;
    final end = double.tryParse(range?.rangeEnd ?? '') ?? 10;
    final step = double.tryParse(range?.rangeStep ?? '') ?? 1;
    final value = switch (node.value) {
      IntegerValue(:final n) => n.toDouble(),
      DecimalValue(:final d) => d,
      _ => null,
    };
    final divisions = step > 0 ? ((end - start) / step).round() : null;
    return Row(
      children: [
        Expanded(
          child: Slider(
            min: start,
            max: end,
            divisions: divisions != null && divisions > 0 ? divisions : null,
            value: (value ?? start).clamp(start, end),
            label: value?.toString(),
            onChanged: node.isReadonly
                ? null
                : (v) => _answer(
                    context,
                    node,
                    node.dataType == DataType.integer
                        ? IntegerValue(v.round())
                        : DecimalValue(v),
                  ),
          ),
        ),
        Text(value == null ? '' : node.value!.displayText),
      ],
    );
  }
}

/// Dates and times: pickers.
class _DateTime extends StatelessWidget {
  const _DateTime(this.node);

  final QuestionNode node;

  Future<void> _pick(BuildContext context) async {
    final current = switch (node.value) {
      DateValue(:final date) => date,
      DateTimeValue(:final dateTime) => dateTime,
      TimeValue(:final time) => time,
      _ => DateTime.now(),
    };
    DateTime? picked = current;
    if (node.dataType != DataType.time) {
      picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked == null || !context.mounted) return;
    }
    if (node.dataType != DataType.date) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null || !context.mounted) return;
      picked = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    }
    _answer(context, node, switch (node.dataType) {
      DataType.date => DateValue(picked),
      DataType.time => TimeValue(picked),
      _ => DateTimeValue(picked),
    });
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(node.displayValue ?? '—')),
      if (!node.isReadonly) ...[
        if (node.value != null)
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () => _answer(context, node, null),
          ),
        FilledButton.tonal(
          onPressed: () => _pick(context),
          child: Text(switch (node.dataType) {
            DataType.date => 'Select date',
            DataType.time => 'Select time',
            _ => 'Select date and time',
          }),
        ),
      ],
    ],
  );
}

/// A value captured by a delegate, or typed when no delegate exists.
class _Captured extends StatelessWidget {
  const _Captured({
    required this.node,
    required this.available,
    required this.capture,
    required this.buttonLabel,
    required this.icon,
  });

  final QuestionNode node;
  final bool available;
  final Future<String?> Function() capture;
  final String buttonLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!available) return _TextInput(node);
    return Row(
      children: [
        Expanded(child: Text(node.displayValue ?? '—')),
        if (!node.isReadonly)
          FilledButton.tonalIcon(
            icon: Icon(icon),
            label: Text(buttonLabel),
            onPressed: () async {
              final text = await capture();
              if (text == null || !context.mounted) return;
              _answer(context, node, UncastValue(text));
            },
          ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    final mediaType = switch (node.controlType) {
      ControlType.imageChoose => 'image/*',
      ControlType.audioCapture => 'audio/*',
      ControlType.videoCapture => 'video/*',
      ControlType.osmCapture => 'osm/*',
      _ => '*/*',
    };
    return _Captured(
      node: node,
      available: delegates.canCaptureMedia,
      capture: () => delegates.captureMedia(
        context,
        mediaType: mediaType,
        appearance: node.appearance,
      ),
      buttonLabel: 'Capture',
      icon: Icons.attach_file,
    );
  }
}

class _Geo extends StatelessWidget {
  const _Geo(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    return _Captured(
      node: node,
      available: delegates.canLocate && node.dataType == DataType.geopoint,
      capture: () => delegates.currentLocation(context),
      buttonLabel: 'Get location',
      icon: Icons.my_location,
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    return _Captured(
      node: node,
      available: delegates.canScanBarcode,
      capture: () => delegates.scanBarcode(context),
      buttonLabel: 'Scan',
      icon: Icons.qr_code_scanner,
    );
  }
}
