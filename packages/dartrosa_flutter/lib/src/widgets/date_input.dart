import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../localizations.dart';
import 'calendar_date_picker_dialog.dart';
import 'common.dart';

/// Dates and times: pickers. Dates support `no-calendar` (typed date),
/// `month-year` and `year` (saved as the first day of the month or
/// year), and ODK Collect's calendar appearances (`ethiopian`, `coptic`,
/// `islamic`, `bikram-sambat`, `myanmar`, `persian`, `buddhist`): the
/// answer is shown in that calendar, as Collect labels it, and picked
/// with that calendar's spinners ([CustomCalendarDatePickerDialog]); the
/// Gregorian date is stored.
class DateTimeInput extends StatelessWidget {
  /// Creates the input for [node].
  const DateTimeInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  /// The first year offered.
  static const firstYear = 1900;

  /// The last year offered.
  static const lastYear = 2100;

  DateTime? get _value => switch (node.value) {
    DateValue(:final date) => date,
    DateTimeValue(:final dateTime) => dateTime,
    TimeValue(:final time) => time,
    _ => null,
  };

  /// The calendar picker of a date question, if it has a calendar
  /// appearance.
  DatePickerDetails? get _calendar {
    if (node.dataType != DataType.date) return null;
    final details = DatePickerDetails.fromAppearance(node.appearance);
    return details.isCustomCalendar ? details : null;
  }

  Future<void> _pick(BuildContext context, Appearance appearance) async {
    final current = _value ?? DateTime.now();
    DateTime? picked = current;
    final calendar = _calendar;
    if (calendar != null) {
      picked = await showDialog<DateTime>(
        context: context,
        builder: (context) => CustomCalendarDatePickerDialog(
          details: calendar,
          initialDate: current,
        ),
      );
      if (picked == null || !context.mounted) return;
      answerQuestion(context, node, DateValue(picked));
      return;
    }
    if (node.dataType == DataType.date &&
        (appearance.has('month-year') || appearance.has('year'))) {
      picked = await showDialog<DateTime>(
        context: context,
        builder: (context) => _MonthYearDialog(
          initial: current,
          withMonth: appearance.has('month-year'),
        ),
      );
      if (picked == null || !context.mounted) return;
      answerQuestion(context, node, DateValue(picked));
      return;
    }
    if (node.dataType != DataType.time) {
      picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(firstYear),
        lastDate: DateTime(lastYear, 12, 31),
        initialEntryMode: appearance.has('no-calendar')
            ? DatePickerEntryMode.inputOnly
            : DatePickerEntryMode.calendar,
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
    answerQuestion(context, node, switch (node.dataType) {
      DataType.date => DateValue(picked),
      DataType.time => TimeValue(picked),
      _ => DateTimeValue(picked),
    });
  }

  String _display(BuildContext context, Appearance appearance) {
    final value = _value;
    if (value == null) return '—';
    final calendar = _calendar;
    if (calendar != null) return dateTimeLabel(value, calendar);
    if (node.dataType == DataType.date) {
      if (appearance.has('year')) return '${value.year}';
      if (appearance.has('month-year')) {
        return MaterialLocalizations.of(context).formatMonthYear(value);
      }
    }
    return node.displayValue ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final appearance = Appearance.parse(node.appearance);
    final strings = XFormLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: Text(_display(context, appearance))),
        if (!node.isReadonly) ...[
          if (node.value != null)
            IconButton(
              tooltip: strings.clear,
              icon: const Icon(Icons.clear),
              onPressed: () => answerQuestion(context, node, null),
            ),
          FilledButton.tonal(
            onPressed: () => _pick(context, appearance),
            child: Text(switch (node.dataType) {
              DataType.date => strings.selectDate,
              DataType.time => strings.selectTime,
              _ => strings.selectDateTime,
            }),
          ),
        ],
      ],
    );
  }
}

/// Picks a year, or a month and year.
class _MonthYearDialog extends StatefulWidget {
  const _MonthYearDialog({required this.initial, required this.withMonth});

  final DateTime initial;
  final bool withMonth;

  @override
  State<_MonthYearDialog> createState() => _MonthYearDialogState();
}

class _MonthYearDialogState extends State<_MonthYearDialog> {
  late int _year = widget.initial.year.clamp(
    DateTimeInput.firstYear,
    DateTimeInput.lastYear,
  );
  late int _month = widget.withMonth ? widget.initial.month : 1;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      content: Row(
        children: [
          if (widget.withMonth) ...[
            Expanded(
              child: DropdownButton<int>(
                key: const ValueKey('month'),
                isExpanded: true,
                value: _month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(XFormLocalizations.of(context).monthName(m)),
                    ),
                ],
                onChanged: (m) => setState(() => _month = m!),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: DropdownButton<int>(
              key: const ValueKey('year'),
              isExpanded: true,
              value: _year,
              items: [
                for (
                  var y = DateTimeInput.firstYear;
                  y <= DateTimeInput.lastYear;
                  y++
                )
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (y) => setState(() => _year = y!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
