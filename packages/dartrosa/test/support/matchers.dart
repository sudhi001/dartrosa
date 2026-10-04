/// Ports of JavaRosa's test matchers (`org.javarosa.core.test.*Matchers`).
library;

import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:test/test.dart';

/// A [StringValue] equal to [expected]. Port of `stringAnswer`.
Matcher stringAnswer(String expected) =>
    isA<StringValue>().having((v) => v.string, 'string answer', expected);

/// An [IntegerValue] equal to [expected]. Port of `intAnswer`.
Matcher intAnswer(int expected) =>
    isA<IntegerValue>().having((v) => v.n, 'int answer', expected);

/// A [BooleanValue] equal to [expected]. Port of `booleanAnswer`.
Matcher booleanAnswer(bool expected) =>
    isA<BooleanValue>().having((v) => v.b, 'boolean answer', expected);

/// An answer whose value equals [expected]'s. Port of `answer`.
Matcher answer(AnswerValue expected) => isA<AnswerValue>().having(
  (v) => v.value,
  'answer value',
  equals(expected.value),
);

/// An answer whose display text matches the regular expression [pattern].
/// Port of `answerText`.
Matcher answerText(String pattern) => isA<AnswerValue>().having(
  (v) => v.displayText,
  'answer text',
  matches(RegExp('^(?:$pattern)\$')),
);

/// A relevant node. Port of `QuestionDefMatchers.relevant`.
final Matcher relevant = isA<TreeElement>().having(
  (e) => e.isRelevant,
  'relevant',
  isTrue,
);

/// A non-relevant node. Port of `nonRelevant`.
final Matcher nonRelevant = isA<TreeElement>().having(
  (e) => e.isRelevant,
  'relevant',
  isFalse,
);

/// An enabled node. Port of `enabled`.
final Matcher enabled = isA<TreeElement>().having(
  (e) => e.isEnabled,
  'enabled',
  isTrue,
);

/// A read-only node. Port of `readOnly`.
final Matcher readOnly = isA<TreeElement>().having(
  (e) => e.isEnabled,
  'enabled',
  isFalse,
);

/// A choice with [value] (and, if given, label text or itext id
/// [labelOrId]). Port of `SelectChoiceMatchers.choice`.
Matcher choice(String value, [String? labelOrId]) {
  var matcher = isA<SelectChoice>().having((c) => c.value, 'value', value);
  if (labelOrId != null) {
    matcher = matcher.having(
      (c) => c.isLocalizable ? c.textId : c.labelInnerText,
      'label or id',
      labelOrId,
    );
  }
  return matcher;
}

/// A form without validation failures. Port of `FormDefMatchers.valid`.
final Matcher valid = isA<FormDef>().having(
  (f) => f.validate(),
  'validation outcome',
  isNull,
);
