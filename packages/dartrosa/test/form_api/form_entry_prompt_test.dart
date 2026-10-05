// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports) of FormEntryPrompt: hints, answer texts of
// secret and multi-select questions, special text forms of choices,
// constraint hints, bind attributes and deprecated <copy> itemsets. JavaRosa
// has no tests for most of these; every expectation was captured from
// JavaRosa 6.0.0 (jshell, FormEntryPrompt on the same forms).
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:dartrosa/src/model/condition/pivot.dart';
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const promptsForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms">
<h:head><h:title>Prompts</h:title><model>
<itext>
<translation lang="en"><text id="q-hint"><value>Hint for <output value="/data/name"/></value></text>
<text id="c-a"><value>Apple</value><value form="image">jr://images/a.png</value><value form="short">A</value></text>
<text id="c-b"><value>Banana</value></text>
<text id="only-en"><value>Only EN</value></text>
</translation>
<translation lang="fr"><text id="q-hint"><value>Indice <output value="/data/name"/></value></text>
<text id="c-a"><value>Pomme</value></text>
<text id="c-b"><value>Banane</value></text>
</translation>
</itext>
<instance><data id="prompts"><name>Bob</name><pin/><fruits/><age/><missing/></data></instance>
<bind nodeset="/data/pin" type="string"/>
<bind nodeset="/data/age" type="int" constraint=". &gt;= 18 and . &lt; 65" odk:foo="bar"/>
</model></h:head>
<h:body>
<input ref="/data/name"><label>Name</label><hint>Literal hint</hint></input>
<secret ref="/data/pin"><label>PIN</label></secret>
<select ref="/data/fruits"><label>Fruits</label><hint ref="jr:itext('q-hint')"/>
<item><label ref="jr:itext('c-a')"/><value>a</value></item>
<item><label ref="jr:itext('c-b')"/><value>b</value></item>
<item><label>Cherry</label><value>c</value></item>
</select>
<input ref="/data/age"><label>Age</label></input>
<input ref="/data/missing"><label>Missing</label><hint ref="jr:itext('only-en')"/></input>
</h:body></h:html>
''';

const copyForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
<h:head><h:title>Copy</h:title><model>
<instance><data id="copy">
<src><item><v>a</v><n>Alpha</n></item><item><v>b</v><n>Beta</n></item><item><v>c</v><n>Gamma</n></item></src>
<sel><item jr:template=""><v/><n/></item></sel>
<one><item jr:template=""><v/><n/></item></one>
<nov><item jr:template=""><v/><n/></item></nov>
</data></instance>
</model></h:head>
<h:body>
<select ref="/data/sel"><label>Many</label><itemset nodeset="/data/src/item"><label ref="n"/><value ref="v"/><copy ref="."/></itemset></select>
<select1 ref="/data/one"><label>One</label><itemset nodeset="/data/src/item"><label ref="n"/><value ref="v"/><copy ref="."/></itemset></select1>
<select1 ref="/data/nov"><label>NoValue</label><itemset nodeset="/data/src/item"><label ref="n"/><copy ref="."/></itemset></select1>
</h:body></h:html>
''';

/// The `v/n` values of the copies under [node], e.g. `c/Gamma`.
List<String> copies(TreeElement node) => [
  for (final item in node.children)
    if (item.multiplicity >= 0)
      '${item.childAt(0).value?.displayText}/${item.childAt(1).value?.displayText}',
];

