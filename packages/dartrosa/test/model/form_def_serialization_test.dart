// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormDefSerializationTest), Copyright (C) 2020 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 FormDefSerializationTest.
//
// JavaRosa's Externalizable FormDef round trip is a FormDefCodec round
// trip (Scenario.serializeAndDeserializeForm).
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

Future<Scenario> _getSimplestFormScenario() => Scenario.init(
  html(
    head([
      title('Simplest'),
      model([
        mainInstance([
          t('data id="simplest"', [t('a')]),
        ]),
        bind('/data/a')..type('string'),
      ]),
    ]),
    body([input('/data/a')]),
  ),
);

void main() {
  test('instanceName_forReferenceInMainInstance_isAlwaysNull', () async {
    final scenario = await _getSimplestFormScenario();

    scenario.next();
    expect(scenario.refAtIndex!.instanceName, isNull);

    final deserialized = await scenario.serializeAndDeserializeForm();

    deserialized.next();
    expect(deserialized.refAtIndex!.instanceName, isNull);
  });

  // During form evaluation, most relative references are contextualized
  // directly or indirectly using the FormDef evaluation context.
  test('instanceName_forFormDefEvaluationContext_isAlwaysNull', () async {
    final scenario = await _getSimplestFormScenario();

    scenario.next();
    expect(scenario.formDef.evaluationContext.contextRef.instanceName, isNull);

    final deserialized = await scenario.serializeAndDeserializeForm();

    deserialized.next();
    expect(
      deserialized.formDef.evaluationContext.contextRef.instanceName,
      isNull,
    );
  });

  // Constraint evaluation uses XPathPathExprEval.eval which uses the main
  // instance from the FormDef to get a TreeReference. Then
  // XPathPathExpr.getRefValue sees whether that reference is the same as
  // the latest modified question by using TreeRefence.equals. In the
  // original JavaRosa implementation, the main instance name was null prior
  // to serialization and set after deserialization.
  test('instanceName_forFormDefMainInstance_isAlwaysNull', () async {
    final scenario = await _getSimplestFormScenario();

    scenario.next();
    expect(scenario.formDef.mainInstance.base.instanceName, isNull);

    final deserialized = await scenario.serializeAndDeserializeForm();

    deserialized.next();
    expect(deserialized.formDef.mainInstance.base.instanceName, isNull);
  });

  test(
    'serializeAndDeserializeFormWithDefaultAnswerInSelectQuestion_worksCorrectly',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Internal choices'),
            model([
              mainInstance([
                t("data id='main-instance'", [
                  tText('select-from-secondary-instance', 'a'),
                ]),
              ]),
              instance('secondary-instance', [
                t('item', [tText('label', 'A'), tText('value', 'a')]),
              ]),
            ]),
          ]),
          body([
            select1Dynamic(
              '/data/select-from-secondary-instance',
              "instance('secondary-instance')/root/item",
            ),
          ]),
        ),
      );

      await scenario.serializeAndDeserializeForm();
    },
  );
}
