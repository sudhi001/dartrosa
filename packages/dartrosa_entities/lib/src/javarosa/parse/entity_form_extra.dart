// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntityFormExtra, Externalizable), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

import 'save_to.dart';

/// The entity information of a parsed form, stored in its
/// `FormDef.extras` under `EntityFormExtra`.
///
/// Port of `org.odk.collect.entities.javarosa.parse.EntityFormExtra`
/// (without `Externalizable`; see [SaveTo]).
final class EntityFormExtra {
  /// Creates the extra.
  EntityFormExtra([List<SaveTo> saveTos = const []])
    : saveTos = List.unmodifiable(saveTos);

  /// The form's `saveto` bindings.
  final List<SaveTo> saveTos;
}
