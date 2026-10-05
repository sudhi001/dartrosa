// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa test: the comparison cache (JavaRosa's grows without bound)
// keeps the most recently used results only.
library;

import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/model/condition/filter_strategies.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

void main() {
  final towns = FormInstance(TreeElement('root'), 'towns');
  final nodeset = const TreeReference.root()
      .extend('root', 0)
      .extend('item', TreeReference.indexUnbound)
      .withInstanceName('towns');
  final context = EvaluationContext(null);
  final strategy = ComparisonExpressionCacheFilterStrategy();

  /// Filters with `name = 'v[value]'`; returns how many times the result
  /// was computed (0 = cached).
  int filter(int value) {
    var computed = 0;
    strategy.filter(
      towns,
      nodeset,
      parseXPath("name = 'v$value'"),
      const [],
      context,
      () {
        computed++;
        return const [];
      },
    );
    return computed;
  }

  test('results are cached', () {
    expect(filter(1), 1);
    expect(filter(1), 0);
  });

  test('at most maxEntries results are kept, least recently used dropped', () {
    const max = ComparisonExpressionCacheFilterStrategy.maxEntries;
    for (var i = 0; i < max + 500; i++) {
      filter(i);
      if (i % 100 == 0) filter(1); // keeps v1 recently used
    }
    expect(strategy.length, max);
    expect(filter(1), 0, reason: 'recently used');
    expect(filter(max + 499), 0, reason: 'recent');
    expect(filter(2), 1, reason: 'dropped');
  });
}
