import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';

/// The spinner dialog ODK Collect shows for a date question with a
/// non-Gregorian calendar appearance (`ethiopian`, `coptic`, `islamic`,
/// `bikram-sambat`, `myanmar`, `persian`, `buddhist`): day, month and year
/// spinners of that calendar (the day hidden for `month-year`, the day and
/// month for `year`) over Collect's label of the chosen date. Pops the
/// Gregorian date (local midnight) to store, or null when cancelled.
///
/// Port of Collect's `CustomDatePickerDialog`; the spinner logic is
/// [CustomDatePickerModel].
class CustomCalendarDatePickerDialog extends StatefulWidget {
  /// Creates the dialog for [details], opened on [initialDate].
  const CustomCalendarDatePickerDialog({
    required this.details,
    required this.initialDate,
    super.key,
  });

  /// The calendar and the spinners shown.
  final DatePickerDetails details;

  /// The Gregorian date the spinners start on.
  final DateTime initialDate;

  @override
  State<CustomCalendarDatePickerDialog> createState() =>
      _CustomCalendarDatePickerDialogState();
}

class _CustomCalendarDatePickerDialogState
    extends State<CustomCalendarDatePickerDialog> {
  late final CustomDatePickerModel _model = CustomDatePickerModel(
    widget.details,
    _supported(widget.initialDate),
  );

  /// Bikram Sambat only covers 1913-04-13..2034-04-13; Collect leaves its
  /// spinners empty outside that range, this dialog starts at the nearest
  /// supported date instead.
  DateTime _supported(DateTime date) {
    final calendar = CustomCalendar.of(widget.details.type);
    if (calendar.fromGregorian(date) != null) return date;
    return date.year < 1970 ? DateTime(1913, 4, 13) : DateTime(2034, 4, 13);
  }

  Widget _spinner({
    required String name,
    required NumberPickerState picker,
    required ValueChanged<int> onChanged,
    int flex = 1,
  }) {
    final labels = picker.displayedValues;
    final min = picker.minValue;
    final max = picker.maxValue < min ? min : picker.maxValue;
    final value = picker.value.clamp(min, max);
    return Expanded(
      flex: flex,
      child: DropdownButton<int>(
        key: ValueKey('calendar-$name'),
        isExpanded: true,
        value: value,
        items: [
          for (var v = min; v <= max; v++)
            DropdownMenuItem(
              value: v,
              child: Text(
                labels != null && v < labels.length ? labels[v] : '$v',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => onChanged(v!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(XFormLocalizations.of(context).selectDate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_model.showsDay) ...[
                _spinner(
                  name: 'day',
                  picker: _model.dayPicker,
                  onChanged: _model.setDay,
                ),
                const SizedBox(width: 8),
              ],
              if (_model.showsMonth) ...[
                _spinner(
                  name: 'month',
                  picker: _model.monthPicker,
                  onChanged: _model.setMonth,
                  flex: 2,
                ),
                const SizedBox(width: 8),
              ],
              _spinner(
                name: 'year',
                picker: _model.yearPicker,
                onChanged: _model.setYear,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _model.label(),
            key: const ValueKey('calendar-label'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _model.gregorianDate),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
