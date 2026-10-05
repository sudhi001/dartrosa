import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';

/// One spinner of the dialog, a drop-down of [picker]'s values.
class _Spinner extends StatelessWidget {
  const _Spinner({
    required this.name,
    required this.picker,
    required this.onChanged,
  });

  final String name;
  final NumberPickerState picker;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = picker.displayedValues;
    final min = picker.minValue;
    final max = picker.maxValue < min ? min : picker.maxValue;
    return DropdownButton<int>(
      key: ValueKey('calendar-$name'),
      isExpanded: true,
      value: picker.value.clamp(min, max),
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
      onChanged: (v) => onChanged(v!),
    );
  }
}

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
                Expanded(
                  child: _Spinner(
                    name: 'day',
                    picker: _model.dayPicker,
                    onChanged: (v) => setState(() => _model.setDay(v)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_model.showsMonth) ...[
                Expanded(
                  flex: 2,
                  child: _Spinner(
                    name: 'month',
                    picker: _model.monthPicker,
                    onChanged: (v) => setState(() => _model.setMonth(v)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _Spinner(
                  name: 'year',
                  picker: _model.yearPicker,
                  onChanged: (v) => setState(() => _model.setYear(v)),
                ),
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
