// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../appearance.dart';
import '../theme.dart';
import 'common.dart';
import 'question_focus.dart';

/// Text, integer, decimal and long inputs (`multiline`, `numbers`,
/// `masked`, `thousands-sep`).
class TextQuestionInput extends StatefulWidget {
  /// Creates the input for [node].
  const TextQuestionInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  State<TextQuestionInput> createState() => _TextQuestionInputState();
}

class _TextQuestionInputState extends State<TextQuestionInput> {
  /// The field's text, created when the field is first shown (read-only
  /// questions show no field).
  TextEditingController? _controller;

  TextEditingController get _text =>
      _controller ??= TextEditingController(text: _display());

  Appearance get _appearance => Appearance.parse(widget.node.appearance);

  bool get _grouped =>
      _isNumeric(widget.node) && _appearance.has('thousands-sep');

  String get _separator => thousandsSeparatorOf(context);

  String _display() {
    final text = widget.node.value?.displayText ?? '';
    return _grouped ? groupThousands(text, _separator) : text;
  }

  @override
  void didUpdateWidget(covariant TextQuestionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculated (or read-only) values replace the text.
    final controller = _controller;
    if (controller == null || !widget.node.isReadonly) return;
    final value = _display();
    if (controller.text != value) controller.text = value;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  AnswerValue? _parse(String input) {
    final text = _grouped ? input.replaceAll(_separator, '') : input;
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

  void _submitted() {
    final advance = XFormPagerScope.advanceOf(context);
    if (advance != null) {
      advance();
    } else {
      FocusScope.of(context).nextFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final appearance = _appearance;
    final integral =
        node.dataType == DataType.integer || node.dataType == DataType.long;
    final numeric = _isNumeric(node) || appearance.has('numbers');
    final masked =
        node.controlType == ControlType.secret || appearance.has('masked');
    // Read-only: the answer as text, as ODK Collect shows it (no field).
    if (node.isReadonly) {
      return ReadOnlyAnswer(_display(), masked: masked);
    }
    final multiline = appearance.has('multiline') && !masked;
    final error = QuestionErrorScope.hasErrorOf(context)
        ? XFormTheme.of(context).errorColorOf(context)
        : null;
    return TextField(
      controller: _text,
      enabled: !node.isReadonly,
      obscureText: masked,
      enableSuggestions: !masked,
      autocorrect: !masked,
      maxLines: multiline ? null : 1,
      minLines: multiline ? 3 : null,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(
              decimal: node.dataType == DataType.decimal,
              signed: true,
            )
          : appearance.has('multiline')
          ? TextInputType.multiline
          : TextInputType.text,
      inputFormatters: [
        if (_grouped)
          ThousandsSeparatorFormatter(decimal: !integral, separator: _separator)
        else if (integral)
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      // The error shows under the question; the outline turns red too.
      decoration: error == null
          ? const InputDecoration(border: OutlineInputBorder())
          : InputDecoration(
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: error),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: error, width: 2),
              ),
            ),
      // Enter moves on: to the next screen when the question is alone on
      // a pager screen, else to the next field.
      textInputAction: multiline ? null : TextInputAction.next,
      onEditingComplete: multiline ? null : () {},
      onSubmitted: multiline ? null : (_) => _submitted(),
      onChanged: (text) => answerQuestion(context, node, _parse(text)),
    );
  }
}

/// The answer of a read-only text or number question, as ODK Collect
/// shows it: text in the color of the surface's content, without a field
/// (`—` when there is none). Screen readers read it as read-only; on
/// desktops and in browsers it can be selected with the mouse, like the
/// form's other text.
class ReadOnlyAnswer extends StatelessWidget {
  /// Creates the display of [text], obscured if [masked].
  const ReadOnlyAnswer(this.text, {this.masked = false, super.key});

  /// The answer as displayed.
  final String text;

  /// Whether the answer is a secret (`masked`, `<secret>`): shown as dots.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = text.isEmpty
        ? '—'
        : masked
        ? '•' * text.length
        : text;
    return Semantics(
      readOnly: true,
      obscured: masked && text.isNotEmpty,
      child: Text(
        shown,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// The answer of [node] as displayed by read-only number widgets: grouped
/// for `thousands-sep`.
String? numberDisplay(BuildContext context, QuestionNode node) {
  final text = node.value?.displayText;
  if (text == null) return null;
  return _isNumeric(node) &&
          Appearance.parse(node.appearance).has('thousands-sep')
      ? groupThousands(text, thousandsSeparatorOf(context))
      : text;
}

bool _isNumeric(QuestionNode node) => switch (node.dataType) {
  DataType.integer || DataType.long || DataType.decimal => true,
  _ => false,
};

/// The default grouping separator of `thousands-sep`.
const thousandsSeparator = ',';

/// The grouping separator of `thousands-sep` in [locale] (intl's number
/// symbols), as ODK Collect's `ThousandsSeparatorTextWatcher` picks it:
/// a space where it would be `.`, which is always the decimal marker.
String thousandsSeparatorFor(String? locale) {
  String separator;
  try {
    separator = NumberFormat.decimalPattern(locale).symbols.GROUP_SEP;
  } on ArgumentError {
    separator = thousandsSeparator;
  }
  return separator == '.' ? ' ' : separator;
}

/// The grouping separator of `thousands-sep` in [context]'s locale (see
/// [thousandsSeparatorFor]).
String thousandsSeparatorOf(BuildContext context) =>
    thousandsSeparatorFor(Localizations.maybeLocaleOf(context)?.toString());

/// [number] (digits, optional sign and `.` decimals) with its integer
/// digits grouped in threes by [separator].
String groupThousands(String number, [String separator = thousandsSeparator]) {
  final match = RegExp(r'^(-?)(\d+)(.*)$').firstMatch(number);
  if (match == null) return number;
  final digits = match[2]!;
  final buffer = StringBuffer(match[1]!);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
    buffer.write(digits[i]);
  }
  return '$buffer${match[3]}';
}

/// Keeps a number's digits grouped while typing (`thousands-sep`); only
/// the display changes, the answer is parsed without separators.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  /// Creates a formatter allowing decimals if [decimal], grouping with
  /// [separator].
  ThousandsSeparatorFormatter({
    required this.decimal,
    this.separator = thousandsSeparator,
  });

  /// Whether a `.` and decimals are allowed.
  final bool decimal;

  /// The grouping separator.
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(separator, '');
    final allowed = decimal ? RegExp(r'^-?\d*\.?\d*$') : RegExp(r'^-?\d*$');
    if (!allowed.hasMatch(raw)) return oldValue;
    final formatted = groupThousands(raw, separator);
    // Keep the cursor after the same number of non-separator characters.
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final before = newValue.text
        .substring(0, end)
        .replaceAll(separator, '')
        .length;
    var offset = 0;
    for (var seen = 0; offset < formatted.length && seen < before; offset++) {
      if (formatted[offset] != separator) seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
