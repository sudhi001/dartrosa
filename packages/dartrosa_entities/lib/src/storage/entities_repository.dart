// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntitiesRepository), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// @docImport 'in_mem_entities_repository.dart';
/// @docImport 'query_exception.dart';
library;

import '../javarosa/parse/entity_schema.dart';
import 'entity.dart';
import 'entity_list.dart';
import 'query.dart';

/// Stores entity lists and their entities.
///
/// Port of `org.odk.collect.entities.storage.EntitiesRepository`. Apps
/// implement it on their storage (Collect uses SQLite);
/// [InMemEntitiesRepository] keeps everything in memory. Methods are
/// synchronous because JavaRosa (and DartRosa) evaluate secondary
/// instances and filters synchronously.
abstract interface class EntitiesRepository {
  /// Saves [entities] to [list]. Properties ([Entity.properties]) will be
  /// dynamically added to the [list] if they don't already exist -
  /// [Entity] instances returned by follow-up calls to [query] will
  /// include them.
  ///
  /// To remove properties that shouldn't be in the [list] any longer, see
  /// [cleanUpProperties].
  void save(String list, List<Entity> entities);

  /// All lists.
  List<EntityList> getLists();

  /// The number of entities in [list].
  int getCount(String list);

  /// Adds an empty [list] if it doesn't exist.
  void addList(String list);

  /// Deletes the entity [id] from [list].
  void delete(String list, String id);

  /// The entities of [list] matching [query] (all of them without one).
  ///
  /// Throws [QueryException] if the query can't be run (e.g. an unknown
  /// column).
  List<SavedEntity> query(String list, [Query? query]);

  /// The entity at [index] in [list], if any.
  SavedEntity? getByIndex(String list, int index);

  /// Records that [list] was updated from a server list with [hash].
  void updateList(String list, String hash, {required bool needsApproval});

  /// The list called [list], if any.
  EntityList? getList(String list);

  /// Removes the properties of [list] that are not in [properties]
  /// (compared ignoring case).
  void cleanUpProperties(String list, Set<String> properties);
}

/// Helpers on [EntitiesRepository] (Kotlin extension functions).
extension EntitiesRepositoryExtensions on EntitiesRepository {
  /// The names of all lists. Port of `getListNames()`.
  List<String> getListNames() => [for (final list in getLists()) list.name];

  /// The entity with [id] in [dataset], if any. Port of
  /// `findEntityById()`.
  SavedEntity? findEntityById(String dataset, String id) {
    final results = query(dataset, StringEqQuery(EntitySchema.id, id));
    return results.isEmpty ? null : results.first;
  }
}
