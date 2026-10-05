// Port of org.odk.collect.entities.javarosa.EntitiesTest.
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

import '../support/entity_xforms_element.dart';

Future<Scenario> _init(XFormsElement form) =>
    Scenario.init(form, parserFactory: entityParser);

void _addProcessor(Scenario scenario) => scenario.formEntryController
    .addPostProcessor(const EntityFormFinalizationProcessor());

List<FormEntity> _entities(Scenario scenario) =>
    entitiesExtraOf(scenario)!.entities;

/// Two groups `people` and `cars`, each with an entity that is updated
/// when [updates], else created (Collect's multiple-groups forms); [action]
/// names the form.
XFormsElement _multipleGroupsForm(String action, {required bool updates}) {
  String entity(String dataset) => updates
      ? 'entity dataset="$dataset" update="1" id="123" baseVersion="1"'
      : 'entity dataset="$dataset" create="1" id=""';
  return html(
    additionalNamespaces: entitiesNs,
    head([
      title('$action entities from multiple groups form'),
      entityModel('2025.1.0', [
        mainInstance([
          t('data id="multiple-groups-form"', [
            t('people', [
              t('name'),
              t('meta', [
                t(entity('people'), [t('label')]),
              ]),
            ]),
            t('cars', [
              t('model'),
              t('meta', [
                t(entity('cars'), [t('label')]),
              ]),
            ]),
          ]),
        ]),
        bind('/data/people/name')
          ..type('string')
          ..withSaveTo('name'),
        bind('/data/people/meta/entity/@id')..type('string'),
        bind('/data/people/meta/entity/label')
          ..type('string')
          ..calculate('/data/people/name'),
        setvalue(
          'odk-instance-first-load',
          '/data/people/meta/entity/@id',
          'uuid()',
        ),
        bind('/data/cars/model')
          ..type('string')
          ..withSaveTo('car_model'),
        bind('/data/cars/meta/entity/@id')..type('string'),
        bind('/data/cars/meta/entity/label')
          ..type('string')
          ..calculate('/data/cars/model'),
        setvalue(
          'odk-instance-first-load',
          '/data/cars/meta/entity/@id',
          'uuid()',
        ),
      ]),
    ]),
    body([
      formGroup('/data/people', [input('/data/people/name')]),
      formGroup('/data/cars', [input('/data/cars/model')]),
    ]),
  );
}

XFormsElement _repeatsForm({required bool updates}) {
  final entity = updates
      ? 'entity dataset="people" update="1" id="123" baseVersion="1"'
      : 'entity dataset="people" create="1" id=""';
  return html(
    additionalNamespaces: entitiesNs,
    head([
      title('Entities from repeats form'),
      entityModel('2025.1.0', [
        mainInstance([
          t('data id="entities-from-repeats-form"', [
            t('people', [
              t('name'),
              t('meta', [
                t(entity, [t('label')]),
              ]),
            ]),
          ]),
        ]),
        bind('/data/people/name')
          ..type('string')
          ..withSaveTo('name'),
        bind('/data/people/meta/entity/@id')..type('string'),
        bind('/data/people/meta/entity/label')
          ..type('string')
          ..calculate('/data/people/name'),
        setvalue(
          'odk-instance-first-load',
          '/data/people/meta/entity/@id',
          'uuid()',
        ),
      ]),
    ]),
    body([
      repeat('/data/people', [
        input('/data/people/name'),
        setvalue('odk-new-repeat', '/data/people/meta/entity/@id', 'uuid()'),
      ]),
    ]),
  );
}

