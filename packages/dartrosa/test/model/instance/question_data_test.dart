// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (QuestionDataElementTests), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 QuestionDataElementTests and
// QuestionDataGroupTests (TreeElement as a question and as a group). The
// visitor tests check selfAndDescendants, which replaces accept(visitor).
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:test/test.dart';

void main() {
  const stringElementName = 'String Data Element';
  const stringData = StringValue('Answer Value');
  const integerData = IntegerValue(4);
  late TreeElement stringElement;
  late TreeElement intElement;

  setUp(() {
    intElement = TreeElement('intElement')..value = integerData;
    stringElement = TreeElement(stringElementName)..value = stringData;
  });

  group('QuestionDataElementTests', () {
    test('is leaf', () => expect(stringElement.isLeaf, isTrue));

    test('get name', () => expect(stringElement.name, stringElementName));

    test('set name', () {
      stringElement.name = 'New Name';
      expect(stringElement.name, 'New Name');
    });

    test('get value', () => expect(stringElement.value, stringData));

    test('set value', () {
      stringElement.value = integerData;
      expect(stringElement.value, integerData);
      stringElement.value = null;
      expect(stringElement.value, isNull);
    });

    test('accepts visitor', () {
      expect(stringElement.selfAndDescendants, [stringElement]);
    });
  });

  group('QuestionDataGroupTests', () {
    late TreeElement group;
    setUp(() => group = TreeElement('TestGroup'));

    test('is leaf', () {
      expect(group.isLeaf, isTrue);
      group.addChild(stringElement);
      expect(group.isLeaf, isFalse);
    });

    test('get name', () {
      expect(group.name, 'TestGroup');
      group.addChild(stringElement);
      expect(group.name, 'TestGroup');
    });

    test('set name', () {
      group.name = 'TestGroupNew';
      expect(group.name, 'TestGroupNew');
    });

    test('accepts visitor', () {
      group.addChild(stringElement);
      expect(group.selfAndDescendants, [group, stringElement]);
    });

    test('add leaf child', () {
      group.addChild(stringElement);
      expect(group.childAt(0), stringElement);
      final leafGroup = TreeElement('leaf group');
      group.addChild(leafGroup);
      expect(group.childAt(1), leafGroup);
    });

    test('add tree child', () {
      final subElement = TreeElement('SubElement')
        ..addChild(stringElement)
        ..addChild(intElement);
      expect(subElement.numChildren, 2);
    });
  });
}
