import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A form offered by a server's form list (an OpenRosa `<xform>`).
///
/// Port of Collect's `org.odk.collect.forms.FormListItem`.
@immutable
final class FormListItem {
  /// Creates an item.
  const FormListItem({
    required this.downloadUrl,
    required this.formId,
    required this.name,
    this.version,
    this.hash,
    this.manifestUrl,
  });

  /// Where to download the form definition (`downloadUrl`).
  final String downloadUrl;

  /// The form's id (`formID`).
  final String formId;

  /// The form's version, if it has one.
  final String? version;

  /// The MD5 hash of the form definition without the `md5:` prefix, or
  /// `null` if the server sent none (or one without the prefix).
  final String? hash;

  /// The form's name.
  final String name;

  /// Where to fetch the form's media manifest, if it has media.
  final String? manifestUrl;

  @override
  bool operator ==(Object other) =>
      other is FormListItem &&
      other.downloadUrl == downloadUrl &&
      other.formId == formId &&
      other.version == version &&
      other.hash == hash &&
      other.name == name &&
      other.manifestUrl == manifestUrl;

  @override
  int get hashCode =>
      Object.hash(downloadUrl, formId, version, hash, name, manifestUrl);

  @override
  String toString() =>
      'FormListItem(downloadURL=$downloadUrl, formID=$formId, '
      'version=$version, hash=$hash, name=$name, manifestURL=$manifestUrl)';
}

/// The kind of a [MediaFile], from its `type` attribute.
///
/// Port of Collect's `MediaFile.Type`.
enum MediaFileType {
  /// `type="entityList"`: a dataset of entities.
  entityList,

  /// `type="approvalEntityList"`: a dataset of entities that need approval.
  approvalEntityList,
}

/// A file listed in a form's manifest (an OpenRosa `<mediaFile>`).
///
/// Port of Collect's `org.odk.collect.forms.MediaFile`.
@immutable
final class MediaFile {
  /// Creates a media file.
  const MediaFile({
    required this.filename,
    required this.hash,
    required this.downloadUrl,
    this.type,
    this.integrityUrl,
  });

  /// The file's name (without any directory).
  final String filename;

  /// The file's MD5 hash, without the `md5:` prefix.
  final String hash;

  /// Where to download the file.
  final String downloadUrl;

  /// What kind of file it is, if it's an entity list.
  final MediaFileType? type;

  /// Where to check which of an entity list's entities were deleted.
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

/// A form's manifest: its media files and the MD5 hash of the manifest
/// document itself.
///
/// Port of Collect's `org.odk.collect.forms.ManifestFile`.
@immutable
final class ManifestFile {
  /// Creates a manifest.
  ManifestFile(this.hash, List<MediaFile> mediaFiles)
    : mediaFiles = List.unmodifiable(mediaFiles);

  /// The MD5 hash of the manifest document.
  final String? hash;

  /// The listed files.
  final List<MediaFile> mediaFiles;

  @override
  bool operator ==(Object other) =>
      other is ManifestFile &&
      other.hash == hash &&
      const ListEquality<MediaFile>().equals(other.mediaFiles, mediaFiles);

  @override
  int get hashCode =>
      Object.hash(hash, const ListEquality<MediaFile>().hash(mediaFiles));
}

/// Whether an entity was deleted on the server, from an integrity
/// response.
///
/// Port of Collect's `org.odk.collect.openrosa.forms.EntityIntegrity`.
@immutable
final class EntityIntegrity {
  /// Creates the state of entity [id].
  const EntityIntegrity(this.id, {required this.deleted});

  /// The entity's id.
  final String id;

  /// Whether the entity was deleted.
  final bool deleted;

  @override
  bool operator ==(Object other) =>
      other is EntityIntegrity && other.id == id && other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, deleted);

  @override
  String toString() => 'EntityIntegrity(id=$id, deleted=$deleted)';
}