XFormsElement _nestedRepeatsForm({required bool updates}) {
  String entity(String dataset) => updates
      ? 'entity dataset="$dataset" update="1" id="123" baseVersion="1"'
      : 'entity dataset="$dataset" create="1" id=""';
  return html(
    additionalNamespaces: entitiesNs,
    head([
      title('Entities from nested repeats form'),
      entityModel('2025.1.0', [
        mainInstance([
          t('data id="entities-from-nested-repeats-form"', [
            t('people', [
              t('name'),
              t('cars', [
                t('model'),
                t('meta', [
                  t(entity('cars'), [t('label')]),
                ]),
              ]),
              t('meta', [
                t(entity('people'), [t('label')]),
              ]),
            ]),
          ]),
        ]),
        bind('/data/people/name')
          ..type('string')
          ..withSaveTo('name'),
        bind('/data/people/meta/entity/@id')..type('string'),
        bind('/data/people/meta/entity/label')
          ..type('string')
          ..calculate('/data/people/name'),
        setvalue(
          'odk-instance-first-load',
          '/data/people/meta/entity/@id',
          'uuid()',
        ),
        bind('/data/people/cars/model')
          ..type('string')
          ..withSaveTo('car_model'),
        bind('/data/people/cars/meta/entity/@id')..type('string'),
        bind('/data/people/cars/meta/entity/label')
          ..type('string')
          ..calculate('/data/people/cars/model'),
        setvalue(
          'odk-instance-first-load',
          '/data/people/cars/meta/entity/@id',
          'uuid()',
        ),
      ]),
    ]),
    body([
      repeat('/data/people', [
        input('/data/people/name'),
        setvalue('odk-new-repeat', '/data/people/meta/entity/@id', 'uuid()'),
        repeat('/data/people/cars', [
          input('/data/people/cars/model'),
          setvalue(
            'odk-new-repeat',
            '/data/people/cars/meta/entity/@id',
            'uuid()',
          ),
        ]),
      ]),
    ]),
  );
}

/// A single-entity form with [entityElement] in `meta` and [binds].
XFormsElement _simpleForm(
  XFormsElement entityElement, {
  String version = '2024.1.0',
  List<XFormsElement> instanceChildren = const [],
  List<XFormsElement> binds = const [],
  List<XFormsElement> bodyChildren = const [],
}) => html(
  additionalNamespaces: entitiesNs,
  head([
    title('Entity form'),
    entityModel(version, [
      mainInstance([
        t('data id="entity-form"', [
          ...instanceChildren,
          t('meta', [entityElement]),
        ]),
      ]),
      ...binds,
    ]),
  ]),
  body(bodyChildren),
);

