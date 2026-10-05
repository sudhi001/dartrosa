// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (AnswerDataUtilTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 AnswerDataUtilTest. JavaRosa's value-less data
// objects (`new IntegerData()`) are `null` answers in DartRosa.
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:test/test.dart';

void main() {
  test('integer data', () {
    expect(answerDataToInt(const IntegerValue(1)), 1);
    expect(answerDataToInt(const IntegerValue(5)), 5);
    expect(answerDataToInt(const IntegerValue(20)), 20);
  });

  test('no value is zero', () => expect(answerDataToInt(null), 0));

  test('decimal data is floored', () {
    expect(answerDataToInt(const DecimalValue(2)), 2);
    expect(answerDataToInt(const DecimalValue(7.5)), 7);
    expect(answerDataToInt(const DecimalValue(41)), 41);
    expect(answerDataToInt(const DecimalValue(-7.5)), -8);
  });

  test('long data', () {
    expect(answerDataToInt(const LongValue(4)), 4);
    expect(answerDataToInt(const LongValue(15)), 15);
    expect(answerDataToInt(const LongValue(120)), 120);
    // Java's (int) cast keeps the low 32 bits.
    expect(answerDataToInt(const LongValue(4294967297)), 1);
  });

  test('string data', () {
    expect(answerDataToInt(const StringValue('6')), 6);
    expect(answerDataToInt(const StringValue('9.0')), 9);
    expect(answerDataToInt(const StringValue('17')), 17);
    expect(answerDataToInt(const StringValue('21.5')), 21);
    expect(answerDataToInt(const StringValue('53')), 53);
  });

  test('string that is not a number is zero', () {
    expect(answerDataToInt(const StringValue('blah')), 0);
  });

  test('unsupported data types are zero', () {
    expect(answerDataToInt(const BooleanValue(true)), 0);
    expect(answerDataToInt(const SelectOneValue(Selection('Selection1'))), 0);
    expect(answerDataToInt(DateValue(DateTime.now())), 0);
  });

  group('NumericEncodingTest', () {
    for (final name in ['int encoding uniform', 'int encoding small']) {
      test(
        name,
        () {},
        skip:
            'Externalizable binary format is not ported '
            '(FormDefCodec replaces it)',
      );
    }
  });
}
