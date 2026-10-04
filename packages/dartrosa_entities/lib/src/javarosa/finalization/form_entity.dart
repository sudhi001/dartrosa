import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../storage/entity.dart';
import '../spec/entity_action.dart';

const _propertiesEquality = ListEquality<EntityProperty>();

/// An entity a finalized form creates or updates.
///
/// Port of `org.odk.collect.entities.javarosa.finalization.FormEntity`.
@immutable
final class FormEntity {
  /// Creates the form entity.
  FormEntity(
    this.action,
    this.dataset,
    this.id,
    this.label,
    List<EntityProperty> properties,
  ) : properties = List.unmodifiable(properties);

  /// Create, update or upsert.
  final EntityAction action;

  /// The entity list.
  final String dataset;

  /// The entity id (the `<entity id>` attribute).
  final String? id;

  /// The label (`''` if none).
  final String label;

  /// The `saveto` values, as (property, value) pairs.
  final List<EntityProperty> properties;

  @override
  bool operator ==(Object other) =>
      other is FormEntity &&
      other.action == action &&
      other.dataset == dataset &&
      other.id == id &&
      other.label == label &&
      _propertiesEquality.equals(other.properties, properties);

  @override
  int get hashCode => Object.hash(
    action,
    dataset,
    id,
    label,
    _propertiesEquality.hash(properties),
  );

  @override
  String toString() =>
      'FormEntity(action=$action, dataset=$dataset, id=$id, label=$label, '
      'properties=$properties)';
}
