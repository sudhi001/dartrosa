// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntityEvent), Copyright University of Washington,
//  Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

import '../javarosa/finalization/form_entity.dart';

/// Why a form entity was not saved locally.
///
/// Port of `org.odk.collect.entities.debug.EntityEvent`.
@immutable
sealed class EntityEvent {
  const EntityEvent(this.formEntity);

  /// The entity that was not saved.
  final FormEntity formEntity;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is EntityEvent &&
      other.formEntity == formEntity;

  @override
  int get hashCode => Object.hash(runtimeType, formEntity);

  @override
  String toString() => '$runtimeType(formEntity=$formEntity)';
}

/// A create (or upsert of a new entity) without a label.
final class CreateNoLabel extends EntityEvent {
  /// Creates the event.
  const CreateNoLabel(super.formEntity);
}

/// An update of an entity that doesn't exist locally.
final class UpdateNoMatch extends EntityEvent {
  /// Creates the event.
  const UpdateNoMatch(super.formEntity);
}

/// An entity without an id.
final class NoId extends EntityEvent {
  /// Creates the event.
  const NoId(super.formEntity);
}

/// An entity whose id is not a version 4 UUID.
final class InvalidId extends EntityEvent {
  /// Creates the event.
  const InvalidId(super.formEntity);
}
