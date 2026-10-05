// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (HttpGetResult, HttpHeadResult, HttpPostResult),
//  Copyright 2018 Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:logging/logging.dart';

import 'case_insensitive_headers.dart';
import 'open_rosa_constants.dart';

final _log = Logger('dartrosa_openrosa');

/// The result of a GET: the body, headers, MD5 hash and status code.
///
/// Port of Collect's `org.odk.collect.openrosa.http.HttpGetResult`.
final class HttpGetResult {
  /// Creates a result.
  HttpGetResult(this.inputStream, this.headers, this.hash, this.statusCode);

  static const _openRosaVersion = '1.0';

  /// The body, or `null` unless the status code was 200. Single
  /// subscription.
  final Stream<List<int>>? inputStream;

  /// The response headers (name → value).
  final Map<String, String> headers;

  /// The MD5 hash of the body when an XML document was asked for, `''`
  /// otherwise.
  final String hash;

  /// The HTTP status code.
  final int statusCode;

  /// Whether the response has an `X-OpenRosa-Version` header (logging
  /// versions other than `1.0`).
  bool get isOpenRosaResponse {
    var openRosaResponse = false;
    if (headers.isNotEmpty) {
      var versionMatch = false;
      final versions = <String?>[];
      for (final key in headers.keys) {
        if (key.toLowerCase() ==
            OpenRosaConstants.versionHeader.toLowerCase()) {
          openRosaResponse = true;
          if (headers[key] == _openRosaVersion) {
            versionMatch = true;
            break;
          }
          versions.add(headers[key]);
        }
      }
      if (!versionMatch) {
        _log.warning(
          '${OpenRosaConstants.versionHeader} unrecognized version(s): '
          '${versions.join('; ')}',
        );
      }
    }
    return openRosaResponse;
  }
}

/// The result of a HEAD: the status code and (for a 204) the headers.
///
/// Port of Collect's `org.odk.collect.openrosa.http.HttpHeadResult`.
final class HttpHeadResult {
  /// Creates a result.
  const HttpHeadResult(this.statusCode, this.headers);

  /// The HTTP status code.
  final int statusCode;

  /// The response headers.
  final CaseInsensitiveHeaders headers;
}

/// The result of a POST: the body, status code and reason phrase.
///
/// Port of Collect's `org.odk.collect.openrosa.http.HttpPostResult`.
final class HttpPostResult {
  /// Creates a result.
  const HttpPostResult(this.httpResponse, this.responseCode, this.reasonPhrase);

  /// The response body.
  final String httpResponse;

  /// The HTTP status code.
  final int responseCode;

  /// The HTTP reason phrase.
  final String reasonPhrase;
}
