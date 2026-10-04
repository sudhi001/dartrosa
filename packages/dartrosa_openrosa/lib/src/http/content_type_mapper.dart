import 'package:mime/mime.dart';

import 'open_rosa_http_interface.dart';

/// Looks up the content type of a (lower-case) file extension, or returns
/// `null` if it's unknown.
typedef ExtensionContentTypes = String? Function(String extension);

/// Maps file names to content types: Collect's own mappings for types
/// Android doesn't know, then the system's, then
/// `application/octet-stream`.
///
/// Port of Collect's `CollectThenSystemContentTypeMapper`. Android's
/// `MimeTypeMap` is replaced by [systemTypes], which defaults to
/// `package:mime`'s table.
final class CollectThenSystemContentTypeMapper
    implements FileToContentTypeMapper {
  /// Creates a mapper falling back on [systemTypes].
  CollectThenSystemContentTypeMapper([ExtensionContentTypes? systemTypes])
    : _systemTypes = systemTypes ?? _mimePackageTypes;

  final ExtensionContentTypes _systemTypes;

  static const _collectContentTypes = {
    'amr': 'audio/amr',
    'oga': 'audio/ogg',
    'ogv': 'video/ogg',
    'webm': 'video/webm',
  };

  static String? _mimePackageTypes(String extension) =>
      extension.isEmpty ? null : lookupMimeType('file.$extension');

  @override
  String map(String fileName) {
    final extension = _fileExtension(fileName);
    return _collectContentTypes[extension] ??
        _systemTypes(extension) ??
        'application/octet-stream';
  }

  static String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
