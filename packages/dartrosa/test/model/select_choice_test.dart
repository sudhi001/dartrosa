@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 SelectChoiceTest.
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

/// A form selecting from the repeat `/data/repeat` with children `value`,
/// `label` and `special-property`, bound by [inputRef].
XFormsElement _selectFromRepeatForm(String Function(String name) inputRef) =>
    html(
      head([
        title('Select from repeat'),
        model([
          mainInstance([
            t("data id='repeat-select'", [
              t('repeat', [t('value'), t('label'), t('special-property')]),
              t('filter'),
              t('select'),
            ]),
          ]),
        ]),
      ]),
      body([
        repeat('/data/repeat', [
          input(inputRef('value')),
          input(inputRef('label')),
          input(inputRef('special-property')),
        ]),
        input('filter'),
        select1Dynamic('/data/select', '../repeat'),
      ]),
    );

XFormsElement _staticSelectForm() => html(
  head([
    title('Static select'),
    model([
      mainInstance([
        t("data id='static-select'", [t('select')]),
      ]),
    ]),
  ]),
  body([
    select1('/data/select', [item('one', 'One'), item('two', 'Two')]),
  ]),
);

void main() {
  test(
    'value_should_continue_being_an_empty_string_after_deserialization',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test('value_should_be_trimmed_when_select_choice_object_constructed', () {
    final choice = SelectChoice(null, 'Label', ' value ', isLocalizable: false);

    expect(choice.value, 'value');
  });

  test(
    'getChild_returnsNamedChild_whenChoicesAreFromSecondaryInstance',
    () async {
      final scenario = await scenarioFor('external-select-geojson.xml');
      expect(scenario.choicesOf('/data/q')[1].child('geometry'), '0.5 104 0 0');
      expect(
        scenario.choicesOf('/data/q')[1].child('special-property'),
        'special value',
      );
    },
  );

  test(
    'getChild_returnsNull_whenChoicesAreFromSecondaryInstance_andRequestedChildDoesNotExist',
    () async {
      final scenario = await scenarioFor('external-select-geojson.xml');
      expect(scenario.choicesOf('/data/q')[1].child('non-existent'), isNull);
    },
  );

  test(
    'getChild_returnsEmptyString_whenChoicesAreFromSecondaryInstance_andRequestedChildHasNoValue',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Select with empty value'),
            model([
              mainInstance([
                t("data id='select-empty'", [t('select')]),
              ]),
              instance('choices', [
                t('item', [
                  tText('label', 'Item'),
                  tText('name', 'item'),
                  tText('property', ''),
                ]),
              ]),
            ]),
          ]),
          body([
            select1Dynamic(
              '/data/select',
              "instance('choices')/root/item",
              valueRef: 'name',
            ),
          ]),
        ),
      );

      expect(scenario.choicesOf('/data/select')[0].child('property'), '');
    },
  );

  test('getChild_updates_whenChoicesAreFromRepeat', () async {
    final scenario = await Scenario.init(_selectFromRepeatForm((n) => n));
    scenario
      ..answer('/data/repeat[0]/value', 'a')
      ..answer('/data/repeat[0]/label', 'A')
      ..answer('/data/repeat[0]/special-property', 'AA');

    expect(scenario.choicesOf('/data/select')[0].value, 'a');
    expect(
      scenario.choicesOf('/data/select')[0].child('special-property'),
      'AA',
    );

    scenario.answer('/data/repeat[0]/special-property', 'changed');
    expect(
      scenario.choicesOf('/data/select')[0].child('special-property'),
      'changed',
    );
  });

  test('getChild_returnsNull_whenCalledOnAChoiceFromInlineSelect', () async {
    final scenario = await Scenario.init(_staticSelectForm());

    expect(
      scenario.choicesOf('/data/select')[0].child('invalid-property'),
      isNull,
    );
  });

  test(
    'getAdditionalChildren_returnsChildrenInOrder_whenChoicesAreFromSecondaryInstance',
    () async {
      final scenario = await scenarioFor('external-select-geojson.xml');

      final firstNodeChildren = scenario
          .choicesOf('/data/q')[0]
          .additionalChildren;
      expect(firstNodeChildren, hasLength(3));
      expect(firstNodeChildren[0], ('geometry', '0.5 102 0 0'));
      expect(firstNodeChildren[1], ('id', 'fs87b'));
      expect(firstNodeChildren[2], ('foo', 'bar'));

      final secondNodeChildren = scenario
          .choicesOf('/data/q')[1]
          .additionalChildren;
      expect(secondNodeChildren, hasLength(4));
      expect(secondNodeChildren[0], ('geometry', '0.5 104 0 0'));
      expect(secondNodeChildren[1], ('id', '67'));
      expect(secondNodeChildren[2], ('foo', 'quux'));
      expect(secondNodeChildren[3], ('special-property', 'special value'));
    },
  );

  test('getChildren_updates_whenChoicesAreFromRepeat', () async {
    final scenario = await Scenario.init(
      _selectFromRepeatForm((n) => '/data/repeat/$n'),
    );
    scenario
      ..answer('/data/repeat[0]/value', 'a')
      ..answer('/data/repeat[0]/label', 'A')
      ..answer('/data/repeat[0]/special-property', 'AA');

    expect(scenario.choicesOf('/data/select')[0].value, 'a');
    var children = scenario.choicesOf('/data/select')[0].additionalChildren;
    expect(children, hasLength(2));
    expect(children[0], ('value', 'a'));
    expect(children[1], ('special-property', 'AA'));

    scenario.answer('/data/repeat[0]/special-property', 'changed');
    children = scenario.choicesOf('/data/select')[0].additionalChildren;
    expect(children[1], ('special-property', 'changed'));
  });

  test('selectFromRepeat_usesSpecifiedValueAndLabelRefs', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Select from repeat'),
          model([
            mainInstance([
              t("data id='repeat-select'", [
                t('repeat', [t('first_name')]),
                t('select'),
              ]),
            ]),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/first_name')]),
          select1Dynamic(
            '/data/select',
            "/data/repeat[./first_name != '']",
            valueRef: 'first_name',
            labelRef: 'first_name',
          ),
        ]),
      ),
    );
    scenario.answer('/data/repeat[0]/first_name', 'b');

    expect(scenario.choicesOf('/data/select')[0].value, 'b');
    expect(scenario.choicesOf('/data/select')[0].labelInnerText, 'b');
  });

  test(
    'getAdditionalChildren_returnsEmpty_whenCalledOnAChoiceFromInlineSelect',
    () async {
      final scenario = await Scenario.init(_staticSelectForm());

      expect(scenario.choicesOf('/data/select')[0].additionalChildren, isEmpty);
    },
  );

  test(
    'getAdditionalChildren_returnsEmptyStringValue_forEmptyChildren',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Internal instance select'),
            model([
              mainInstance([
                t("data id='static-select'", [t('select')]),
              ]),
              instance('instance', [
                t('item', [
                  tText('label', 'label'),
                  tText('value', 'value'),
                  t('child'),
                ]),
              ]),
            ]),
          ]),
          body([
            select1Dynamic('/data/select', "instance('instance')/root/item"),
          ]),
        ),
      );

      expect(scenario.choicesOf('/data/select')[0].additionalChildren, [
        ('value', 'value'),
        ('child', ''),
      ]);
    },
  );

  test('itemsetBindingVerification_doesNotVerifySecondItem', () async {
    await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('first')]),
            ]),
            t('instance id="mixed-schema"', [
              t('root', [
                t('item', [tText('label', 'A'), tText('name', 'a')]),
                t('item', [t('foo')]),
              ]),
            ]),
            bind('/data/first')..type('string'),
          ]),
        ]),
        body([
          // Define a select using value and label references that only
          // exist for the first item
          select1Dynamic(
            '/data/first',
            "instance('mixed-schema')/root/item",
            valueRef: 'name',
          ),
        ]),
      ),
    );
  });

  test('itemsetBindingVerification_verifiesFirstItem', () async {
    await expectLater(
      Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [t('first')]),
              ]),
              t('instance id="mixed-schema"', [
                t('root', [
                  t('item', [tText('foo', 'bar')]),
                  t('item', [tText('label', 'A'), tText('value', 'a')]),
                ]),
              ]),
              bind('/data/first')..type('string'),
            ]),
          ]),
          body([
            // Define a select using value and label references that only
            // exist for the second item
            select1Dynamic(
              '/data/first',
              "instance('mixed-schema')/root/item",
              valueRef: 'name',
            ),
          ]),
        ),
      ),
      throwsA(isA<XFormParseException>()),
    );
  });
}
