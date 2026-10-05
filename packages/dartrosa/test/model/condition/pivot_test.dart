// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Range hints from constraints. JavaRosa has no tests for these; every
// expectation below was captured from JavaRosa 6.0.0 (jshell, RangeHint on
// an XPathConditional) with age = 7 and other = 3.
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/model/condition/pivot.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

/// (hint kind, constraint, expected) where expected is `min max` with
/// `(`/`[` and `)`/`]` for exclusive/inclusive, or `unpivotable`.
const cases = [
  ('int', '. > 5', 'min=5( max=null'),
  ('int', '. >= 1 and . < 10', 'min=1[ max=10)'),
  ('int', '. <= 100', 'min=null max=100]'),
  ('int', '5 < .', 'min=5( max=null'),
  ('int', '. > /data/other', 'min=3( max=null'),
  ('int', '. > 5 or . < 2', 'min=5( max=2)'),
  ('int', '. != 3', 'unpivotable'),
  ('int', "selected(., 'a')", 'unpivotable'),
  ('int', '. > 1 and . < 5 and . != 3', 'unpivotable'),
  ('int', '. < 10 and . > 1 and . > 2', 'unpivotable'),
  ('int', '/data/other > 2', 'min=null max=null'),
  ('int', 'true()', 'min=null max=null'),
  ('str', 'string-length(.) <= 10', 'min=null max=XXXXXXXXXX]'),
  (
    'str',
    'string-length(.) > 2 and string-length(.) < 8',
    'min=XX( max=XXXXXXXX)',
  ),
  // JavaRosa probes decimals with Double.MIN_VALUE, which rounding loses.
  ('dec', '. > 5', 'min=null max=null'),
  ('dec', '. >= 2.5', 'min=null max=null'),
  ('date', '. > 18262', 'min=2020-01-01( max=null'),
  // A date() value isn't a number, so it can't be a pivot.
  ('date', ". > date('2020-01-01')", 'unpivotable'),
];

String describe(RangeHint hint) {
  String side(AnswerValue? value, bool inclusive, String open, String closed) =>
      value == null
      ? 'null'
      : '${value.uncast().string}${inclusive ? closed : open}';
  return 'min=${side(hint.min, hint.minInclusive, '(', '[')} '
      'max=${side(hint.max, hint.maxInclusive, ')', ']')}';
}

void main() {
  late FormInstance instance;
  late TreeElement age;

  setUp(() {
    age = TreeElement('age')..value = const IntegerValue(7);
    final data = TreeElement('data')
      ..addChild(age)
      ..addChild(TreeElement('other')..value = const IntegerValue(3));
    instance = FormInstance(data);
  });

  for (final (kind, constraint, expected) in cases) {
    test('$kind: $constraint', () {
      // The annotation is needed: the arms' least upper bound is not
      // RangeHint (the lint misses this).
      // ignore: omit_local_variable_types
      final RangeHint hint = switch (kind) {
        'int' => IntegerRangeHint(),
        'dec' => DecimalRangeHint(),
        'date' => DateRangeHint(),
        _ => StringLengthRangeHint(),
      };
      final context = EvaluationContext.withContext(
        EvaluationContext(instance),
        age.ref,
      );
      void run() => hint.init(context, parseXPath(constraint), instance);
      if (expected == 'unpivotable') {
        expect(run, throwsA(isA<UnpivotableExpressionException>()));
      } else {
        run();
        expect(describe(hint), expected);
      }
    });
  }
}
