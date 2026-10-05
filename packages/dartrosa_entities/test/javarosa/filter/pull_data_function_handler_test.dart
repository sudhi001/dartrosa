// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (PullDataFunctionHandlerTest), Copyright University
//  of Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.entities.javarosa.filter.PullDataFunctionHandlerTest.
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

Future<Scenario> _pullDataScenario(
  EntitiesRepository entitiesRepository,
  String calculate, {
  XPathFunctionHandler? fallback,
}) => Scenario.init(
  html(
    head([
      title('Pull data form'),
      model([
        mainInstance([
          t('data id="pull-data-form"', [t('question'), t('calculate')]),
        ]),
        bind('/data/question')..type('string'),
        bind('/data/calculate')
          ..type('string')
          ..calculate(calculate),
      ]),
    ]),
    body([input('/data/question'), input('/data/calculate')]),
  ),
  controllerFactory: (formDef) => FormEntryController(FormEntryModel(formDef))
    ..addFunctionHandler(
      PullDataFunctionHandler(entitiesRepository, fallback: fallback),
    ),
);

final class _FakePullData extends XPathFunctionHandler {
  @override
  String get name => 'pulldata';

  @override
  List<List<XPathArgType>> get prototypes => const [];

  @override
  bool get rawArgs => true;

  @override
  Object eval(List<Object> args, EvaluationContext context) => 'fallback';
}

void main() {
  test('returns empty string when there are no matching results', () async {
    final entitiesRepository = InMemEntitiesRepository()..addList('things');
    final scenario = await _pullDataScenario(
      entitiesRepository,
      "pulldata('things', 'label', 'name', 'blah')",
    );
    expect(scenario.answerOf('/data/calculate'), isNull);
  });

  test('returns first match when there are multiple', () async {
    final entitiesRepository = InMemEntitiesRepository()
      ..save('things', [
        NewEntity('one', 'One', properties: const [('property', 'value')]),
      ])
      ..save('things', [
        NewEntity('two', 'Two', properties: const [('property', 'value')]),
      ]);
    final scenario = await _pullDataScenario(
      entitiesRepository,
      "pulldata('things', 'label', 'property', 'value')",
    );
    expect(scenario.answerOf('/data/calculate')?.value, 'One');
  });

  test('returns empty string when uses not existing property', () async {
    final entitiesRepository = InMemEntitiesRepository()
      ..save('things', [NewEntity('one', 'One')]);
    final scenario = await _pullDataScenario(
      entitiesRepository,
      "pulldata('things', 'label', 'property', 'value')",
    );
    expect(scenario.answerOf('/data/calculate'), isNull);
  });

  test('returns empty string when uses not existing property with no '
      'value', () async {
    final entitiesRepository = InMemEntitiesRepository()
      ..save('things', [NewEntity('one', 'One')]);
    final scenario = await _pullDataScenario(
      entitiesRepository,
      "pulldata('things', 'label', 'property', '')",
    );
    expect(scenario.answerOf('/data/calculate'), isNull);
  });

  // Added: instances that are not entity lists go to the fallback.
  test('uses the fallback for other instances', () async {
    final scenario = await _pullDataScenario(
      InMemEntitiesRepository(),
      "pulldata('other', 'label', 'name', 'x')",
      fallback: _FakePullData(),
    );
    expect(scenario.answerOf('/data/calculate')?.value, 'fallback');
  });
}
