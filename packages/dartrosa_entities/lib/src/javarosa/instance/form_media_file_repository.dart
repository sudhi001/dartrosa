// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (FormMediaFileRepository), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// Tells whether a form has a media file attached for a `jr://` source.
///
/// Port of the part of Collect's `FormMediaFileRepository` the entities
/// module uses (`get(src)?.exists()`): the app implements it on its form
/// storage.
abstract interface class FormMediaFileRepository {
  /// Whether a media file for [mediaSrc] (such as
  /// `jr://file-csv/people.csv`) exists.
  bool exists(String mediaSrc);
}

/// A [FormMediaFileRepository] over a fixed set of sources (for tests, or
/// apps that know their forms' attachments up front).
final class InMemFormMediaFileRepository implements FormMediaFileRepository {
  /// Creates a repository where exactly [existing] sources exist.
  InMemFormMediaFileRepository([Iterable<String> existing = const []])
    : _existing = Set.of(existing);

  final Set<String> _existing;

  @override
  bool exists(String mediaSrc) => _existing.contains(mediaSrc);
}
