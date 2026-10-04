import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../appearance.dart';
import 'common.dart';

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
  late final TextEditingController _text = TextEditingController(
    text: _display(),
  );

  Appearance get _appearance => Appearance.parse(widget.node.appearance);

  bool get _isNumber => switch (widget.node.dataType) {
    DataType.integer || DataType.long || DataType.decimal => true,
    _ => false,
  };

  bool get _grouped => _isNumber && _appearance.has('thousands-sep');

  String get _separator => thousandsSeparatorOf(context);

  String _display() {
    final text = widget.node.value?.displayText ?? '';
    return _grouped ? groupThousands(text, _separator) : text;
  }

  @override
  void didUpdateWidget(covariant TextQuestionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculated (or read-only) values replace the text.
    final value = _display();
    if (widget.node.isReadonly && _text.text != value) _text.text = value;
  }

  @override
  void dispose() {
    _text.dispose();
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

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final appearance = _appearance;
    final integral =
        node.dataType == DataType.integer || node.dataType == DataType.long;
    final numeric = _isNumber || appearance.has('numbers');
    final masked =
        node.controlType == ControlType.secret || appearance.has('masked');
    return TextField(
      controller: _text,
      enabled: !node.isReadonly,
      obscureText: masked,
      enableSuggestions: !masked,
      autocorrect: !masked,
      maxLines: appearance.has('multiline') && !masked ? null : 1,
      minLines: appearance.has('multiline') && !masked ? 3 : null,
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
      decoration: const InputDecoration(border: OutlineInputBorder()),
      onChanged: (text) => answerQuestion(context, node, _parse(text)),
    );
  }
}

/// The answer of [node] as displayed by read-only number widgets: grouped
/// for `thousands-sep`.
String? numberDisplay(BuildContext context, QuestionNode node) {
  final text = node.value?.displayText;
  if (text == null) return null;
  final number = switch (node.dataType) {
    DataType.integer || DataType.long || DataType.decimal => true,
    _ => false,
  };
  return number && Appearance.parse(node.appearance).has('thousands-sep')
      ? groupThousands(text, thousandsSeparatorOf(context))
      : text;
}

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
