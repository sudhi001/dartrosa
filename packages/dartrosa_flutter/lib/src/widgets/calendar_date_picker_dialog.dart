// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (CustomDatePickerDialog), Copyright 2017 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';

/// One spinner of the dialog, a drop-down of [picker]'s values.
///
/// It fills the width it is given when [expand] is set (the month, whose
/// names vary in length); otherwise it is as wide as its widest value
/// (day and year numbers).
class _Spinner extends StatelessWidget {
  const _Spinner({
    required this.name,
    required this.picker,
    required this.onChanged,
    this.expand = false,
  });

  final String name;
  final NumberPickerState picker;
  final ValueChanged<int> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final labels = picker.displayedValues;
    final min = picker.minValue;
    final max = picker.maxValue < min ? min : picker.maxValue;
    return DropdownButton<int>(
      key: ValueKey('calendar-$name'),
      isExpanded: expand,
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

  /// The day, month and year spinners in one row, or with the month on a
  /// line of its own when the row would leave it too little room (narrow
  /// windows, large text).
  Widget _spinners(BuildContext context) {
    // The dialog's content width (AlertDialog: 40dp insets, 24dp padding,
    // at most 560dp); the dialog sizes itself to its content, so this is
    // derived from the window.
    final width = math.min(560, MediaQuery.sizeOf(context).width - 80) - 48;
    final day = _model.showsDay
        ? _Spinner(
            name: 'day',
            picker: _model.dayPicker,
            onChanged: (v) => setState(() => _model.setDay(v)),
          )
        : null;
    final month = _model.showsMonth
        ? _Spinner(
            name: 'month',
            picker: _model.monthPicker,
            onChanged: (v) => setState(() => _model.setMonth(v)),
            expand: true,
          )
        : null;
    final year = _Spinner(
      name: 'year',
      picker: _model.yearPicker,
      onChanged: (v) => setState(() => _model.setYear(v)),
    );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (month != null && width / scale < 240) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          month,
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [?day, year],
          ),
        ],
      );
    }
    return Row(
      children: [
        if (day != null) ...[day, const SizedBox(width: 8)],
        if (month != null) ...[
          Expanded(child: month),
          const SizedBox(width: 8),
        ],
        year,
        // In year mode the year is alone; keep it at the start.
        if (month == null) const Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      // Large text on a small screen: the content scrolls.
      scrollable: true,
      title: Text(XFormLocalizations.of(context).selectDate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _spinners(context),
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
