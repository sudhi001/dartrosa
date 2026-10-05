// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntitySchema), Copyright University of Washington,
//  Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// The reserved column names of an entity list (in its CSV and in the
/// secondary instance forms see).
///
/// Port of `org.odk.collect.entities.javarosa.parse.EntitySchema`.
abstract final class EntitySchema {
  /// The entity id.
  static const id = 'name';

  /// The label.
  static const label = 'label';

  /// The (local) version.
  static const version = '__version';

  /// The server version the entity is based on.
  static const trunkVersion = '__trunkVersion';

  /// The offline branch id.
  static const branchId = '__branchId';
}