void main() {
  test('filling form without create does not create any entities', () async {
    final scenario = await _init(
      _simpleForm(
        t('entity dataset="people"'),
        instanceChildren: [t('name')],
        binds: [
          bind('/data/name')
            ..type('string')
            ..withSaveTo('name'),
        ],
        bodyChildren: [input('/data/name')],
      ),
    );
    _addProcessor(scenario);

    scenario
      ..answer('/data/name', 'Tom Wambsgans')
      ..finalizeInstance();

    expect(_entities(scenario), isEmpty);
  });

  test('filling form with create makes entity available', () async {
    final scenario = await _init(
      _simpleForm(
        t('entity dataset="people" create="1" id=""', [t('label')]),
        instanceChildren: [t('name')],
        binds: [
          bind('/data/name')
            ..type('string')
            ..withSaveTo('name'),
          entityIdBind(),
          entityIdSetValue(),
          entityLabelBind('/data/name'),
        ],
        bodyChildren: [input('/data/name')],
      ),
    );
    _addProcessor(scenario);

    scenario
      ..answer('/data/name', 'Tom Wambsgans')
      ..finalizeInstance();

    final entities = _entities(scenario);
    expect(entities, hasLength(1));
    expect(entities[0].dataset, 'people');
    expect(entities[0].id, stringAnswer(scenario, '/data/meta/entity/@id'));
    expect(entities[0].label, 'Tom Wambsgans');
    expect(entities[0].properties, [('name', 'Tom Wambsgans')]);
    expect(entities[0].action, EntityAction.create);
  });

  for (final updates in [false, true]) {
    final action = updates ? EntityAction.update : EntityAction.create;
    final name = updates ? 'update' : 'create';

    test('filling form with $name in multiple groups makes entities '
        'available', () async {
      final scenario = await _init(_multipleGroupsForm(name, updates: updates));
      _addProcessor(scenario);

      scenario
        ..answer('/data/people/name', 'Tom Wambsgans')
        ..answer('/data/cars/model', 'Range Rover')
        ..finalizeInstance();

      final entities = _entities(scenario);
      expect(entities, hasLength(2));
      expect(
        entities,
        unorderedEquals([
          FormEntity(
            action,
            'people',
            stringAnswer(scenario, '/data/people/meta/entity/@id'),
            'Tom Wambsgans',
            const [('name', 'Tom Wambsgans')],
          ),
          FormEntity(
            action,
            'cars',
            stringAnswer(scenario, '/data/cars/meta/entity/@id'),
            'Range Rover',
            const [('car_model', 'Range Rover')],
          ),
        ]),
      );
    });

    test(
      'filling form with $name in repeats makes entities available',
      () async {
        final scenario = await _init(_repeatsForm(updates: updates));
        _addProcessor(scenario);

        scenario
          ..answer('/data/people[1]/name', 'Tom Wambsgans')
          ..createNewRepeat('/data/people')
          ..answer('/data/people[2]/name', 'Shiv Roy')
          ..finalizeInstance();

        final entities = _entities(scenario);
        expect(entities, hasLength(2));
        expect(
          entities,
          unorderedEquals([
            FormEntity(
              action,
              'people',
              stringAnswer(scenario, '/data/people[1]/meta/entity/@id'),
              'Tom Wambsgans',
              const [('name', 'Tom Wambsgans')],
            ),
            FormEntity(
              action,
              'people',
              stringAnswer(scenario, '/data/people[2]/meta/entity/@id'),
              'Shiv Roy',
              const [('name', 'Shiv Roy')],
            ),
          ]),
        );
      },
    );

    test('filling form with $name in nested repeats makes entities '
        'available', () async {
      final scenario = await _init(_nestedRepeatsForm(updates: updates));
      _addProcessor(scenario);

      scenario
        ..answer('/data/people[1]/name', 'Tom Wambsgans')
        ..answer('/data/people[1]/cars[1]/model', 'Range Rover')
        ..createNewRepeat('/data/people')
        ..answer('/data/people[2]/name', 'Shiv Roy')
        ..createNewRepeat('/data/people[2]/cars')
        ..answer('/data/people[2]/cars[1]/model', 'Audi A8')
        ..finalizeInstance();

      final entities = _entities(scenario);
      expect(entities, hasLength(4));
      FormEntity entity(String dataset, String ref, String label, String p) =>
          FormEntity(action, dataset, stringAnswer(scenario, ref), label, [
            (p, label),
          ]);
      expect(
        entities,
        unorderedEquals([
          entity(
            'people',
            '/data/people[1]/meta/entity/@id',
            'Tom Wambsgans',
            'name',
          ),
          entity(
            'people',
            '/data/people[2]/meta/entity/@id',
            'Shiv Roy',
            'name',
          ),
          entity(
            'cars',
            '/data/people[1]/cars[1]/meta/entity/@id',
            'Range Rover',
            'car_model',
          ),
          entity(
            'cars',
            '/data/people[2]/cars[1]/meta/entity/@id',
            'Audi A8',
            'car_model',
          ),
        ]),
      );
    });
  }

  for (final (attributes, action) in [
    ('update="1"', EntityAction.update),
    ('create="1" update="1"', EntityAction.upsert),
  ]) {
    test('filling form with $attributes makes entity available with '
        '${action.name} action', () async {
      final scenario = await _init(
        _simpleForm(
          t('entity dataset="people" $attributes id="123" baseVersion="1"', [
            t('label'),
          ]),
          instanceChildren: [t('name')],
          binds: [
            bind('/data/name')
              ..type('string')
              ..withSaveTo('name'),
            entityIdBind(),
            entityIdSetValue(),
            entityLabelBind('/data/name'),
          ],
          bodyChildren: [input('/data/name')],
        ),
      );
      _addProcessor(scenario);
      scenario
        ..answer('/data/name', 'Tom Wambsgans')
        ..finalizeInstance();

      final entities = _entities(scenario);
      expect(entities, hasLength(1));
      expect(entities[0].dataset, 'people');
      expect(entities[0].id, isNotNull);
      expect(entities[0].label, 'Tom Wambsgans');
      expect(entities[0].properties, [('name', 'Tom Wambsgans')]);
      expect(entities[0].action, action);
    });
  }

  test('filling form with dynamic create expression conditionally creates '
      'entities', () async {
    final scenario = await _init(
      _simpleForm(
        entityNode('members', EntityAction.create),
        instanceChildren: [t('name'), t('join')],
        binds: [
          bind('/data/meta/entity/@create')..calculate("/data/join = 'yes'"),
          bind('/data/name')
            ..type('string')
            ..withSaveTo('name'),
          entityIdBind(),
          entityIdSetValue(),
          entityLabelBind('/data/name'),
        ],
        bodyChildren: [
          input('/data/name'),
          select1('/data/join', [item('yes', 'Yes'), item('no', 'No')]),
        ],
      ),
    );
    _addProcessor(scenario);

    scenario
      ..next()
      ..answerCurrent('Roman Roy')
      ..next()
      ..answerCurrent(scenario.choicesOf('/data/join')[0])
      ..finalizeInstance();
    expect(_entities(scenario), hasLength(1));

    scenario.newInstance();
    _addProcessor(scenario);
    scenario
      ..next()
      ..answerCurrent('Roman Roy')
      ..next()
      ..answerCurrent(scenario.choicesOf('/data/join')[1])
      ..finalizeInstance();
    expect(_entities(scenario), isEmpty);
  });

  test('entity form can be serialized', () async {
    final scenario = await _init(
      _simpleForm(
        entityNode('people', EntityAction.create),
        instanceChildren: [t('name')],
        binds: [
          bind('/data/name')
            ..type('string')
            ..withSaveTo('name'),
          entityIdBind(),
          entityIdSetValue(),
          entityLabelBind('/data/name'),
        ],
        bodyChildren: [input('/data/name')],
      ),
    );
    _addProcessor(scenario);
    final deserialized = await scenario.serializeAndDeserializeForm();
    _addProcessor(deserialized);

    deserialized
      ..next()
      ..answerCurrent('Shiv Roy')
      ..finalizeInstance();

    final entities = _entities(deserialized);
    expect(entities, hasLength(1));
    expect(entities[0].dataset, 'people');
    expect(entities[0].properties, [('name', 'Shiv Roy')]);
  });

  test('entities namespace works regardless of name', () async {
    final scenario = await _init(
      html(
        additionalNamespaces: {'blah': entitiesNamespace},
        head([
          title('Create entity form'),
          model(
            [
              mainInstance([
                t('data id="create-entity-form"', [
                  t('name'),
                  t('meta', [entityNode('people', EntityAction.create)]),
                ]),
              ]),
              bind('/data/name')
                ..type('string')
                ..withAttribute('blah', 'saveto', 'name'),
              entityIdBind(),
              entityIdSetValue(),
              entityLabelBind('/data/name'),
            ],
            attributes: {'blah:entities-version': '2024.1.0'},
          ),
        ]),
        body([input('/data/name')]),
      ),
    );
    _addProcessor(scenario);

    scenario
      ..answer('/data/name', 'Tom Wambsgans')
      ..finalizeInstance();

    final entities = _entities(scenario);
    expect(entities, hasLength(1));
    expect(entities[0].properties, [('name', 'Tom Wambsgans')]);
  });

  test('filling form with select saveto and with create saves values '
      'correctly to entity', () async {
    final scenario = await _init(
      _simpleForm(
        entityNode('people', EntityAction.create),
        instanceChildren: [t('team')],
        binds: [
          bind('/data/team')
            ..type('string')
            ..withSaveTo('team'),
          entityIdBind(),
          entityIdSetValue(),
          entityLabelBind('/data/team'),
        ],
        bodyChildren: [
          select1('/data/team', [
            item('kendall', 'Kendall'),
            item('logan', 'Logan'),
          ]),
        ],
      ),
    );
    _addProcessor(scenario);

    scenario
      ..next()
      ..answerCurrent(scenario.choicesOf('/data/team')[0])
      ..finalizeInstance();

    final entities = _entities(scenario);
    expect(entities, hasLength(1));
    expect(entities[0].properties, [('team', 'kendall')]);
  });

  test('when saveto question is not answered, entity property is empty '
      'string', () async {
    final scenario = await _init(
      _simpleForm(
        entityNode('people', EntityAction.create),
        instanceChildren: [t('name'), t('age')],
        binds: [
          bind('/data/name')..type('string'),
          bind('/data/age')..withSaveTo('age'),
          entityIdBind(),
          entityIdSetValue(),
          entityLabelBind('/data/name'),
        ],
        bodyChildren: [input('/data/name')],
      ),
    );
    _addProcessor(scenario);
    scenario
      ..answer('/data/name', 'James')
      ..finalizeInstance();

    final entities = _entities(scenario);
    expect(entities, hasLength(1));
    expect(entities[0].properties, [('age', '')]);
  });

  test('saveto is removed from bind attributes for clients', () async {
    final scenario = await _init(
      _simpleForm(
        t('entity dataset="people" create="1"'),
        instanceChildren: [t('name')],
        binds: [
          bind('/data/name')
            ..type('string')
            ..withSaveTo('name'),
        ],
        bodyChildren: [input('/data/name')],
      ),
    );

    scenario.next();
    final bindAttributes = scenario.formEntryPromptAtIndex.bindAttributes;
    expect(bindAttributes.any((it) => it.name == 'saveto'), isFalse);
  });
}
