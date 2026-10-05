// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ChildProcessingTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ChildProcessingTest.
import 'package:dartrosa/src/xform/instance_structure.dart';
import 'package:dartrosa/src/xform/kdom.dart';
import 'package:test/test.dart';

void main() {
  test('works with one child', () {
    final el = KElement('', '')..children.add(KElement('Child Name', ''));
    expect(childOptimizationsOk(el), isTrue);
  });

  test('works with two matching children', () {
    final el = KElement('', '')
      ..children.add(KElement('Child Name', ''))
      ..children.add(KElement('Child Name', ''));
    expect(childOptimizationsOk(el), isTrue);
  });

  test('works with two not matching children', () {
    final el = KElement('', '')
      ..children.add(KElement('Child Name 1', ''))
      ..children.add(KElement('Child Name 2', ''));
    expect(childOptimizationsOk(el), isFalse);
  });

  test('recognizes that one child is a template', () {
    final template = KElement('Child Name', '')
      ..attributes.add((
        namespace: namespaceJavaRosa,
        name: 'template',
        value: '',
      ));
    final el = KElement('', '')
      ..children.add(template)
      ..children.add(KElement('Child Name', ''));
    expect(childOptimizationsOk(el), isFalse);
  });

  test('works with no children', () {
    expect(childOptimizationsOk(KElement('', '')), isFalse);
  });

  test('discovers non-element child', () {
    final el = KElement('', '')
      ..children.add(KText(KNodeType.comment, 'A string'));
    expect(childOptimizationsOk(el), isFalse);
  });
}
