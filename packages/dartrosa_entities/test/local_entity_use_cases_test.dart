// Port of org.odk.collect.entities.LocalEntityUseCasesTest.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

final class _MeasurableEntitiesRepository implements EntitiesRepository {
  _MeasurableEntitiesRepository(this._wrapped);

  final EntitiesRepository _wrapped;
  int accesses = 0;
  int savedEntities = 0;

  @override
  void save(String list, List<Entity> entities) {
    accesses += 1;
    savedEntities += entities.length;
    _wrapped.save(list, entities);
  }

  @override
  List<EntityList> getLists() {
    accesses += 1;
    return _wrapped.getLists();
  }

  @override
  int getCount(String list) => _wrapped.getCount(list);

  @override
  void addList(String list) {
    accesses += 1;
    _wrapped.addList(list);
  }

  @override
  void delete(String list, String id) {
    accesses += 1;
    _wrapped.delete(list, id);
  }

  @override
  List<SavedEntity> query(String list, [Query? query]) {
    accesses += 1;
    return _wrapped.query(list, query);
  }

  @override
  SavedEntity? getByIndex(String list, int index) {
    accesses += 1;
    return _wrapped.getByIndex(list, index);
  }

  @override
  void updateList(String list, String hash, {required bool needsApproval}) {
    accesses += 1;
    _wrapped.updateList(list, hash, needsApproval: false);
  }

  @override
  EntityList? getList(String list) {
    accesses += 1;
    return _wrapped.getList(list);
  }

  @override
  void cleanUpProperties(String list, Set<String> properties) {
    accesses += 1;
    _wrapped.cleanUpProperties(list, properties);
  }
}

final class _FakeEntitySource implements EntitySource {
  final String integrityUrl = 'http://example.com/${_uuid()}';
  int accesses = 0;
  final List<String> _deleted = [];

  @override
  Future<List<(String, bool)>> fetchDeletedStates(
    String integrityUrl,
    List<String> ids,
  ) async {
    accesses += 1;
    if (integrityUrl != this.integrityUrl) throw ArgumentError(integrityUrl);
    return [for (final id in ids) (id, _deleted.contains(id))];
  }

  void delete(String id) => _deleted.add(id);
}

final class _RecordingLogger implements DebugLogger<EntityEvent> {
  final List<EntityEvent> events = [];

  @override
  void log(EntityEvent event) => events.add(event);
}

var _uuidCounter = 0;

/// A distinct v4 UUID per call.
String _uuid() {
  final n = (_uuidCounter++).toRadixString(16).padLeft(12, '0');
  return '3d9c6b1e-5f1a-4b8e-9c2d-$n';
}

/// Collect's `FormFixtures.mediaFile()` (a new random hash by default).
MediaFile _mediaFile({String? hash, String? integrityUrl}) => MediaFile(
  'file',
  hash ?? _uuid(),
  'http://example.com/download',
  integrityUrl: integrityUrl,
);

/// Prints CSV like commons-csv `CSVFormat.DEFAULT`.
Uint8List _createCsv(
  List<String> header, [
  List<List<String?>> rows = const [],
]) {
  String field(String? value) {
    final v = value ?? '';
    return RegExp('[,"\r\n]').hasMatch(v) ||
            v.startsWith(' ') ||
            v.endsWith(' ')
        ? '"${v.replaceAll('"', '""')}"'
        : v;
  }

  final lines = [
    for (final record in [header, ...rows]) record.map(field).join(','),
  ];
  return Uint8List.fromList(utf8.encode('${lines.join('\r\n')}\r\n'));
}

Uint8List _createEntityList([List<Entity> entities = const []]) {
  final header = [
    EntitySchema.id,
    EntitySchema.label,
    EntitySchema.version,
    if (entities.isNotEmpty) ...entities[0].propertyNames,
  ];
  return _createCsv(header, [
    for (final entity in entities)
      [
        entity.id,
        entity.label,
        '${entity.version}',
        for (final (_, value) in entity.properties) value,
      ],
  ]);
}

