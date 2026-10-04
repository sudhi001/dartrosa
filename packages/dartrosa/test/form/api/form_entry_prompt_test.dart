// Port of JavaRosa v6.0.0 FormEntryPromptTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  // region Binding of select choice values to labels
  test(
    'getSelectItemText_onSelectionFromDynamicSelect_withoutTranslations_returnsLabelInnerText',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Select'),
            model([
              mainInstance([
                t("data id='select'", [t('filter'), tText('select', 'a')]),
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
            input('/data/filter'),
            select1Dynamic(
              '/data/select',
              "instance('choices')/root/item[starts-with(value,/data/filter)]",
            ),
          ]),
        ),
      );

      scenario
        ..next()
        ..answerCurrent('a')
        ..next();
      final questionPrompt = scenario.formEntryPromptAtIndex;
      expect(questionPrompt.answerText, 'A');
    },
  );

  test(
    'getSelectItemText_onSelectionFromDynamicSelect_withTranslations_returnsCorrectTranslation',
    () async {
      XFormsElement text(String id, String value) =>
          t("text id='$id'", [tText('value', value)]);
      final scenario = await Scenario.init(
        html(
          head([
            title('Multilingual dynamic select'),
            model([
              t('itext', [
                t("translation lang='fr'", [
                  text('choices-0', 'A (fr)'),
                  text('choices-1', 'B (fr)'),
                  text('choices-2', 'C (fr)'),
                ]),
                t("translation lang='en'", [
                  text('choices-0', 'A (en)'),
                  text('choices-1', 'B (en)'),
                  text('choices-2', 'C (en)'),
                ]),
              ]),
              mainInstance([
                t("data id='multilingual-select'", [tText('select', 'b')]),
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

      scenario
        ..language = 'en'
        ..next();
      final questionPrompt = scenario.formEntryPromptAtIndex;
      expect(questionPrompt.answerText, 'B (en)');

      scenario.language = 'fr';
      expect(questionPrompt.answerText, 'B (fr)');
    },
  );

  test(
    'getSelectItemText_onSelectionsInRepeatInstances_returnsLabelInnerText',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Select'),
            model([
              mainInstance([
                t("data id='select-repeat'", [
                  t('repeat', [tText('select', 'a')]),
                  t('repeat', [tText('select', 'a')]),
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
              select1Dynamic(
                '/data/repeat/select',
                "instance('choices')/root/item",
              ),
            ]),
          ]),
        ),
      );

      scenario.next(2);
      var questionPrompt = scenario.formEntryPromptAtIndex;
      expect(questionPrompt.answerText, 'A');

      // Prior to https://github.com/getodk/javarosa/issues/642 being
      // addressed, the selected choice for a select in a repeat instance
      // with the same choice list as the prior repeat instance's select
      // would not be bound to its label
      scenario.next(2);
      questionPrompt = scenario.formEntryPromptAtIndex;
      expect(questionPrompt.answerText, 'A');
    },
  );
  // endregion
}
