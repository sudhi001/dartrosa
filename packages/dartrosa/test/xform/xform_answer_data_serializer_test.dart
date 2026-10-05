// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XFormAnswerDataSerializerTest), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 XFormAnswerDataSerializerTest.
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/xform/xform_answer_data_serializer.dart';
import 'package:test/test.dart';

void main() {
  const stringDataValue = 'String Data Value';
  const integerDataValue = 5;
  final dateDataValue = DateTime.now();
  final timeDataValue = DateTime.now();

  late StringValue stringData;
  late IntegerValue integerData;
  late DateValue dateData;
  late TimeValue timeData;

  late TreeElement stringElement;
  late TreeElement intElement;
  late TreeElement dateElement;
  late TreeElement timeElement;

  setUp(() {
    stringData = const StringValue(stringDataValue);
    stringElement = TreeElement()..value = stringData;

    integerData = const IntegerValue(integerDataValue);
    intElement = TreeElement()..value = integerData;

    dateData = DateValue(dateDataValue);
    dateElement = TreeElement()..value = dateData;

    timeData = TimeValue(timeDataValue);
    timeElement = TreeElement()..value = timeData;
  });

  test('testString', () {
    expect(
      canSerializeAnswerData(stringElement.value),
      isTrue,
      reason: 'Serializer Incorrectly Reports Inability to Serializer String',
    );
    final answerData = serializeAnswerData(stringData);
    expect(
      answerData,
      isNotNull,
      reason: 'Serializer returns Null for valid String Data',
    );
    expect(
      answerData,
      stringDataValue,
      reason: 'Serializer returns incorrect string serialization',
    );
  });

  test('testInteger', () {
    expect(
      canSerializeAnswerData(intElement.value),
      isTrue,
      reason: 'Serializer Incorrectly Reports Inability to Serializer Integer',
    );
    final answerData = serializeAnswerData(integerData);
    expect(
      answerData,
      isNotNull,
      reason: 'Serializer returns Null for valid Integer Data',
    );
  });

  test('testDate', () {
    expect(
      canSerializeAnswerData(dateElement.value),
      isTrue,
      reason: 'Serializer Incorrectly Reports Inability to Serializer Date',
    );
    final answerData = serializeAnswerData(dateData);
    expect(
      answerData,
      isNotNull,
      reason: 'Serializer returns Null for valid Date Data',
    );
  });

  test('testTime', () {
    expect(
      canSerializeAnswerData(timeElement.value),
      isTrue,
      reason: 'Serializer Incorrectly Reports Inability to Serializer Time',
    );
    final answerData = serializeAnswerData(timeData);
    expect(
      answerData,
      isNotNull,
      reason: 'Serializer returns Null for valid Time Data',
    );
  });

  test('testSelect', () {
    //No select tests yet.
  });
}
