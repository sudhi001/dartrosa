import 'package:dartrosa/javarosa.dart';

import '../forms/models.dart';

/// Parses OpenRosa responses.
///
/// Port of Collect's `org.odk.collect.openrosa.parse.OpenRosaResponseParser`.
/// Documents are the document elements `getXmlDocument` returns (`null`
/// for an empty document).
abstract interface class OpenRosaResponseParser {
  /// The forms in a form list (`<xforms>`), or `null` if it isn't one.
  List<FormListItem>? parseFormList(KElement? document);

  /// The files in a manifest (`<manifest>`), or `null` if it isn't one.
  List<MediaFile>? parseManifest(KElement? document);

  /// The entities in an integrity response (`<data><entities>`), or
  /// `null` if it isn't one.
  List<EntityIntegrity>? parseIntegrityResponse(KElement? document);
}

/// The OpenRosa 1.0 [OpenRosaResponseParser].
///
/// Port of Collect's `Kxml2OpenRosaResponseParser`.
final class Kxml2OpenRosaResponseParser implements OpenRosaResponseParser {
  /// Creates the parser.
  const Kxml2OpenRosaResponseParser();

  static const _md5StringPrefix = 'md5:';
  static const _namespaceXformsList = 'http://openrosa.org/xforms/xformsList';
  static const _namespaceXformsManifest =
      'http://openrosa.org/xforms/xformsManifest';

  @override
  List<FormListItem>? parseFormList(KElement? document) {
    // Attempt OpenRosa 1.0 parsing
    final xformsElement = document;
    if (xformsElement == null) return null;
    if (xformsElement.name != 'xforms') return null;
    if (!_hasNamespace(xformsElement, _namespaceXformsList)) return null;

    final formList = <FormListItem>[];
    for (var i = 0; i < xformsElement.childCount; i++) {
      // e.g., whitespace (text)
      final xformElement = xformsElement.elementAt(i);
      if (xformElement == null) continue;
      // someone else's extension?
      if (!_hasNamespace(xformElement, _namespaceXformsList)) continue;
      if (xformElement.name.toLowerCase() != 'xform') continue;

      // this is something we know how to interpret
      String? formId;
      String? formName;
      String? version;
      String? downloadUrl;
      String? manifestUrl;
      String? hash;
      // don't process descriptionUrl
      for (var j = 0; j < xformElement.childCount; j++) {
        final child = xformElement.elementAt(j);
        if (child == null) continue; // whitespace
        if (!_hasNamespace(child, _namespaceXformsList)) continue;
        switch (child.name) {
          case 'formID':
            formId = _emptyToNull(xmlText(child, trim: true));
          case 'name':
            formName = _emptyToNull(xmlText(child, trim: true));
          case 'version':
            version = xmlText(child, trim: true);
            if (version != null && version.trim().isEmpty) version = null;
          case 'downloadUrl':
            downloadUrl = _emptyToNull(xmlText(child, trim: true));
          case 'manifestUrl':
            manifestUrl = _emptyToNull(xmlText(child, trim: true));
          case 'hash':
            hash = xmlText(child, trim: true);
            // Collect calls substring on a null hash (an element without
            // children, `<hash/>`), failing with a NullPointerException.
            if (hash == null) {
              throw StateError('<hash/> has no text');
            }
            hash = hash.isEmpty || !hash.startsWith(_md5StringPrefix)
                ? null
                : hash.substring(_md5StringPrefix.length);
        }
      }

      if (formId == null || downloadUrl == null || formName == null) {
        return null;
      }
      formList.add(
        FormListItem(
          downloadUrl: downloadUrl,
          formId: formId,
          version: version,
          hash: hash,
          name: formName,
          manifestUrl: manifestUrl,
        ),
      );
    }
    return formList;
  }

