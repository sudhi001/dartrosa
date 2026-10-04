// Port of JavaRosa v6.0.0 DynamicSelectUpdateTest.
//
// Integration tests to verify that the choice lists for "dynamic selects"
// (selects with itemsets rather than inline items) are updated when
// dependent values change.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

XFormsElement _selectFromRepeatForm([String predicate = '']) => html(
  head([
    title('Select from repeat'),
    model([
      mainInstance([
        t("data id='repeat-select'", [
          t('repeat', [t('value'), t('label')]),
          t('filter'),
          t('select'),
        ]),
      ]),
    ]),
  ]),
  body([
    repeat('/data/repeat', [input('value'), input('label')]),
    input('filter'),
    select1Dynamic(
      '/data/select',
      '../repeat${predicate.isNotEmpty ? '[$predicate]' : ''}',
    ),
  ]),
);

void main() {
  // region Select from repeat
  // Unlike static secondary instances, repeats are dynamic. Repeat instances
  // (items) can be added or removed. The contents of those instances (item
  // values, labels) can also change.
  test('selectFromRepeat_whenRepeatAdded_updatesChoices', () async {
    final scenario = await Scenario.init(_selectFromRepeatForm());

    scenario
      ..answer('/data/repeat[1]/value', 'a')
      ..answer('/data/repeat[1]/label', 'A');
    expect(scenario.choicesOf('/data/select'), equals([choice('a', 'A')]));

    scenario
      ..answer('/data/repeat[2]/value', 'b')
      ..answer('/data/repeat[2]/label', 'B');
    expect(
      scenario.choicesOf('/data/select'),
      unorderedMatches([choice('a', 'A'), choice('b', 'B')]),
    );
  });

  test('selectFromRepeat_whenRepeatChanged_updatesChoices', () async {
    final scenario = await Scenario.init(_selectFromRepeatForm());

    scenario
      ..answer('/data/repeat[1]/value', 'a')
      ..answer('/data/repeat[1]/label', 'A');
    expect(scenario.choicesOf('/data/select'), equals([choice('a', 'A')]));

    scenario
      ..answer('/data/repeat[1]/value', 'c')
      ..answer('/data/repeat[1]/label', 'C');
    expect(scenario.choicesOf('/data/select'), equals([choice('c', 'C')]));
    expect(scenario.choicesOf('/data/select'), hasLength(1));
  });

  test('selectFromRepeat_whenRepeatRemoved_updatesChoices', () async {
    final scenario = await Scenario.init(_selectFromRepeatForm());

    scenario
      ..answer('/data/repeat[1]/value', 'a')
      ..answer('/data/repeat[1]/label', 'A');
    expect(scenario.choicesOf('/data/select'), equals([choice('a', 'A')]));

    scenario.removeRepeat('/data/repeat[1]');
    expect(scenario.choicesOf('/data/select'), hasLength(0));
  });

  test(
    'selectFromRepeat_withPredicate_whenPredicateTriggerChanges_updatesChoices',
    () async {
      final scenario = await Scenario.init(
        _selectFromRepeatForm('starts-with(value,current()/../filter)'),
      );

      scenario
        ..answer('/data/repeat[1]/value', 'a')
        ..answer('/data/repeat[1]/label', 'A')
        ..answer('/data/filter', 'a');
      expect(scenario.choicesOf('/data/select'), equals([choice('a', 'A')]));

      scenario.answer('/data/filter', 'b');
      expect(scenario.choicesOf('/data/select'), hasLength(0));
    },
  );
  // endregion

  // region Multi-language
  test('multilanguage', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Multilingual dynamic select'),
          model([
            t('itext', [
              t("translation lang='fr'", [
                t("text id='choices-0'", [tText('value', 'A (fr)')]),
                t("text id='choices-1'", [tText('value', 'B (fr)')]),
                t("text id='choices-2'", [tText('value', 'C (fr)')]),
              ]),
              t("translation lang='en'", [
                t("text id='choices-0'", [tText('value', 'A (en)')]),
                t("text id='choices-1'", [tText('value', 'B (en)')]),
                t("text id='choices-2'", [tText('value', 'C (en)')]),
              ]),
            ]),
            mainInstance([
              t("data id='multilingual-select'", [t('select')]),
            ]),
            instance('choices', [
              t('item', [tText('itextId', 'choices-0'), tText('name', 'a')]),
              t('item', [tText('itextId', 'choices-1'), tText('name', 'b')]),
              t('item', [tText('itextId', 'choices-2'), tText('name', 'c')]),
            ]),
          ]),
        ]),
        body([
          select1Dynamic(
            '/data/select',
            "instance('choices')/root/item",
            valueRef: 'name',
            labelRef: 'jr:itext(itextId)',
          ),
        ]),
      ),
    );

    scenario.language = 'en';
    expect(scenario.choicesOf('/data/select'), hasLength(3));
    expect(
      scenario.choicesOf('/data/select'),
      unorderedMatches([
        choice('a', 'choices-0'),
        choice('b', 'choices-1'),
        choice('c', 'choices-2'),
      ]),
    );
  });
  // endregion

  test('selectWithChangedTriggers_recomputesChoiceList', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Select'),
          model([
            mainInstance([
              t("data id='select'", [t('filter'), t('select')]),
            ]),
            instance('choices', [
              item('aa', 'A'),
              item('aaa', 'AA'),
              item('bb', 'B'),
              item('bbb', 'BB'),
            ]),
          ]),
        ]),
        body([
          input('/data/filter'),
          select1Dynamic(
            '/data/select',
            "instance('choices')/root/item[starts-with(value,/data/filter)]",
          ),
        ]),
      ),
    );

    scenario.answer('/data/filter', 'a');
    final choices = scenario.choicesOf('/data/select');
    expect(choices, unorderedMatches([choice('aa', 'A'), choice('aaa', 'AA')]));

    scenario.answer('/data/filter', 'aa');
    expect(choices, unorderedMatches([choice('aa', 'A'), choice('aaa', 'AA')]));
    // Even though the list happens to be unchanged, it should have been
    // recomputed because the trigger value changed
    expect(scenario.choicesOf('/data/select'), isNot(same(choices)));
  });

  test(
    'selectWithRepeatAsTrigger_recomputesChoiceListAtEveryRequest',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Repeat trigger'),
            model([
              mainInstance([
                t("data id='repeat-trigger'", [
                  t('repeat', [t('question')]),
                  t('select'),
                ]),
              ]),
              instance('choices', [
                item('1', 'A'),
                item('2', 'AA'),
                item('3', 'B'),
                item('4', 'BB'),
              ]),
            ]),
          ]),
          body([
            repeat('/data/repeat', [input('/data/repeat/question')]),
            select1Dynamic(
              '/data/select',
              "instance('choices')/root/item[value>count(/data/repeat)]",
            ),
          ]),
        ),
      );

      scenario.answer('/data/repeat[1]/question', 'a');
      expect(scenario.choicesOf('/data/select'), hasLength(3));

      scenario.answer('/data/repeat[2]/question', 'b');
      final choices = scenario.choicesOf('/data/select');
      expect(choices, hasLength(2));
      // Because of the repeat trigger in the count expression, choices should
      // be recomputed every time they're requested
      expect(scenario.choicesOf('/data/select'), isNot(same(choices)));
    },
  );

  // region Caching for selects in repeat
  // When a dynamic select is in a repeat, the itemsets for all repeat
  // instances are represented by the same ItemsetBinding.
  test(
    'selectInRepeat_withRefToRepeatChildInPredicate_evaluatesChoiceListForEachRepeatInstance',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Select in repeat'),
            model([
              mainInstance([
                t("data id='repeat-select'", [
                  t('repeat', [t('filter'), t('select')]),
                ]),
              ]),
              instance('choices', [
                item('a', 'A'),
                item('aa', 'AA'),
                item('b', 'B'),
                item('bb', 'BB'),
              ]),
            ]),
          ]),
          body([
            repeat('/data/repeat', [
              input('filter'),
              select1Dynamic(
                '/data/repeat/select',
                "instance('choices')/root/item"
                    '[starts-with(value,current()/../filter)]',
              ),
            ]),
          ]),
        ),
      );

      scenario
        ..answer('/data/repeat[1]/filter', 'a')
        ..answer('/data/repeat[2]/filter', 'a');
      final repeat0Choices = scenario.choicesOf('/data/repeat[1]/select');
      final repeat1Choices = scenario.choicesOf('/data/repeat[2]/select');

      // The trigger keys are /data/repeat[1]/filter and
      // /data/repeat[2]/filter which means no caching between them
      expect(repeat0Choices, isNot(same(repeat1Choices)));

      scenario.answer('/data/repeat[2]/filter', 'bb');
      expect(scenario.choicesOf('/data/repeat[1]/select'), hasLength(2));
      expect(scenario.choicesOf('/data/repeat[2]/select'), hasLength(1));
    },
  );
  // endregion
}
