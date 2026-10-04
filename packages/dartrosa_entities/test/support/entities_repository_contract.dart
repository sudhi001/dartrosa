// Port of org.odk.collect.android.entities.EntitiesRepositoryTest (an
// abstract contract test every EntitiesRepository implementation should
// pass) and support/EntitySameAsMatcher.
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

/// Matches an [Entity] that is [Entity.sameAs] [expected].
Matcher sameEntityAs(Entity expected) => predicate<Entity?>(
  (item) => item != null && expected.sameAs(item),
  'is the same as $expected',
);

/// Defines the repository contract tests for [buildSubject].
void entitiesRepositoryContract(
  EntitiesRepository Function({int Function()? clock}) buildSubject,
) {
  test('#getLists returns lists for saved entities', () {
    final repository = buildSubject(clock: () => 123);

    repository
      ..save('wines', [NewEntity('1', 'Léoville Barton 2008')])
      ..save('whiskys', [NewEntity('2', 'Lagavulin 16')])
      ..updateList('wines', 'blah', needsApproval: true);

    expect(
      repository.getLists(),
      unorderedEquals([
        const EntityList(
          'wines',
          hash: 'blah',
          needsApproval: true,
          lastUpdated: 123,
        ),
        const EntityList('whiskys'),
      ]),
    );
  });

  test('#save updates existing entity with matching id', () {
    final repository = buildSubject();

    final wine = NewEntity('1', 'Léoville Barton 2008', trunkVersion: 1);
    repository.save('wines', [wine]);

    final updatedWine = wine.copyWith(
      label: 'Léoville Barton 2009',
      version: 2,
    );
    repository.save('wines', [updatedWine]);

    expect(repository.query('wines'), [sameEntityAs(updatedWine)]);
  });

  test('#save creates entity with matching id in different list', () {
    final repository = buildSubject();

    final wine = NewEntity('1', 'Léoville Barton 2008');
    repository.save('wines', [wine]);

    final updatedWine = NewEntity(wine.id, 'Edradour 10', version: 2);
    repository.save('whisky', [updatedWine]);

    expect(repository.query('wines'), [sameEntityAs(wine)]);
    expect(repository.query('whisky'), [sameEntityAs(updatedWine)]);
  });

  test('#save updates existing entity with matching id and version', () {
    final repository = buildSubject();

    final wine = NewEntity('1', 'Léoville Barton 2008');
    repository.save('wines', [wine]);

    final updatedWine = wine.copyWith(label: 'Léoville Barton 2009');
    repository.save('wines', [updatedWine]);

    expect(repository.query('wines'), [sameEntityAs(updatedWine)]);
  });

  test('#save updates state on existing entity when it is offline', () {
    final repository = buildSubject();

    final wine = NewEntity('1', 'Léoville Barton 2008');
    repository.save('wines', [wine]);

    final updatedWine = wine.copyWith(state: EntityState.online);
    repository.save('wines', [updatedWine]);

    expect(repository.query('wines'), [sameEntityAs(updatedWine)]);
  });

  test('#save does not update state on existing entity when it is online', () {
    final repository = buildSubject();

    final wine = NewEntity(
      '1',
      'Léoville Barton 2008',
      state: EntityState.online,
    );
    repository
      ..save('wines', [wine])
      ..save('wines', [wine.copyWith(state: EntityState.offline)]);

    expect(repository.query('wines'), [sameEntityAs(wine)]);
  });

  for (final list in ['wines', 'favourite-wines']) {
    test(
      '#save adds new properties${list == 'wines' ? '' : ' for lists '
                'with dashes'}',
      () {
        final repository = buildSubject();

        final wine = NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('window', '2019-2038')],
        );
        repository
          ..save(list, [wine])
          ..save(list, [
            NewEntity(
              wine.id,
              'Léoville Barton 2008',
              properties: const [('score', '92')],
              version: 2,
            ),
          ]);

        final wines = repository.query(list);
        expect(wines, hasLength(1));
        expect(wines[0].properties, [('window', '2019-2038'), ('score', '92')]);
      },
    );
  }

  test('#save adds new properties to existing entities', () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('window', '2019-2038')],
        ),
      ])
      ..save('wines', [
        NewEntity(
          '2',
          'Léoville Barton 2009',
          properties: const [('score', '92')],
          version: 2,
        ),
      ]);

    final wines = repository.query('wines');
    expect(wines, hasLength(2));
    expect(wines[0].properties, [('window', '2019-2038'), ('score', '')]);
    expect(wines[1].properties, [('window', ''), ('score', '92')]);
  });

  test('#save updates existing properties', () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('window', '2019-2038')],
        ),
      ])
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('window', '2019-2042')],
          version: 2,
        ),
      ]);

    final wines = repository.query('wines');
    expect(wines, hasLength(1));
    expect(wines[0].properties, [('window', '2019-2042')]);
  });

  test('#save does not update existing label if new one is null', () {
    final wine = NewEntity(
      '1',
      'Léoville Barton 2008',
      properties: const [('window', '2019-2038')],
    );
    final updatedWine = NewEntity(
      wine.id,
      null,
      properties: const [('window', '2019-2042')],
      version: 2,
    );
    final repository = buildSubject()
      ..save('wines', [wine])
      ..save('wines', [updatedWine]);

    final wines = repository.query('wines');
    expect(wines, hasLength(1));
    expect(wines[0].label, wine.label);
    expect(wines[0].properties, updatedWine.properties);
  });

  test('#save does not clear empty entity lists', () {
    final repository = buildSubject()
      ..addList('wines')
      ..addList('blah');
    expect(repository.getListNames(), unorderedEquals(['wines', 'blah']));

    repository.save('wines', [NewEntity('blah', 'Blah')]);
    expect(repository.getListNames(), unorderedEquals(['wines', 'blah']));
  });

  test('#save supports properties with dots and dashes when saving new '
      'entities and updating existing ones', () {
    final repository = buildSubject();
    final entity = NewEntity(
      '1',
      'One',
      properties: const [('a.property', 'value'), ('a-property', 'value')],
    );

    repository.save('things', [entity]);
    final savedEntity = repository.query('things')[0];
    expect(savedEntity, sameEntityAs(entity));

    repository.save('things', [savedEntity]);
    expect(repository.query('things')[0], sameEntityAs(savedEntity));
  });

  test('#save does not create a list when no entities are provided', () {
    final repository = buildSubject()..save('blah', []);
    expect(repository.getLists(), isEmpty);
  });

  test('#save supports creating list names with with dots and dashes', () {
    final repository = buildSubject();
    final wine = NewEntity('1', 'Léoville Barton 2008');

    repository.save('favourite-wines', [wine]);
    expect(repository.query('favourite-wines')[0], sameEntityAs(wine));

    repository.save('favourite.wines', [wine]);
    expect(repository.query('favourite.wines')[0], sameEntityAs(wine));
  });

  test('#save can save multiple entities', () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity('1', 'Léoville Barton 2008'),
        NewEntity('2', 'Chateau Pontet Canet'),
      ]);
    expect(repository.query('wines'), hasLength(2));
  });

  test('#save assigns an index to each entity in insert order when saving '
      'multiple entities', () {
    // first and second have alphabetically out of order IDs/names here so
    // that any indexing on them is tested.
    final first = NewEntity('2', 'B');
    final second = NewEntity('1', 'A');

    final repository = buildSubject()..save('wines', [first, second]);

    final entities = repository.query('wines');
    expect(entities[0].index, 0);
    expect(entities[0].id, first.id);
    expect(entities[1].index, 1);
    expect(entities[1].id, second.id);
  });

  test('#save assigns an index to each entity in insert order when saving '
      'single entities', () {
    final repository = buildSubject()
      ..save('wines', [NewEntity('1', 'Léoville Barton 2008')])
      ..save('wines', [NewEntity('2', 'Pontet Canet 2014')]);

    final entities = repository.query('wines');
    expect(entities[0].index, 0);
    expect(entities[1].index, 1);
  });

  test('#save does not change index when updating an existing entity', () {
    final first = NewEntity('1', 'Léoville Barton 2008');
    final repository = buildSubject()
      ..save('wines', [first, NewEntity('2', 'Pontet Canet 2014')]);
    expect(repository.query('wines')[0].index, 0);

    repository.save('wines', [first.copyWith(label: 'Léoville Barton 2009')]);
    expect(repository.query('wines')[0].index, 0);
  });

  test('#addList adds a list with no entities', () {
    final repository = buildSubject()..addList('wine');
    expect(repository.getListNames(), ['wine']);
    expect(repository.query('wine'), isEmpty);
  });

  test('#addList works if list already exists', () {
    final repository = buildSubject()
      ..addList('wine')
      ..addList('wine');
    expect(repository.getListNames(), ['wine']);
    expect(repository.query('wine'), isEmpty);
  });

  test('#delete removes an entity', () {
    final canet = NewEntity('2', 'Pontet-Canet 2014');
    final repository = buildSubject()
      ..save('wines', [NewEntity('1', 'Léoville Barton 2008'), canet])
      ..delete('wines', '1');

    expect(repository.query('wines'), [sameEntityAs(canet)]);
  });

  test('#delete supports list names with dots and dashes', () {
    final leoville = NewEntity('1', 'Léoville Barton 2008');
    final repository = buildSubject()
      ..save('wines.x', [leoville])
      ..save('wines-x', [leoville])
      ..delete('wines.x', '1')
      ..delete('wines-x', '1');

    expect(repository.query('wines.x'), isEmpty);
    expect(repository.query('wines-x'), isEmpty);
  });

  test('#delete updates index values so that they are always in sequence '
      'and start at 0', () {
    final leoville = NewEntity('1', 'Léoville Barton 2008');
    final repository = buildSubject()
      ..save('wines', [
        leoville,
        NewEntity('2', 'Pontet-Canet 2014'),
        NewEntity('3', 'Chateau Gloria 2016'),
      ])
      ..delete('wines', '1');
    var wines = repository.query('wines');
    expect(wines[0].index, 0);
    expect(wines[1].index, 1);

    repository.save('wines', [leoville]);
    wines = repository.query('wines');
    expect([for (final w in wines) w.index], [0, 1, 2]);
  });

  test('#getCount returns 0 when a list is empty', () {
    expect((buildSubject()..addList('wines')).getCount('wines'), 0);
  });

  test('#getCount returns 0 when a list does not exist', () {
    expect(buildSubject().getCount('wines'), 0);
  });

  for (final (wines, whiskys) in [
    ('wines', 'whiskys'),
    ('favourite-wines', 'favourite.whiskys'),
  ]) {
    test('#getCount returns number of entities in list ($wines)', () {
      final repository = buildSubject()
        ..save(wines, [
          NewEntity('1', 'Léoville Barton 2008'),
          NewEntity('2', "Dow's 1983"),
        ])
        ..save(whiskys, [NewEntity('1', 'Springbank 10')]);

      expect(repository.getCount(wines), 2);
      expect(repository.getCount(whiskys), 1);
    });
  }

  test('#getByIndex returns matching entity', () {
    final aultmore = NewEntity('2', 'Aultmore 12');
    final repository = buildSubject()
      ..save('whiskys', [NewEntity('1', 'Springbank 10'), aultmore]);

    final aultmoreIndex = repository
        .query('whiskys')
        .firstWhere((it) => it.id == aultmore.id)
        .index;
    expect(
      repository.getByIndex('whiskys', aultmoreIndex),
      sameEntityAs(aultmore),
    );
  });

  test('#getByIndex returns null when the list does not exist', () {
    expect(buildSubject().getByIndex('wine', 0), isNull);
  });

  test('#getByIndex returns null when the list is empty', () {
    expect((buildSubject()..addList('wine')).getByIndex('wine', 0), isNull);
  });

  test('#getByIndex supports list names with dots and dashes', () {
    final leoville = NewEntity('1', 'Léoville Barton 2008');
    final canet = NewEntity('2', 'Pontet-Canet 2014');
    final repository = buildSubject()
      ..save('favourite-wines', [leoville])
      ..save('other.favourite.wines', [canet]);

    for (final (list, entity) in [
      ('favourite-wines', leoville),
      ('other.favourite.wines', canet),
    ]) {
      final index = repository
          .query(list)
          .firstWhere((it) => it.id == entity.id)
          .index;
      expect(repository.getByIndex(list, index), sameEntityAs(entity));
    }
  });

  test('#getList returns list', () {
    final repository = buildSubject()
      ..addList('wine')
      ..updateList('wine', '2024', needsApproval: true);
    expect(
      repository.getList('wine'),
      const EntityList(
        'wine',
        hash: '2024',
        needsApproval: true,
        lastUpdated: 0,
      ),
    );
  });

  test("#getList returns list with null hash if list doesn't have hash", () {
    expect(
      (buildSubject()..addList('wine')).getList('wine'),
      const EntityList('wine'),
    );
  });

  test("#getList returns null if list doesn't exist", () {
    expect(buildSubject().getList('wine'), isNull);
  });

  test('#save ignores case-insensitive duplicate new properties', () {
    final repository = buildSubject()
      ..save('things', [
        NewEntity(
          '1',
          'One',
          properties: const [('prop', 'value'), ('Prop', 'value')],
        ),
      ]);
    final savedEntities = repository.query('things');
    expect(savedEntities[0].properties, hasLength(1));
    expect(savedEntities[0].properties[0].$1, 'prop');
  });

  test('#save ignores case-insensitive duplicate properties if one of them '
      'has already been saved', () {
    final entity = NewEntity('1', 'One', properties: const [('prop', 'value')]);
    final repository = buildSubject()..save('things', [entity]);
    var savedEntities = repository.query('things');
    expect(savedEntities[0].properties, hasLength(1));
    expect(savedEntities[0].properties[0].$1, 'prop');

    repository.save('things', [
      entity.copyWith(properties: const [('Prop', 'value')]),
    ]);
    savedEntities = repository.query('things');
    expect(savedEntities[0].properties, hasLength(1));
    expect(savedEntities[0].properties[0].$1, 'prop');
  });

  test('#query returns matching entities', () {
    final canet = NewEntity(
      '2',
      'Pontet-Canet 2014',
      version: 2,
      properties: const [('vintage', '2009')],
    );
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('vintage', '2008')],
        ),
        canet,
      ]);

    expect(repository.query('wines', const StringEqQuery('name', '2')), [
      sameEntityAs(canet),
    ]);
  });

  test('#query returns empty list when there are no matches', () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('vintage', '2008')],
        ),
      ]);
    expect(
      repository.query('wines', const StringEqQuery('name', '3')),
      isEmpty,
    );
  });

  test('#query returns empty list when there is a match in a different '
      'list', () {
    final repository = buildSubject()
      ..save('wines', [NewEntity('1', 'Léoville Barton 2008')])
      ..save('whisky', [NewEntity('2', 'Ardbeg 10')]);

    expect(
      repository.query('wines', const StringEqQuery('label', 'Ardbeg 10')),
      isEmpty,
    );
  });

  test('#query returns empty list where there are no entities in the list', () {
    expect(
      buildSubject().query(
        'wines',
        const StringEqQuery('label', 'Léoville Barton 2008'),
      ),
      isEmpty,
    );
  });

  test('#query supports list names with dots and dashes', () {
    final leoville = NewEntity('1', 'Léoville Barton 2008');
    final canet = NewEntity('2', 'Pontet-Canet 2014');
    final repository = buildSubject()
      ..save('favourite-wines', [leoville])
      ..save('other.favourite.wines', [canet]);

    expect(
      repository.query(
        'favourite-wines',
        const StringEqQuery('label', 'Léoville Barton 2008'),
      ),
      [sameEntityAs(leoville)],
    );
    expect(
      repository.query(
        'other.favourite.wines',
        const StringEqQuery('label', 'Pontet-Canet 2014'),
      ),
      [sameEntityAs(canet)],
    );
  });

  test('#query throws an exception when not existing property is used', () {
    final repository = buildSubject()
      ..save('wines', [NewEntity('1', 'Léoville Barton 2008')]);

    expect(
      () => repository.query('wines', const StringEqQuery('score', '92')),
      throwsA(isA<QueryException>()),
    );
  });

  for (final (kind, five, other) in [
    ('integer', '5', '7'),
    ('decimal', '5.0', '7.5'),
  ]) {
    test('#query returns matching entities with numeric eq selection '
        'arguments for $kind values', () {
      final leoville = NewEntity(
        '1',
        'Léoville Barton 2008',
        properties: [('score', five)],
      );
      final dows = NewEntity('3', "Dow's 1983", properties: [('score', other)]);
      final repository = buildSubject()..save('wines', [leoville, dows]);

      expect(repository.query('wines', const NumericEqQuery('score', 5)), [
        sameEntityAs(leoville),
      ]);
    });

    test('#query returns matching entities with numeric not eq selection '
        'arguments for $kind values', () {
      final leoville = NewEntity(
        '1',
        'Léoville Barton 2008',
        properties: [('score', five)],
      );
      final dows = NewEntity('3', "Dow's 1983", properties: [('score', other)]);
      final repository = buildSubject()..save('wines', [leoville, dows]);

      expect(repository.query('wines', const NumericNotEqQuery('score', 5)), [
        sameEntityAs(dows),
      ]);
    });
  }

  test('#query without query returns empty list when there are not '
      'entities', () {
    expect(buildSubject().query('wines'), isEmpty);
  });

  test('#query without query returns entities for list', () {
    final wine = NewEntity(
      '1',
      'Léoville Barton 2008',
      version: 2,
      trunkVersion: 1,
    );
    final whisky = NewEntity('2', 'Lagavulin 16', version: 3, trunkVersion: 1);
    final repository = buildSubject()
      ..save('wines', [wine])
      ..save('whiskys', [whisky]);

    expect(repository.query('wines'), [sameEntityAs(wine)]);
    expect(repository.query('whiskys'), [sameEntityAs(whisky)]);
  });

  test('#query returns entities when searching for empty string for '
      "property that doesn't exist", () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('vintage', '2008')],
        ),
      ]);
    expect(
      repository.query('wines', const StringEqQuery('score', '')),
      hasLength(1),
    );
  }, skip: 'https://github.com/getodk/collect/issues/6615');

  test('#updateList creates list if doesn\'t exist', () {
    final repository = buildSubject()
      ..updateList('blah', 'abcd', needsApproval: false);
    expect(repository.getLists(), hasLength(1));
    expect(repository.query('blah'), isEmpty);
  });

  test('#cleanUpProperties removes list properties not in properties '
      'param', () {
    final repository = buildSubject()
      ..save('wines', [
        NewEntity(
          '1',
          'Léoville Barton 2008',
          properties: const [('vintage', '2008'), ('rating', '92')],
        ),
      ])
      ..cleanUpProperties('wines', {'rating'});
    expect(repository.query('wines')[0].propertyNames, ['rating']);
  });

  test("#cleanUpProperties does nothing if list doesn't exist", () {
    final repository = buildSubject()..cleanUpProperties('wines', {'rating'});
    expect(repository.getLists(), isEmpty);
  });
}
