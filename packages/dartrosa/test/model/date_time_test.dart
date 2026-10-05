// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DateTimeTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DateTimeTest.
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

/// A form with a [type] question calculated from the literal [value], one
/// with [value] as its default, and one calculated from that default.
Future<Scenario> _form(
  String formTitle,
  String id,
  String type,
  String value,
) => Scenario.init(
  html(
    head([
      title(formTitle),
      model([
        mainInstance([
          t('data id="$id"', [
            t('calculateLiteral'),
            tText('empty', value),
            t('calculateReference'),
          ]),
        ]),
        bind('/data/calculateLiteral')
          ..type(type)
          ..calculate('&quot;$value&quot;'),
        bind('/data/empty')..type(type),
        bind('/data/calculateReference')
          ..type(type)
          ..calculate('/data/empty'),
      ]),
    ]),
    body([
      input('/data/calculateLiteral'),
      input('/data/empty'),
      input('/data/calculateReference'),
    ]),
  ),
);

void main() {
  test('timeQuestionReturnsTimeDataAnswer', () async {
    final scenario = await _form(
      'Time form',
      'time-form',
      'time',
      '23:14:00.000+02:00',
    );
    expect(scenario.answerOf('/data/calculateLiteral'), isA<TimeValue>());
    expect(scenario.answerOf('/data/empty'), isA<TimeValue>());
    expect(scenario.answerOf('/data/calculateReference'), isA<TimeValue>());
  });

  test('dateQuestionReturnsDateDataAnswer', () async {
    final scenario = await _form(
      'Date form',
      'date-form',
      'date',
      '2025-09-25',
    );
    expect(scenario.answerOf('/data/calculateLiteral'), isA<DateValue>());
    expect(scenario.answerOf('/data/empty'), isA<DateValue>());
    expect(scenario.answerOf('/data/calculateReference'), isA<DateValue>());
  });

  test('dateTimeQuestionReturnsDateTimeDataAnswer', () async {
    final scenario = await _form(
      'DateTime form',
      'datetime-form',
      'dateTime',
      '2025-09-25T23:15:00.000+02:00',
    );
    expect(scenario.answerOf('/data/calculateLiteral'), isA<DateTimeValue>());
    expect(scenario.answerOf('/data/empty'), isA<DateTimeValue>());
    expect(scenario.answerOf('/data/calculateReference'), isA<DateTimeValue>());
  });

  test('timeQuestionWithInvalidTimeFormatResultsInNoAnswer', () async {
    final scenario = await _form('Time form', 'time-form', 'time', 'notatime');

    expect(scenario.answerOf('/data/calculateLiteral'), isNull);
    expect(scenario.answerOf('/data/empty'), isNull);
    expect(scenario.answerOf('/data/calculateReference'), isNull);
  });

  test('dateQuestionWithInvalidDateFormatResultsInNoAnswer', () async {
    final scenario = await _form(
      'Date form',
      'date-form',
      'date',
      'not-a-date',
    );

    expect(scenario.answerOf('/data/calculateLiteral'), isNull);
    expect(scenario.answerOf('/data/empty'), isNull);
    expect(scenario.answerOf('/data/calculateReference'), isNull);
  });

  test('dateTimeQuestionWithInvalidDateTimeFormatResultsInNoAnswer', () async {
    final scenario = await _form(
      'DateTime form',
      'datetime-form',
      'dateTime',
      'not-a-datetime',
    );

    expect(scenario.answerOf('/data/calculateLiteral'), isNull);
    expect(scenario.answerOf('/data/empty'), isNull);
    expect(scenario.answerOf('/data/calculateReference'), isNull);
  });
}
