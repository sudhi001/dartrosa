// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocalEntitiesInstanceAdapter), Copyright University
//  of Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart' show StringValue;
import 'package:dartrosa/javarosa.dart';

import '../../storage/entities_repository.dart';
import '../../storage/entity.dart';
import '../../storage/query.dart';
import '../parse/entity_schema.dart';

/// Presents the lists of an [EntitiesRepository] as secondary-instance
/// `item` elements (`name`, `label`, `__version`, `__trunkVersion`,
/// `__branchId`, then the properties).
///
/// Port of
/// `org.odk.collect.entities.javarosa.intance.LocalEntitiesInstanceAdapter`.
/// The list names are read once, when the adapter is created.
final class LocalEntitiesInstanceAdapter {
  /// Creates an adapter for the lists of the given repository.
  LocalEntitiesInstanceAdapter(this._entitiesRepository)
    : _lists = _entitiesRepository.getListNames();

  final EntitiesRepository _entitiesRepository;
  final List<String> _lists;

  /// Whether [instanceId] is one of the repository's lists.
  bool supportsInstance(String instanceId) => _lists.contains(instanceId);

  /// All items of [instanceId]; with [partial], only the first item is
  /// complete and the others are empty partial placeholders.
  List<TreeElement> getAll(String instanceId, {required bool partial}) {
    if (partial) {
      final count = _entitiesRepository.getCount(instanceId);
      if (count <= 0) return [];
      final first = _entitiesRepository.getByIndex(instanceId, 0)!;
      return [
        for (var i = 0; i < count; i++)
          i == 0 ? _convertToElement(first) : TreeElement('item', i, true),
      ];
    }
    return [
      for (final entity in _entitiesRepository.query(instanceId))
        _convertToElement(entity),
    ];
  }

  /// The items of [list] matching [query]. Throws `QueryException` if the
  /// repository can't run it.
  List<TreeElement> query(String list, Query query) => [
    for (final entity in _entitiesRepository.query(list, query))
      _convertToElement(entity),
  ];

  TreeElement _convertToElement(SavedEntity entity) {
    final name = TreeElement(EntitySchema.id)..value = StringValue(entity.id);
    final label = TreeElement(EntitySchema.label);
    final version = TreeElement(EntitySchema.version)
      ..value = StringValue('${entity.version}');
    final trunkVersion = TreeElement(EntitySchema.trunkVersion);
    final branchId = TreeElement(EntitySchema.branchId)
      ..value = StringValue(entity.branchId);

    final entityLabel = entity.label;
    if (entityLabel != null) label.value = StringValue(entityLabel);

    final entityTrunkVersion = entity.trunkVersion;
    if (entityTrunkVersion != null) {
      trunkVersion.value = StringValue('$entityTrunkVersion');
    }

    final item = TreeElement('item', entity.index)
      ..addChild(name)
      ..addChild(label)
      ..addChild(version)
      ..addChild(trunkVersion)
      ..addChild(branchId);

    for (final (propertyName, propertyValue) in entity.properties) {
      item.addChild(
        TreeElement(propertyName)..value = StringValue(propertyValue),
      );
    }

    return item;
  }
}
