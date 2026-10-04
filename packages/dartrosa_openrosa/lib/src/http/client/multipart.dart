import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../open_rosa_http_interface.dart';

/// A part of a [MultipartFormRequest].
final class FormDataPart {
  /// A file part: `name="[name]"; filename="[file.name]"` with
  /// [contentType].
  FormDataPart.file(this.name, UploadFile this.file, String this.contentType)
    : value = null;

  /// A plain field: `name="[name]"` with [value] and no content type.
  FormDataPart.field(this.name, String this.value)
    : file = null,
      contentType = null;

  /// The part's name.
  final String name;

  /// The file, for a file part.
  final UploadFile? file;

  /// The value, for a field.
  final String? value;

  /// The content type, for a file part.
  final String? contentType;
}

/// A `multipart/form-data` POST laid out byte for byte as OkHttp's
/// `MultipartBody` writes it (parts in order, each with
/// `Content-Disposition`, then `Content-Type` if any), whose
/// file content stops with an [UploadCancelledException] as soon as
/// [isCancelled] returns `true`.
///
/// Port of the request body Collect's `OkHttpConnection` builds (with its
/// `cancellableRequestBody`). Unlike `package:http`'s
/// `MultipartRequest`, it keeps the parts in order.
final class MultipartFormRequest extends http.BaseRequest {
  /// Creates the request; [boundary] defaults to a random UUID, as OkHttp's.
  MultipartFormRequest(
    Uri url,
    List<FormDataPart> parts, {
    bool Function()? isCancelled,
    String? boundary,
    Random? random,
  }) : _parts = List.unmodifiable(parts),
       _isCancelled = isCancelled ?? _never,
       boundary = boundary ?? _uuid(random ?? Random()),
       super('POST', url) {
    headers['Content-Type'] = 'multipart/form-data; boundary=${this.boundary}';
    var length = 0;
    for (final part in _parts) {
      length += _partHeader(part).length + _partLength(part) + 2;
    }
    contentLength = length + utf8.encode('--${this.boundary}--\r\n').length;
  }

  static bool _never() => false;

  /// The multipart boundary.
  final String boundary;

  final List<FormDataPart> _parts;
  final bool Function() _isCancelled;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body());
  }

  Stream<List<int>> _body() async* {
    for (final part in _parts) {
      yield _partHeader(part);
      final file = part.file;
      if (file != null) {
        await for (final chunk in file.openRead()) {
          if (_isCancelled()) throw const UploadCancelledException();
          yield chunk;
        }
      } else {
        yield utf8.encode(part.value!);
      }
      yield const [13, 10];
    }
    yield utf8.encode('--$boundary--\r\n');
  }

  static int _partLength(FormDataPart part) =>
      part.file?.length ?? utf8.encode(part.value!).length;

  List<int> _partHeader(FormDataPart part) {
    final disposition = StringBuffer('form-data; name=');
    _appendQuoted(disposition, part.name);
    final file = part.file;
    if (file != null) {
      disposition.write('; filename=');
      _appendQuoted(disposition, file.name);
    }
    final out = StringBuffer('--$boundary\r\n')
      ..write('Content-Disposition: $disposition\r\n');
    if (part.contentType != null) {
      out.write('Content-Type: ${part.contentType}\r\n');
    }
    out.write('\r\n');
    return utf8.encode(out.toString());
  }

  /// OkHttp's `appendQuotedString`.
  static void _appendQuoted(StringBuffer out, String key) {
    out.write('"');
    for (final c in key.split('')) {
      switch (c) {
        case '\n':
          out.write('%0A');
        case '\r':
          out.write('%0D');
        case '"':
          out.write('%22');
        default:
          out.write(c);
      }
    }
    out.write('"');
  }

  static String _uuid(Random random) {
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
