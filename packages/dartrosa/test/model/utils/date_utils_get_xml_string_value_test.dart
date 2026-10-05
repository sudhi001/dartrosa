// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DateUtilsGetXmlStringValueTest), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DateUtilsGetXmlStringValueTest.
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  test('XML string is well formatted', () {
    final now = DateTime.now();
    final xml = getXmlStringValue(now);
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(xml), isTrue);
    final parsed = DateTime.parse(xml);
    expect(
      (parsed.year, parsed.month, parsed.day),
      (now.year, now.month, now.day),
    );
  });
}