void main() {
  late InMemEntitiesRepository entitiesRepository;
  late _FakeEntitySource entitySource;

  setUp(() {
    entitiesRepository = InMemEntitiesRepository();
    entitySource = _FakeEntitySource();
  });

  void fromForm(List<FormEntity> formEntities, [DebugLogger<EntityEvent>? l]) =>
      LocalEntityUseCases.updateLocalEntitiesFromForm(
        EntitiesExtra(formEntities),
        entitiesRepository,
        debugLogger: l,
      );

  void fromServer(
    Uint8List csv, {
    EntitiesRepository? repository,
    MediaFile? mediaFile,
  }) => LocalEntityUseCases.updateLocalEntitiesFromServer(
    'songs',
    csv,
    repository ?? entitiesRepository,
    mediaFile ?? _mediaFile(),
  );

  test('#updateLocalEntitiesFromForm saves a new entity on create', () {
    entitiesRepository.addList('things');

    final formEntity = FormEntity(
      EntityAction.create,
      'things',
      _uuid(),
      'label',
      const [('property', 'value')],
    );
    fromForm([formEntity]);

    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].id, formEntity.id);
    expect(entities[0].label, formEntity.label);
    expect(entities[0].properties, formEntity.properties);
    expect(entities[0].branchId, isNotEmpty);
  });

  test('#updateLocalEntitiesFromForm does not save a new entity on create if '
      'id is not a valid UUID', () {
    entitiesRepository.addList('things');
    fromForm([
      FormEntity(EntityAction.create, 'things', 'id', 'label', const [
        ('property', 'value'),
      ]),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  test('#updateLocalEntitiesFromForm does not save a new entity on create if '
      'label is blank', () {
    entitiesRepository.addList('things');
    fromForm([
      FormEntity(EntityAction.create, 'things', _uuid(), '', const [
        ('property', 'value'),
      ]),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  test('#updateLocalEntitiesFromForm does not save a new entity on create if '
      "the list doesn't already exist", () {
    fromForm([
      FormEntity(EntityAction.create, 'things', _uuid(), 'label', const [
        ('property', 'value'),
      ]),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  // Added: lists that need approval don't get local creates.
  test('#updateLocalEntitiesFromForm does not save a new entity on create if '
      'the list needs approval', () {
    entitiesRepository.updateList('things', 'hash', needsApproval: true);
    fromForm([
      FormEntity(EntityAction.create, 'things', _uuid(), 'label', const []),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  test('#updateLocalEntitiesFromForm does not update an entity if id in not '
      'a valid UUID', () {
    entitiesRepository.save('things', [NewEntity('id', 'label')]);
    fromForm([
      FormEntity(EntityAction.update, 'things', 'id', 'new_label', const []),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].label, 'label');
    expect(entities[0].version, 1);
  });

  test('#updateLocalEntitiesFromForm increments version on update', () {
    final id = _uuid();
    entitiesRepository.save('things', [NewEntity(id, 'label')]);
    fromForm([
      FormEntity(EntityAction.update, 'things', id, 'label', const []),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].version, 2);
  });

  test('#updateLocalEntitiesFromForm updates properties on update', () {
    final id = _uuid();
    entitiesRepository.save('things', [
      NewEntity(id, 'label', properties: const [('prop', 'value')]),
    ]);
    fromForm([
      FormEntity(EntityAction.update, 'things', id, 'label', const [
        ('prop', 'value 2'),
      ]),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].properties, [('prop', 'value 2')]);
  });

  test('#updateLocalEntitiesFromForm updates properties and does not change '
      'label on update if label is blank', () {
    final id = _uuid();
    entitiesRepository.save('things', [
      NewEntity(id, 'label', properties: const [('prop', 'value')]),
    ]);
    fromForm([
      FormEntity(EntityAction.update, 'things', id, ' ', const [
        ('prop', 'value 2'),
      ]),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].label, 'label');
    expect(entities[0].properties, [('prop', 'value 2')]);
  });

  test('#updateLocalEntitiesFromForm saves a new entity on upsert if it '
      "doesn't exist", () {
    entitiesRepository.addList('things');
    final formEntity = FormEntity(
      EntityAction.upsert,
      'things',
      _uuid(),
      'label',
      const [('property', 'value')],
    );
    fromForm([formEntity]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].id, formEntity.id);
    expect(entities[0].label, formEntity.label);
    expect(entities[0].properties, formEntity.properties);
    expect(entities[0].branchId, isNotEmpty);
  });

  test('#updateLocalEntitiesFromForm does not save a new entity on upsert if '
      'label is blank', () {
    entitiesRepository.addList('things');
    fromForm([
      FormEntity(EntityAction.upsert, 'things', _uuid(), '', const [
        ('property', 'value'),
      ]),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  test('#updateLocalEntitiesFromForm updates an existing entity on upsert if '
      'it exists', () {
    final id = _uuid();
    entitiesRepository.save('things', [NewEntity(id, 'label')]);
    fromForm([
      FormEntity(EntityAction.upsert, 'things', id, 'new label', const []),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].label, 'new label');
    expect(entities[0].version, 2);
  });

  test('#updateLocalEntitiesFromForm does not override trunk version or '
      'branchId on update', () {
    entitiesRepository.save('things', [
      NewEntity('id', 'label', trunkVersion: 1, branchId: 'branch-1'),
    ]);
    fromForm([
      FormEntity(EntityAction.update, 'things', _uuid(), 'label', const []),
    ]);
    final entities = entitiesRepository.query('things');
    expect(entities, hasLength(1));
    expect(entities[0].trunkVersion, 1);
    expect(entities[0].branchId, 'branch-1');
  });

  test('#updateLocalEntitiesFromForm does not save updated entity that '
      "doesn't already exist", () {
    entitiesRepository.addList('things');
    fromForm([
      FormEntity(EntityAction.update, 'things', _uuid(), '1', const []),
    ]);
    expect(entitiesRepository.query('things'), isEmpty);
  });

  test('#updateLocalEntitiesFromForm logs invalid entities', () {
    final logger = _RecordingLogger();
    final id = _uuid();
    final formEntity1 = FormEntity(
      EntityAction.create,
      'things',
      '',
      'label',
      const [],
    );
    final formEntity2 = FormEntity(
      EntityAction.create,
      'things',
      'id',
      'label',
      const [],
    );
    final formEntity3 = FormEntity(
      EntityAction.create,
      'things',
      id,
      '',
      const [],
    );
    final formEntity4 = FormEntity(
      EntityAction.update,
      'things',
      id,
      '',
      const [],
    );

    fromForm([formEntity1, formEntity2, formEntity3, formEntity4], logger);

    expect(
      logger.events,
      unorderedEquals([
        NoId(formEntity1),
        InvalidId(formEntity2),
        CreateNoLabel(formEntity3),
        UpdateNoMatch(formEntity4),
      ]),
    );
  });

  test('#updateLocalEntitiesFromServer saves entity from server', () {
    fromServer(
      _createEntityList([
        NewEntity(
          'noah',
          'Noah',
          version: 2,
          properties: const [('property', 'value')],
        ),
      ]),
    );
    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].label, 'Noah');
    expect(songs[0].version, 2);
    expect(songs[0].properties, [('property', 'value')]);
    expect(songs[0].state, EntityState.online);
    expect(songs[0].trunkVersion, 2);
    expect(songs[0].branchId, isNotEmpty);
  });

  for (final trunkVersion in [1, null]) {
    test('#updateLocalEntitiesFromServer overrides offline version if the '
        'online version is newer${trunkVersion == null ? ' and the offline '
                  'version is dirty' : ''}', () {
      final offline = NewEntity('noah', 'Noa', trunkVersion: trunkVersion);
      entitiesRepository.save('songs', [offline]);
      fromServer(_createEntityList([NewEntity('noah', 'Noah', version: 2)]));

      final songs = entitiesRepository.query('songs');
      expect(songs, hasLength(1));
      expect(songs[0].label, 'Noah');
      expect(songs[0].version, 2);
      expect(songs[0].state, EntityState.online);
      expect(songs[0].trunkVersion, 2);
      expect(songs[0].branchId, isNotEmpty);
      expect(songs[0].branchId, isNot(offline.branchId));
    });
  }

  test('#updateLocalEntitiesFromServer updates state if the online version '
      'is older', () {
    final offline = NewEntity('noah', 'Noah', version: 2);
    entitiesRepository.save('songs', [offline]);
    fromServer(_createEntityList([NewEntity('noah', 'Noa')]));

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].label, 'Noah');
    expect(songs[0].version, 2);
    expect(songs[0].state, EntityState.online);
    expect(songs[0].trunkVersion, isNull);
    expect(songs[0].branchId, offline.branchId);
  });

  test('#updateLocalEntitiesFromServer does not write to repository if '
      'online and local are exactly the same', () {
    final repository = _MeasurableEntitiesRepository(entitiesRepository);

    final local = NewEntity(
      'noah',
      'Noah',
      version: 2,
      properties: const [('length', '4:33')],
    );
    fromServer(_createEntityList([local]), repository: repository);
    expect(repository.savedEntities, 1);

    fromServer(
      _createEntityList([local, NewEntity('perception', 'Perception')]),
      repository: repository,
    );
    expect(repository.savedEntities, 2);
  });

  test('#updateLocalEntitiesFromServer updates trunkVersion, branchId and '
      'state if the online version catches up to an offline branch', () {
    entitiesRepository.save('songs', [NewEntity('noah', 'Noah', version: 2)]);
    fromServer(_createEntityList([NewEntity('noah', 'Noah', version: 2)]));

    final onlineBranched = NewEntity('noah', 'Noah', version: 3);
    entitiesRepository.save('songs', [onlineBranched]);
    fromServer(_createEntityList([NewEntity('noah', 'Noah', version: 3)]));

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].version, 3);
    expect(songs[0].state, EntityState.online);
    expect(songs[0].trunkVersion, 3);
    expect(songs[0].branchId, isNotEmpty);
    expect(songs[0].branchId, isNot(onlineBranched.branchId));
  });

  test('#updateLocalEntitiesFromServer overrides offline version if the '
      'online version is the same', () {
    final offline = NewEntity('noah', 'Noah', version: 2);
    entitiesRepository.save('songs', [offline]);
    fromServer(
      _createEntityList([
        NewEntity(
          'noah',
          'Noa',
          version: 2,
          properties: const [('length', '4:33')],
        ),
      ]),
    );

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].label, 'Noa');
    expect(songs[0].properties, [('length', '4:33')]);
    expect(songs[0].version, 2);
    expect(songs[0].state, EntityState.online);
    expect(songs[0].trunkVersion, 2);
    expect(songs[0].branchId, isNotEmpty);
    expect(songs[0].branchId, isNot(offline.branchId));
  });

  test('#updateLocalEntitiesFromServer ignores properties not in offline '
      'version from older online version', () {
    entitiesRepository.save('songs', [NewEntity('noah', 'Noah', version: 3)]);
    fromServer(
      _createEntityList([
        NewEntity(
          'noah',
          'Noah',
          version: 2,
          properties: const [('length', '6:38')],
        ),
      ]),
    );
    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].properties, isEmpty);
  });

  test('#updateLocalEntitiesFromServer overrides properties in offline '
      'version from newer list version', () {
    entitiesRepository.save('songs', [
      NewEntity('noah', 'Noah', properties: const [('length', '6:38')]),
    ]);
    fromServer(
      _createEntityList([
        NewEntity(
          'noah',
          'Noah',
          version: 2,
          properties: const [('length', '4:58')],
        ),
      ]),
    );
    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].version, 2);
    expect(songs[0].properties, [('length', '4:58')]);
  });

  for (final (missing, header, row) in [
    ('version', ['name', 'label'], ['grisaille', 'Grisaille']),
    ('name', ['label', '__version'], ['Grisaille', '2']),
    ('label', ['name', '__version'], ['grisaille', '2']),
  ]) {
    test('#updateLocalEntitiesFromServer does nothing if $missing does not '
        'exist in online entities', () {
      fromServer(_createCsv(header, [row]));
      expect(entitiesRepository.getLists(), isEmpty);
    });
  }

  test('#updateLocalEntitiesFromServer adds online entity when its label is '
      'blank', () {
    fromServer(_createEntityList([NewEntity('cathedrals', '')]));
    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].label, '');
  });

  test('#updateLocalEntitiesFromServer does nothing if passed a non-CSV '
      'file', () {
    // Collect passes an empty temp file.
    fromServer(Uint8List(0));
    expect(entitiesRepository.getLists(), isEmpty);
  });

  test('#updateLocalEntitiesFromServer does nothing if the list hash has not '
      'changed', () {
    entitiesRepository.updateList('songs', 'hash', needsApproval: false);
    fromServer(
      _createEntityList([NewEntity('noah', 'Noah')]),
      mediaFile: _mediaFile(hash: 'hash'),
    );
    expect(entitiesRepository.query('songs'), isEmpty);
  });

  test('#updateLocalEntitiesFromServer does not remove offline entities that '
      'are not in online entities', () {
    entitiesRepository.save('songs', [NewEntity('noah', 'Noah')]);
    fromServer(_createEntityList([NewEntity('cathedrals', 'Cathedrals')]));
    expect(entitiesRepository.query('songs'), hasLength(2));
  });

  test('#updateLocalEntitiesFromServer does not check for deletions with the '
      'entity source if it does not need to', () {
    fromServer(
      _createEntityList(),
      mediaFile: _mediaFile(integrityUrl: entitySource.integrityUrl),
    );
    expect(entitySource.accesses, 0);
  });

  test('#updateLocalEntitiesFromServer removes offline entity that was in '
      "online list, but isn't any longer", () {
    entitiesRepository.save('songs', [NewEntity('cathedrals', 'Cathedrals')]);
    fromServer(_createEntityList([NewEntity('cathedrals', 'Cathedrals')]));
    fromServer(
      _createEntityList([NewEntity('noah', 'Noah')]),
      mediaFile: _mediaFile(hash: 'hash2'),
    );

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].id, 'noah');
  });

  test('#updateLocalEntitiesFromServer removes offline entity that was '
      "updated in online list, but isn't any longer", () {
    entitiesRepository.save('songs', [NewEntity('cathedrals', 'Cathedrals')]);
    fromServer(
      _createEntityList([
        NewEntity('cathedrals', 'Cathedrals (A Song)', version: 2),
      ]),
    );
    fromServer(_createEntityList(), mediaFile: _mediaFile(hash: 'hash2'));

    expect(entitiesRepository.query('songs'), isEmpty);
  });

  test('#updateLocalEntitiesFromServer updates the list hash', () {
    fromServer(
      _createEntityList([NewEntity('cathedrals', 'Cathedrals')]),
      mediaFile: _mediaFile(hash: 'hash'),
    );
    expect(entitiesRepository.getList('songs')?.hash, 'hash');
  });

  test('#updateLocalEntitiesFromServer records whether the list needs '
      'approval', () {
    fromServer(
      _createEntityList([NewEntity('cathedrals', 'Cathedrals')]),
      mediaFile: const MediaFile(
        'file',
        'hash',
        'url',
        type: MediaFileType.approvalEntityList,
      ),
    );
    expect(entitiesRepository.getList('songs')?.needsApproval, isTrue);
  });

  test('#updateLocalEntitiesFromServer removes properties that no longer '
      'appear in the entity source', () {
    entitiesRepository.save('songs', [
      NewEntity('noah', 'Noah', properties: const [('length', '6:38')]),
    ]);
    fromServer(_createEntityList([NewEntity('noah', 'Noah', version: 2)]));

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].properties, isEmpty);
  });

  test('#updateLocalEntitiesFromServer removes properties that no longer '
      'appear in the entity source when no entities are updated', () {
    final entity = NewEntity(
      'noah',
      'Noah',
      properties: const [('length', '6:38')],
    );
    fromServer(
      _createEntityList([entity]),
      mediaFile: _mediaFile(hash: 'hash1'),
    );
    fromServer(
      _createEntityList([entity.copyWith(properties: const [])]),
      mediaFile: _mediaFile(hash: 'hash2'),
    );

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(1));
    expect(songs[0].properties, isEmpty);
  });

  test('#updateLocalEntitiesFromServer uses semicolons when the header has '
      'one', () {
    fromServer(
      Uint8List.fromList(utf8.encode('name;label;__version\nnoah;Noah;1\n')),
    );
    expect(entitiesRepository.query('songs').single.label, 'Noah');
  });

  test('#updateOfflineLocalEntitiesFromServer removes offline entities that '
      'are deleted according to the entity source', () async {
    entitiesRepository
      ..save('songs', [NewEntity('cathedrals', 'Cathedrals')])
      ..save('songs', [NewEntity('noah', 'Noah', state: EntityState.online)])
      ..save('songs', [NewEntity('midnightCity', 'Midnight City')]);

    entitySource.delete('cathedrals');

    await LocalEntityUseCases.cleanUpDeletedOfflineEntities(
      'songs',
      entitiesRepository,
      entitySource,
      _mediaFile(integrityUrl: entitySource.integrityUrl),
    );

    final songs = entitiesRepository.query('songs');
    expect(songs, hasLength(2));
    expect(songs[0].label, 'Noah');
    expect(songs[1].label, 'Midnight City');
  });
}
