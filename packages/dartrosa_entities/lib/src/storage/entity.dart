import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Whether an entity is known to the server.
///
/// Port of `Entity.State`.
enum EntityState {
  /// Created or changed on this device only.
  offline,

  /// Seen in a list downloaded from the server.
  online,
}

/// An entity property: a (name, value) pair, as Kotlin's
/// `Pair<String, String>`.
typedef EntityProperty = (String, String);

const _propertiesEquality = ListEquality<EntityProperty>();

/// An entity of an entity list.
///
/// Port of `org.odk.collect.entities.storage.Entity` (a sealed interface
/// with `New` and `Saved` data classes): [NewEntity] is one to save,
/// [SavedEntity] one read back from an [EntitiesRepository] (with its
/// [SavedEntity.index] in the list).
@immutable
sealed class Entity {
  const Entity({
    required this.id,
    required this.label,
    required this.version,
    required this.properties,
    required this.state,
    required this.trunkVersion,
    required this.branchId,
  });

  /// The entity id (the `name` column); a UUID for entities created by
  /// forms.
  final String id;

  /// The label, if any.
  final String? label;

  /// The local version, incremented whenever the entity changes locally.
  final int version;

  /// The properties, in order.
  final List<EntityProperty> properties;

  /// Whether the server knows about this entity.
  final EntityState state;

  /// The server version (from an entity list CSV) this is based on. This
  /// should only be updated when updating an entity from the server where
  /// as [version] should be incremented whenever there is a local change.
  final int? trunkVersion;

  /// The offline "branch" identifier. Should be updated whenever the local
  /// version is modified from the latest server version.
  final String branchId;

  /// Whether the entity changed locally since it was last updated from the
  /// server.
  bool isDirty() => version != trunkVersion;

  /// The property names, in order. Port of `Entity.propertyNames()`.
  List<String> get propertyNames => [for (final (name, _) in properties) name];

  /// Whether this and [entity] have the same content, ignoring whether
  /// they are new or saved (and the saved index).
  bool sameAs(Entity entity) => _toNew(this) == _toNew(entity);

  static NewEntity _toNew(Entity entity) => NewEntity(
    entity.id,
    entity.label,
    version: entity.version,
    properties: entity.properties,
    state: entity.state,
    trunkVersion: entity.trunkVersion,
    branchId: entity.branchId,
  );

  bool _fieldsEqual(Entity other) =>
      other.id == id &&
      other.label == label &&
      other.version == version &&
      _propertiesEquality.equals(other.properties, properties) &&
      other.state == state &&
      other.trunkVersion == trunkVersion &&
      other.branchId == branchId;

  int get _fieldsHash => Object.hash(
    id,
    label,
    version,
    _propertiesEquality.hash(properties),
    state,
    trunkVersion,
    branchId,
  );
}

/// An entity to save. Port of `Entity.New`.
final class NewEntity extends Entity {
  /// Creates an entity.
  NewEntity(
    String id,
    String? label, {
    super.version = 1,
    List<EntityProperty> properties = const [],
    super.state = EntityState.offline,
    super.trunkVersion,
    super.branchId = '',
  }) : super(id: id, label: label, properties: List.unmodifiable(properties));

  /// A copy with the given fields replaced (`trunkVersion` can't be reset
  /// to `null` this way; use the constructor).
  NewEntity copyWith({
    String? label,
    int? version,
    List<EntityProperty>? properties,
    EntityState? state,
    int? trunkVersion,
    String? branchId,
  }) => NewEntity(
    id,
    label ?? this.label,
    version: version ?? this.version,
    properties: properties ?? this.properties,
    state: state ?? this.state,
    trunkVersion: trunkVersion ?? this.trunkVersion,
    branchId: branchId ?? this.branchId,
  );

  @override
  bool operator ==(Object other) => other is NewEntity && _fieldsEqual(other);

  @override
  int get hashCode => _fieldsHash;

  @override
  String toString() =>
      'New(id=$id, label=$label, version=$version, '
      'properties=$properties, state=$state, trunkVersion=$trunkVersion, '
      'branchId=$branchId)';
}

/// An entity read from an [EntitiesRepository]. Port of `Entity.Saved`.
final class SavedEntity extends Entity {
  /// Creates a saved entity at [index] in its list.
  SavedEntity(
    String id,
    String? label, {
    required this.index,
    super.version = 1,
    List<EntityProperty> properties = const [],
    super.state = EntityState.offline,
    super.trunkVersion,
    super.branchId = '',
  }) : super(id: id, label: label, properties: List.unmodifiable(properties));

  /// The position in the list (used as the secondary-instance item's
  /// multiplicity).
  final int index;

  /// A copy with the given fields replaced (`label` and `trunkVersion`
  /// can't be reset to `null` this way; use the constructor).
  SavedEntity copyWith({
    String? label,
    int? version,
    List<EntityProperty>? properties,
    EntityState? state,
    int? index,
    int? trunkVersion,
    String? branchId,
  }) => SavedEntity(
    id,
    label ?? this.label,
    index: index ?? this.index,
    version: version ?? this.version,
    properties: properties ?? this.properties,
    state: state ?? this.state,
    trunkVersion: trunkVersion ?? this.trunkVersion,
    branchId: branchId ?? this.branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is SavedEntity && other.index == index && _fieldsEqual(other);

  @override
  int get hashCode => Object.hash(_fieldsHash, index);

  @override
  String toString() =>
      'Saved(id=$id, label=$label, version=$version, '
      'properties=$properties, state=$state, index=$index, '
      'trunkVersion=$trunkVersion, branchId=$branchId)';
}
