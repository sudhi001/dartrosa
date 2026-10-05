// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntityAction), Copyright University of Washington,
//  Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// What a form does to its entity.
///
/// Port of `org.odk.collect.entities.javarosa.spec.EntityAction`.
enum EntityAction {
  /// `create="1"`: create a new entity.
  create,

  /// `update="1"`: update an existing entity.
  update,

  /// Both `create` and `update`: update the entity if it exists, create
  /// it otherwise.
  upsert,
}
