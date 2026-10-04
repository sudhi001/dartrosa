import '../javarosa/parse/entity_schema.dart';
import 'entities_repository.dart';
import 'entity.dart';
import 'entity_list.dart';
import 'query.dart';
import 'query_exception.dart';

/// An [EntitiesRepository] that keeps everything in memory (for tests,
/// or apps that persist entities some other way).
///
/// Port of `org.odk.collect.entities.storage.InMemEntitiesRepository`,
/// including its behaviour: entities are re-added at the end of their list
/// when saved again (so indexes change), and list properties are matched
/// ignoring case.
final class InMemEntitiesRepository implements EntitiesRepository {
  /// Creates an empty repository; [clock] gives `lastUpdated` times
  /// (milliseconds since the epoch; always `0` by default).
  InMemEntitiesRepository({int Function()? clock}) : _clock = clock ?? _zero;

  static int _zero() => 0;

  final int Function() _clock;
  final List<EntityList> _lists = [];
  final Map<String, Set<String>> _listProperties = {};
  final Map<String, List<NewEntity>> _entities = {};

  @override
  List<EntityList> getLists() => List.unmodifiable(_lists);

  @override
  int getCount(String list) => query(list).length;

  @override
  void addList(String list) {
    if (!_lists.any((it) => it.name == list)) _lists.add(EntityList(list));
  }

  @override
  void delete(String list, String id) =>
      _entities[list]?.removeWhere((it) => it.id == id);

  @override
  List<SavedEntity> query(String list, [Query? query]) {
    final entities = [
      for (final (index, entity) in (_entities[list] ?? const []).indexed)
        SavedEntity(
          entity.id,
          entity.label,
          index: index,
          version: entity.version,
          properties: _buildProperties(list, entity),
          state: entity.state,
          trunkVersion: entity.trunkVersion,
          branchId: entity.branchId,
        ),
    ];

    return switch (query) {
      StringEqQuery(:final column, :final value) =>
        entities.where((it) => _fieldValue(it, column) == value).toList(),
      StringNotEqQuery(:final column, :final value) =>
        entities.where((it) => _fieldValue(it, column) != value).toList(),
      NumericEqQuery(:final column, :final value) =>
        entities
            .where((it) => _toDoubleOrNull(_fieldValue(it, column)) == value)
            .toList(),
      NumericNotEqQuery(:final column, :final value) =>
        entities
            .where((it) => _toDoubleOrNull(_fieldValue(it, column)) != value)
            .toList(),
      AndQuery(:final queryA, :final queryB) => () {
        final b = this.query(list, queryB).toSet();
        return {
          for (final it in this.query(list, queryA))
            if (b.contains(it)) it,
        }.toList();
      }(),
      OrQuery(:final queryA, :final queryB) => {
        ...this.query(list, queryA),
        ...this.query(list, queryB),
      }.toList(),
      null => entities,
    };
  }

  static String _fieldValue(Entity entity, String column) => switch (column) {
    EntitySchema.id => entity.id,
    EntitySchema.label => entity.label!,
    EntitySchema.version => '${entity.version}',
    _ =>
      entity.properties
              .where((it) => it.$1 == column)
              .map((it) => it.$2)
              .firstOrNull ??
          (throw QueryException('No such column: $column')),
  };

  /// Kotlin's `String.toDoubleOrNull()` (close enough: Dart's parser also
  /// accepts `NaN` and `Infinity`, but not Java's `d`/`f` suffixes).
  static double? _toDoubleOrNull(String value) => double.tryParse(value);

  @override
  SavedEntity? getByIndex(String list, int index) =>
      query(list).where((it) => it.index == index).firstOrNull;

  @override
  void updateList(String list, String hash, {required bool needsApproval}) {
    final existing = getList(list);
    if (existing != null) {
      final update = existing.copyWith(
        hash: hash,
        needsApproval: needsApproval,
        lastUpdated: _clock(),
      );
      _lists
        ..remove(existing)
        ..add(update);
    } else {
      _lists.add(
        EntityList(
          list,
          hash: hash,
          needsApproval: needsApproval,
          lastUpdated: _clock(),
        ),
      );
    }
  }

  @override
  EntityList? getList(String list) =>
      _lists.where((it) => it.name == list).firstOrNull;

  @override
  void cleanUpProperties(String list, Set<String> properties) {
    final listProperties = _listProperties[list];
    if (listProperties != null) {
      final lowerCase = {for (final p in properties) p.toLowerCase()};
      listProperties.removeWhere(
        (property) => !lowerCase.contains(property.toLowerCase()),
      );
    }
  }

  @override
  void save(String list, List<Entity> entities) {
    final entityList = _entities.putIfAbsent(list, () => []);

    for (final entity in entities) {
      _updateLists(list, entity);
      final existing = entityList.where((it) => it.id == entity.id).firstOrNull;

      if (existing != null) {
        final state = switch (existing.state) {
          EntityState.offline => entity.state,
          EntityState.online => EntityState.online,
        };

        entityList
          ..remove(existing)
          ..add(
            NewEntity(
              entity.id,
              entity.label ?? existing.label,
              version: entity.version,
              properties: _mergeProperties(existing, entity),
              state: state,
              trunkVersion: entity.trunkVersion,
              branchId: entity.branchId,
            ),
          );
      } else {
        entityList.add(
          NewEntity(
            entity.id,
            entity.label,
            version: entity.version,
            properties: entity.properties,
            state: entity.state,
            trunkVersion: entity.trunkVersion,
            branchId: entity.branchId,
          ),
        );
      }
    }
  }

  void _updateLists(String list, Entity entity) {
    addList(list);

    final properties = _listProperties.putIfAbsent(list, () => <String>{});
    final seen = <String>{};
    for (final (name, _) in entity.properties) {
      // distinctBy { it.lowercase() }, then only names not already in the
      // list (ignoring case).
      if (!seen.add(name.toLowerCase())) continue;
      final lower = name.toLowerCase();
      if (!properties.any((it) => it.toLowerCase() == lower)) {
        properties.add(name);
      }
    }
  }

  static List<EntityProperty> _mergeProperties(Entity existing, Entity entity) {
    final merged = <String, String>{
      for (final (name, value) in existing.properties) name: value,
    };
    for (final (name, value) in entity.properties) {
      merged[name] = value;
    }
    return [for (final MapEntry(:key, :value) in merged.entries) (key, value)];
  }

  List<EntityProperty> _buildProperties(String list, NewEntity entity) => [
    for (final property in _listProperties[list] ?? const <String>{})
      (
        property,
        entity.properties
                .where((it) => it.$1 == property)
                .map((it) => it.$2)
                .firstOrNull ??
            '',
      ),
  ];
}
