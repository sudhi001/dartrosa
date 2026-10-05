// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (MediaFile), Copyright 2017 Nafundi; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

/// The kind of an entity-list media file.
///
/// Port of `MediaFile.Type`.
enum MediaFileType {
  /// An entity list.
  entityList,

  /// An entity list whose new entities need approval on the server.
  approvalEntityList,
}

/// A form attachment from the server's manifest.
///
/// Port of `org.odk.collect.forms.MediaFile`.
@immutable
final class MediaFile {
  /// Creates a media file description.
  const MediaFile(
    this.filename,
    this.hash,
    this.downloadUrl, {
    this.type,
    this.integrityUrl,
  });

  /// The file name.
  final String filename;

  /// The file hash from the manifest.
  final String hash;

  /// Where to download it.
  final String downloadUrl;

  /// The entity-list type, if it is one.
  final MediaFileType? type;

  /// The entity list's integrity URL (for deleted-entity checks), if any.
  final String? integrityUrl;

  @override
  bool operator ==(Object other) =>
      other is MediaFile &&
      other.filename == filename &&
      other.hash == hash &&
      other.downloadUrl == downloadUrl &&
      other.type == type &&
      other.integrityUrl == integrityUrl;

  @override
  int get hashCode =>
      Object.hash(filename, hash, downloadUrl, type, integrityUrl);

  @override
  String toString() =>
      'MediaFile(filename=$filename, hash=$hash, downloadUrl=$downloadUrl, '
      'type=$type, integrityUrl=$integrityUrl)';
}