void main() {
  group('prompts', () {
    late Scenario scenario;

    setUp(() async {
      scenario = await Scenario.fromXml(promptsForm);
      scenario.language = 'en';
    });

    FormEntryPrompt promptAt(String xPath) => scenario.formEntryController.model
        .questionPrompt(scenario.indexOf(xPath));

    test('help text is localized with outputs, else literal', () {
      expect(promptAt('/data/name').helpText, 'Literal hint');
      expect(promptAt('/data/fruits').helpText, 'Hint for Bob');
      scenario.language = 'fr';
      expect(promptAt('/data/fruits').helpText, 'Indice Bob');
      // Missing translations fall back to the default language.
      expect(promptAt('/data/missing').helpText, 'Only EN');
    });

    test('secret answers are shown as asterisks', () {
      scenario.answer('/data/pin', '1234');
      final prompt = promptAt('/data/pin');
      expect(prompt.controlType, ControlType.secret);
      expect(prompt.answerText, '****');
    });

    test('multi-select answer text lists labels with trailing spaces', () {
      scenario.answer('/data/fruits', ['a', 'c']);
      expect(promptAt('/data/fruits').answerText, 'Apple Cherry ');
      scenario.language = 'fr';
      expect(promptAt('/data/fruits').answerText, 'Pomme Cherry ');
    });

    test('special forms of choice labels', () {
      final prompt = promptAt('/data/fruits');
      final [a, b, c] = prompt.selectChoices;
      expect(
        prompt.specialFormSelectChoiceText(a, 'image'),
        'jr://images/a.png',
      );
      expect(prompt.specialFormSelectChoiceText(a, 'short'), 'A');
      expect(prompt.specialFormSelectChoiceText(b, 'image'), isNull);
      // Choices without itext have no special forms.
      expect(prompt.specialFormSelectChoiceText(c, 'image'), isNull);
      expect(prompt.selectChoiceText(c), 'Cherry');
    });

    test('unattached selections are attached by value', () {
      final prompt = promptAt('/data/fruits');
      expect(prompt.selectItemText(const Selection('b')), 'Banana');
      expect(
        prompt.specialFormSelectItemText(const Selection('a'), 'short'),
        'A',
      );
    });

    test('constraint hint gives the range of the constraint', () {
      final prompt = promptAt('/data/age');
      final hint = IntegerRangeHint();
      prompt.requestConstraintHint(hint);
      expect(hint.min, const IntegerValue(18));
      expect(hint.minInclusive, isTrue);
      expect(hint.max, const IntegerValue(65));
      expect(hint.maxInclusive, isFalse);
      expect(prompt.constraintText(), isNull);
    });

    test('constraint hint without constraint is unpivotable', () {
      expect(
        () =>
            promptAt('/data/missing').requestConstraintHint(IntegerRangeHint()),
        throwsA(isA<UnpivotableExpressionException>()),
      );
    });

    test('non-JavaRosa bind attributes are kept', () {
      final [attr] = promptAt('/data/age').bindAttributes;
      expect(attr.name, 'foo');
      expect(attr.attributeValue, 'bar');
    });
  });

  group('copy itemsets', () {
    late Scenario scenario;

    setUp(() async => scenario = await Scenario.fromXml(copyForm));

    FormEntryPrompt promptAt(String xPath) => scenario.formEntryController.model
        .questionPrompt(scenario.indexOf(xPath));

    AnswerStatus answer(String xPath, AnswerValue value) => scenario
        .formEntryController
        .answerQuestion(value, index: scenario.indexOf(xPath));

    test('selections copy the chosen subtrees', () {
      var prompt = promptAt('/data/sel');
      expect(prompt.question.isComplex, isTrue);
      expect(prompt.answerValue, isNull);
      final [a, _, c] = prompt.selectChoices;
      expect(
        answer(
          '/data/sel',
          MultipleItemsValue([Selection.ofChoice(c), Selection.ofChoice(a)]),
        ),
        AnswerStatus.ok,
      );
      prompt = promptAt('/data/sel');
      expect(prompt.answerValue!.displayText, 'c, a');
      expect(prompt.answerText, 'Gamma Alpha ');
      expect(copies(scenario.getAnswerNode('/data/sel')), [
        'c/Gamma',
        'a/Alpha',
      ]);

      // A still-selected copy is reused, the others are removed.
      answer('/data/sel', MultipleItemsValue([Selection.ofChoice(a)]));
      expect(copies(scenario.getAnswerNode('/data/sel')), ['a/Alpha']);
    });

    test('select one copies one subtree', () {
      var prompt = promptAt('/data/one');
      expect(prompt.answerValue, isNull);
      answer(
        '/data/one',
        SelectOneValue(Selection.ofChoice(prompt.selectChoices[1])),
      );
      prompt = promptAt('/data/one');
      expect(prompt.answerValue, isA<SelectOneValue>());
      expect(prompt.answerValue!.displayText, 'b');
      expect(prompt.answerText, 'Beta');
      expect(copies(scenario.getAnswerNode('/data/one')), ['b/Beta']);
    });

    test('without <value> the copy is made but there is no answer', () {
      final prompt = promptAt('/data/nov');
      answer(
        '/data/nov',
        SelectOneValue(Selection.ofChoice(prompt.selectChoices[2])),
      );
      expect(promptAt('/data/nov').answerValue, isNull);
      expect(copies(scenario.getAnswerNode('/data/nov')), ['c/Gamma']);
    });
  });
}
