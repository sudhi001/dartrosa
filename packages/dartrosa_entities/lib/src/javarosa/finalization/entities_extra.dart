// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntitiesExtra), Copyright University of Washington,
//  Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'form_entity.dart';

/// The entities of a finalized form, stored in the form entry model's
/// `extras` under `EntitiesExtra` (`FormSession.extras` with the
/// high-level API).
///
/// Port of `org.odk.collect.entities.javarosa.finalization.EntitiesExtra`.
final class EntitiesExtra {
  /// Creates the extra.
  EntitiesExtra([List<FormEntity> entities = const []])
    : entities = List.unmodifiable(entities);

  /// The entities, in document order.
  final List<FormEntity> entities;

  /// A copy with [entity] added. Port of the Kotlin
  /// `copy(entities = entities + entity)`.
  EntitiesExtra plus(FormEntity entity) => EntitiesExtra([...entities, entity]);
}
