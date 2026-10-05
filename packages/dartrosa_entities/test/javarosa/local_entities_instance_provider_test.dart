// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocalEntitiesInstanceProviderTest), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.entities.javarosa.LocalEntitiesInstanceProviderTest.
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

void main() {
  late InMemEntitiesRepository entitiesRepository;

  setUp(() => entitiesRepository = InMemEntitiesRepository());

  LocalEntitiesInstanceProvider provider([
    Iterable<String> attached = const [],
  ]) => LocalEntitiesInstanceProvider(
    () => entitiesRepository,
    InMemFormMediaFileRepository(attached),
  );

  test('includes properties in local entity elements', () {
    entitiesRepository.save('people', [
      NewEntity(
        '1',
        'Shiv Roy',
        properties: const [('age', '35'), ('born', 'England')],
      ),
    ]);

    final instance = provider().get('people', 'people.csv');
    expect(instance.numChildren, 1);

    final item = instance.childAt(0);
    expect(item.numChildren, 7);
    expect(item.firstChild('age')?.value?.value, '35');
    expect(item.firstChild('born')?.value?.value, 'England');
  });

  test('includes version in local entity elements', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);

    final instance = provider().get('people', 'people.csv');
    expect(instance.numChildren, 1);

    final item = instance.childAt(0);
    expect(item.numChildren, 5);
    expect(item.firstChild(EntitySchema.version)?.value?.value, '1');
  });

  test('includes trunk version in local entity elements', () {
    entitiesRepository.save('people', [
      NewEntity('1', 'Shiv Roy', trunkVersion: 1),
    ]);

    final item = provider().get('people', 'people.csv').childAt(0);
    expect(item.numChildren, 5);
    expect(item.firstChild(EntitySchema.trunkVersion)?.value?.value, '1');
  });

  test('includes branch id in local entity elements', () {
    entitiesRepository.save('people', [
      NewEntity('1', 'Shiv Roy', branchId: 'branch-1'),
    ]);

    final item = provider().get('people', 'people.csv').childAt(0);
    expect(item.numChildren, 5);
    expect(item.firstChild(EntitySchema.branchId)?.value?.value, 'branch-1');
  });

  test('includes blank trunk version when it is null', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);

    final item = provider().get('people', 'people.csv').childAt(0);
    expect(item.firstChild(EntitySchema.trunkVersion)?.value, isNull);
  });

  test('partial parse returns the full first item and just item for '
      'others', () {
    entitiesRepository.save('people', [
      NewEntity('1', 'Shiv Roy', properties: const [('age', '35')]),
      NewEntity('2', 'Kendall Roy', properties: const [('age', '40')]),
    ]);

    final instance = provider().get('people', 'people.csv', partial: true);
    expect(instance.numChildren, 2);

    final item1 = instance.childAt(0);
    expect(item1.isPartial, isFalse);
    expect(item1.numChildren, 6);
    expect(item1.firstChild('name')!.value!.value, '1');

    final item2 = instance.childAt(1);
    expect(item2.isPartial, isTrue);
    expect(item2.numChildren, 0);
  });

  test('uses entity index for multiplicity', () {
    final repository = InMemEntitiesRepository()
      ..save('people', [
        NewEntity('1', 'Shiv Roy'),
        NewEntity('2', 'Kendall Roy'),
      ]);

    final instance = LocalEntitiesInstanceProvider(
      () => repository,
      InMemFormMediaFileRepository(),
    ).get('people', 'people.csv');

    final first = instance.childAt(0);
    expect(first.firstChild('name')!.value!.value, '1');
    expect(first.multiplicity, 0);

    final second = instance.childAt(1);
    expect(second.firstChild('name')!.value!.value, '2');
    expect(second.multiplicity, 1);
  });

  test('isSupported returns true for an existing entity list when no media '
      'file is attached', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);
    expect(
      provider().isSupported('people', 'jr://file-csv/people.csv'),
      isTrue,
    );
  });

  test('isSupported returns false when a media file with the same name is '
      'attached', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);
    expect(
      provider([
        'jr://file-csv/people.csv',
      ]).isSupported('people', 'jr://file-csv/people.csv'),
      isFalse,
    );
  });

  test('isSupported returns true when the resolved media file does not '
      'exist', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);
    expect(
      provider([
        'jr://file-csv/missing.csv',
      ]).isSupported('people', 'jr://file-csv/people.csv'),
      isTrue,
    );
  });

  test('isSupported returns false for a list that does not exist', () {
    expect(
      provider().isSupported('people', 'jr://file-csv/people.csv'),
      isFalse,
    );
  });

  test('includes blank label version when it is null', () {
    entitiesRepository.save('people', [NewEntity('1', null)]);

    final instance = provider().get('people', 'people.csv');
    expect(instance.numChildren, 1);
    expect(instance.childAt(0).firstChild(EntitySchema.label)?.value, isNull);
  });

  test('the external instance parser factory adds the provider', () {
    entitiesRepository.save('people', [NewEntity('1', 'Shiv Roy')]);
    final parser = LocalEntitiesExternalInstanceParserFactory(
      () => entitiesRepository,
      InMemFormMediaFileRepository(),
    ).getExternalInstanceParser();
    expect(
      parser.providerFor('people', 'jr://file-csv/people.csv'),
      isA<LocalEntitiesInstanceProvider>(),
    );
  });
}
