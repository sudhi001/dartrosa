// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ToDateTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ToDateTest.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/src/xpath/conversions.dart';
import 'package:test/test.dart';

const _dayMs = 86400000;

void main() {
  test('ISO 8601 dates without preserving time', () {
    expect(toDate('2018-01-01', preserveTime: false), DateTime(2018));
  });

  test('ISO 8601 dates without offset, preserving time', () {
    expect(
      toDate('2018-01-01T10:20:30.400', preserveTime: true),
      DateTime(2018, 1, 1, 10, 20, 30, 400),
    );
  });

  test('ISO 8601 dates with offset, preserving time', () {
    expect(
      toDate('2018-01-01T10:20:30.400+02', preserveTime: true),
      DateTime.utc(2018, 1, 1, 8, 20, 30, 400).toLocal(),
    );
  });

  test('timestamps without preserving time give local midnight', () {
    // JavaRosa: the same local date as 1971-01-01 in the default zone.
    expect(toDate(365.0, preserveTime: false), DateTime(1971));
  });

  test('timestamps preserving time are UTC-midnight based', () {
    expect(
      (toDate(365.0, preserveTime: true) as DateTime).millisecondsSinceEpoch,
      365 * _dayMs,
    );
  });

  test('dates go unchanged', () {
    final date = DateTime(2018);
    expect(toDate(date, preserveTime: false), date);
    expect(toDate(date, preserveTime: true), date);
  });

  test('empty strings and NaN go unchanged', () {
    expect(toDate('', preserveTime: false), '');
    expect(toDate('', preserveTime: true), '');
    expect((toDate(double.nan, preserveTime: false) as double).isNaN, isTrue);
    expect((toDate(double.nan, preserveTime: true) as double).isNaN, isTrue);
  });

  final mismatch = throwsA(isA<XPathTypeMismatchException>());

  test('out-of-range numbers throw', () {
    expect(() => toDate(-2147483648.0 - 1, preserveTime: false), mismatch);
    expect(() => toDate(2147483647.0 + 1, preserveTime: false), mismatch);
    expect(() => toDate(double.infinity, preserveTime: false), mismatch);
    expect(
      () => toDate(double.negativeInfinity, preserveTime: false),
      mismatch,
    );
  });

  test('unparseable strings, booleans and other types throw', () {
    expect(() => toDate('some random text', preserveTime: false), mismatch);
    expect(() => toDate(false, preserveTime: false), mismatch);
    // JavaRosa uses a Long here; on the web a Dart int is a number, so use
    // an arbitrary object.
    expect(() => toDate(Object(), preserveTime: false), mismatch);
  });
}
