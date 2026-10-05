// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (MultiplePredicateTest), Copyright (C) 2009 JavaRosa
//  and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 MultiplePredicateTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('calculatesSupportMultiplePredicatesInOnePartOfPath', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('calc'), t('input')]),
            ]),
            instance('instance', [
              t('item', [
                tText('value', 'A'),
                tText('count', '2'),
                tText('id', 'A2'),
              ]),
              t('item', [
                tText('value', 'A'),
                tText('count', '3'),
                tText('id', 'A3'),
              ]),
              t('item', [
                tText('value', 'B'),
                tText('count', '2'),
                tText('id', 'B2'),
              ]),
            ]),
            bind('/data/calc')
              ..type('string')
              ..calculate(
                "instance('instance')/root/item[value = 'A']"
                '[count = /data/input]/id',
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    scenario.answer('/data/input', '3');
    expect(scenario.answerOf('/data/calc')!.value, 'A3');

    scenario.answer('/data/input', '2');
    expect(scenario.answerOf('/data/calc')!.value, 'A2');

    scenario.answer('/data/input', '7');
    expect(scenario.answerOf('/data/calc'), isNull);
  });

  test('calculatesSupportMultiplePredicatesInMultiplePartsOfPath', () async {
    XFormsElement person(String name, String yob, List<XFormsElement> kids) =>
        t('item', [tText('name', name), tText('yob', yob), ...kids]);
    XFormsElement child(String name, String yob) =>
        t('child', [tText('name', name), tText('yob', yob)]);

    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('calc'), t('input')]),
            ]),
            instance('instance', [
              person('Bob Smith', '1966', [
                child('Sally Smith', '1988'),
                child('Kwame Smith', '1990'),
              ]),
              person('Hu Xao', '1972', [
                child('Foo Bar', '1988'),
                child('Foo2 Bar', '2008'),
              ]),
              person('Baz Quux', '1968', [
                child('Baz2 Quux', '1988'),
                child('Baz3 Quux', '1988'),
              ]),
            ]),
            bind('/data/calc')
              ..type('string')
              ..calculate(
                "count(instance('instance')/root/item[yob < 1970]"
                '/child[yob = 1988])',
              ),
            bind('/data/input')..type('string'),
          ]),
        ]),
        body([input('/data/input')]),
      ),
    );

    expect(scenario.answerOf('/data/calc')!.value, 3);
  });
}
