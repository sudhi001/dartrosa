// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntityFormFinalizationProcessorTest), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of
// org.odk.collect.entities.javarosa.EntityFormFinalizationProcessorTest.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

import '../support/entity_xforms_element.dart';

Future<Scenario> _init(XFormsElement form) =>
    Scenario.init(form, parserFactory: entityParser);

XFormsElement _entityForm(
  List<XFormsElement> instanceChildren,
  List<XFormsElement> binds,
  List<XFormsElement> bodyChildren,
) => html(
  additionalNamespaces: entitiesNs,
  head([
    title('Create entity form'),
    entityModel('2024.1.0', [
      mainInstance([
        t('data id="create-entity-form"', [
          ...instanceChildren,
          t('meta', [entityNode('people', EntityAction.create)]),
        ]),
      ]),
      ...binds,
      bind('/data/meta/entity/@id')..type('string'),
      setvalue('odk-instance-first-load', '/data/meta/entity/@id', 'uuid()'),
    ]),
  ]),
  body(bodyChildren),
);

void main() {
  test('when form does not have entity element, adds no entities to '
      'extras', () async {
    final scenario = await _init(
      html(
        head([
          title('Normal form'),
          model([
            mainInstance([
              t('data id="normal"', [t('name')]),
            ]),
            bind('/data/name')..type('string'),
          ]),
        ]),
        body([input('/data/name')]),
      ),
    );

    final entryModel = scenario.formEntryController.model;
    const EntityFormFinalizationProcessor().processForm(entryModel);
    expect(entryModel.extras[EntitiesExtra], isNull);
  });

  test('when saveTo is not relevant, it is not included in entity', () async {
    final scenario = await _init(
      _entityForm(
        [t('name'), t('age')],
        [
          bind('/data/name')..type('string'),
          bind('/data/age')
            ..type('string')
            ..withSaveTo('age')
            ..relevant('false()'),
          bind('/data/meta/entity/label')
            ..type('string')
            ..calculate('/data/name'),
        ],
        [input('/data/name')],
      ),
    );

    scenario.answer('/data/name', 'Johannes');
    final entryModel = scenario.formEntryController.model;
    const EntityFormFinalizationProcessor().processForm(entryModel);

    final entities =
        (entryModel.extras[EntitiesExtra]! as EntitiesExtra).entities;
    expect(entities, hasLength(1));
    expect(entities[0].properties, isEmpty);
  });

  test('creates entity with values treated as opaque strings', () async {
    final scenario = await _init(
      _entityForm(
        [t('birthday')],
        [
          bind('/data/birthday')
            ..type('date')
            ..withSaveTo('birthday'),
          bind('/data/meta/entity/label')
            ..type('string')
            ..calculate('/data/birthday'),
        ],
        [input('/data/birthday')],
      ),
    );

    final entryModel = scenario.formEntryController.model;
    scenario.next();
    scenario.formEntryController.answerQuestion(
      DateValue(DateTime(2024, 11, 15)),
      midSurvey: true,
    );
    const EntityFormFinalizationProcessor().processForm(entryModel);

    final entities =
        (entryModel.extras[EntitiesExtra]! as EntitiesExtra).entities;
    expect(entities, hasLength(1));
    expect(entities[0].properties[0], ('birthday', '2024-11-15'));
  });

  test('when saveTo is in not relevant group, it is not included in '
      'entity', () async {
    final scenario = await _init(
      _entityForm(
        [
          t('name'),
          t('group', [t('age')]),
        ],
        [
          bind('/data/name'),
          bind('/data/group')..relevant('false()'),
          bind('/data/group/age')
            ..type('string')
            ..withSaveTo('age'),
          bind('/data/meta/entity/label')
            ..type('string')
            ..calculate('/data/name'),
        ],
        [
          input('/data/name'),
          formGroup('/data/group', [input('/data/group/age')]),
        ],
      ),
    );

    scenario.answer('/data/name', 'Thomas');
    final entryModel = scenario.formEntryController.model;
    const EntityFormFinalizationProcessor().processForm(entryModel);

    final entities =
        (entryModel.extras[EntitiesExtra]! as EntitiesExtra).entities;
    expect(entities, hasLength(1));
    expect(entities[0].properties, isEmpty);
  });

  test('when saveTo is nested in an extra group, creates entity with '
      'values', () async {
    final scenario = await _init(
      _entityForm(
        [
          t('group', [t('name')]),
        ],
        [
          bind('/data/group'),
          bind('/data/group/name')
            ..type('string')
            ..withSaveTo('name'),
          bind('/data/meta/entity/label')
            ..type('string')
            ..calculate('/data/group/name'),
        ],
        [
          formGroup('/data/group', [input('/data/group/name')]),
        ],
      ),
    );

    final entryModel = scenario.formEntryController.model;
    scenario
      ..next()
      ..next();
    scenario.formEntryController.answerQuestion(
      const StringValue('John'),
      midSurvey: true,
    );
    const EntityFormFinalizationProcessor().processForm(entryModel);

    final entities =
        (entryModel.extras[EntitiesExtra]! as EntitiesExtra).entities;
    expect(entities, hasLength(1));
    expect(entities[0].properties[0], ('name', 'John'));
  });
}
