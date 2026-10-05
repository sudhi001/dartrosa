// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (CompareToNodeExpressionTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 CompareToNodeExpressionTest.
import 'dart:math';

import 'package:dartrosa/src/model/condition/filter_strategies.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/src/xpath/qname.dart';
import 'package:test/test.dart';

XPathPathExpr path(PathStart start, String name) => XPathPathExpr(start, [
  XPathStep.named(XPathAxis.child, XPathQName(null, name)),
]);

void main() {
  test('parse_doesNotParseExpressionsWhereBothSidesAreRelative', () {
    final expression = XPathEqExpr(
      true,
      path(PathStart.relative, 'name'),
      path(PathStart.relative, 'name'),
    );

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNull);
  });

  test('parse_parsesStringLiteralAsContextSide', () {
    final expression = XPathEqExpr(
      true,
      path(PathStart.relative, 'name'),
      const XPathStringLiteral('string'),
    );

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNotNull);
    expect(parsed!.nodeSide, equals(expression.a));
    expect(parsed.contextSide, equals(expression.b));
  });

  test('parse_parsesNumericLiteralAsContextSide', () {
    final expression = XPathEqExpr(
      true,
      path(PathStart.relative, 'name'),
      const XPathNumericLiteral(45),
    );

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNotNull);
    expect(parsed!.nodeSide, equals(expression.a));
    expect(parsed.contextSide, equals(expression.b));
  });

  test('parse_parsesIdempotentFunctionWithAbsoluteAndRelativeArgs', () {
    final functions = idempotentFunctions.toList();
    final expression = XPathFuncExpr(
      XPathQName(null, functions[Random().nextInt(functions.length)]),
      [path(PathStart.relative, 'name'), path(PathStart.root, 'something')],
    );

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNotNull);
    expect(parsed!.nodeSide, equals(expression.args[0]));
    expect(parsed.contextSide, equals(expression.args[1]));
  });

  test('parse_doesNotParseNonIdempotentFunction', () {
    final expression = XPathFuncExpr(XPathQName(null, 'blah'), [
      path(PathStart.relative, 'name'),
      path(PathStart.root, 'something'),
    ]);

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNull);
  });

  test('parse_parsesContextExpressionsAsContextSide', () {
    final expression = XPathEqExpr(
      true,
      path(PathStart.relative, 'name'),
      XPathPathExpr.fromFilter(
        XPathFilterExpr(
          XPathFuncExpr(XPathQName(null, 'blah'), const []),
          const [],
        ),
        const [],
      ),
    );

    final parsed = CompareToNodeExpression.parse(expression);
    expect(parsed, isNotNull);
    expect(parsed!.nodeSide, equals(expression.a));
    expect(parsed.contextSide, equals(expression.b));
  });

  test('parse_parsesRelativeAndAbsoluteRegardlessOfSide', () {
    final relative = path(PathStart.relative, 'name');
    final absolute = path(PathStart.root, 'something');

    final ltr = XPathEqExpr(true, relative, absolute);
    final rtl = XPathEqExpr(true, absolute, relative);
    final ltrParsed = CompareToNodeExpression.parse(ltr);
    final rtlParsed = CompareToNodeExpression.parse(rtl);

    expect(ltrParsed, isNotNull);
    expect(ltrParsed!.nodeSide, equals(relative));
    expect(ltrParsed.contextSide, equals(absolute));

    expect(rtlParsed, isNotNull);
    expect(rtlParsed!.nodeSide, equals(relative));
    expect(rtlParsed.contextSide, equals(absolute));
  });
}
