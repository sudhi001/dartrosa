// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (RelativeRefTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 RelativeRefTest.
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

void main() {
  test('predicateInRelativeRef_isAppliedToCorrectLevel', () {
    final predicate = parseXPath('position() = ../count');
    final parentRefWithPredicate =
        parseXPath('../repeat[position() = ../count]/choice') as XPathPathExpr;
    expect(
      parentRefWithPredicate.toTreeReference().predicatesAt(0)![0],
      predicate,
    );

    final grandParentRefWithPredicate =
        parseXPath('../../repeat[position() = ../count]/choice')
            as XPathPathExpr;
    expect(
      grandParentRefWithPredicate.toTreeReference().predicatesAt(0)![0],
      predicate,
    );
  });
}