  @override
  List<MediaFile>? parseManifest(KElement? document) {
    // Attempt OpenRosa 1.0 parsing
    final manifestElement = document;
    if (manifestElement == null) return null;
    if (manifestElement.name != 'manifest') return null;
    if (!_hasNamespace(manifestElement, _namespaceXformsManifest)) return null;

    final files = <MediaFile>[];
    for (var i = 0; i < manifestElement.childCount; i++) {
      final mediaFileElement = manifestElement.elementAt(i);
      if (mediaFileElement == null) continue; // e.g., whitespace (text)
      // someone else's extension?
      if (!_hasNamespace(mediaFileElement, _namespaceXformsManifest)) continue;

      final type = mediaFileElement.attribute(null, 'type');
      if (mediaFileElement.name.toLowerCase() != 'mediafile') continue;

      String? filename;
      String? hash;
      String? downloadUrl;
      String? integrityUrl;
      // don't process descriptionUrl
      for (var j = 0; j < mediaFileElement.childCount; j++) {
        final child = mediaFileElement.elementAt(j);
        if (child == null) continue; // e.g., whitespace (text)
        if (!_hasNamespace(child, _namespaceXformsManifest)) continue;
        switch (child.name) {
          case 'filename':
            filename = _emptyToNull(xmlText(child, trim: true));
            if (filename != null) filename = _fileName(filename);
          case 'hash':
            hash = xmlText(child, trim: true);
            if (hash != null && hash.isEmpty) {
              hash = null;
            } else {
              // Collect strips the prefix without checking it is there (and
              // fails on <hash/>, or a hash shorter than the prefix).
              if (hash == null) throw StateError('<hash/> has no text');
              hash = hash.substring(_md5StringPrefix.length);
            }
          case 'downloadUrl':
            downloadUrl = _emptyToNull(xmlText(child, trim: true));
          case 'integrityUrl':
            integrityUrl = xmlText(child, trim: true);
        }
      }

      if (filename == null || downloadUrl == null || hash == null) {
        return null;
      }
      final mediaFileType = switch (type) {
        'entityList' => MediaFileType.entityList,
        'approvalEntityList' => MediaFileType.approvalEntityList,
        _ => null,
      };
      files.add(
        MediaFile(
          filename: filename,
          hash: hash,
          downloadUrl: downloadUrl,
          type: mediaFileType,
          integrityUrl: integrityUrl,
        ),
      );
    }
    return files;
  }

  @override
  List<EntityIntegrity>? parseIntegrityResponse(KElement? document) {
    final data = document;
    if (data == null || data.name != 'data') return null;

    final entities = _element(data, 'entities');
    if (entities == null) return null;
    final result = <EntityIntegrity>[];
    for (final entity in entities.childElements) {
      if (entity.name != 'entity') continue;
      final deleted = _element(entity, 'deleted');
      // kdom's getChild(0) as String: there must be a first child, and it
      // must be text.
      if (deleted == null || deleted.childCount == 0) return null;
      final text = deleted.textAt(0);
      if (text == null) return null;
      // Kotlin's toBooleanStrict.
      final bool value;
      if (text == 'true') {
        value = true;
      } else if (text == 'false') {
        value = false;
      } else {
        return null;
      }
      final id = entity.attribute(null, 'id');
      // Collect's EntityIntegrity has a non-null id: a missing attribute
      // fails (a NullPointerException, caught as a RuntimeException).
      if (id == null) return null;
      result.add(EntityIntegrity(id, deleted: value));
    }
    return result;
  }

  /// kdom's `getElement(null, name)`: the first child element called
  /// [name] in any namespace (kdom throws when there is none).
  static KElement? _element(KElement parent, String name) {
    for (final child in parent.childElements) {
      if (child.name == name) return child;
    }
    return null;
  }

  static String? _emptyToNull(String? s) => s != null && s.isEmpty ? null : s;

  /// `java.io.File(path).getName()`: the part after the last `/`.
  static String _fileName(String path) {
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p.substring(p.lastIndexOf('/') + 1);
  }

  static bool _hasNamespace(KElement e, String namespace) =>
      e.namespace.toLowerCase() == namespace.toLowerCase();
}
