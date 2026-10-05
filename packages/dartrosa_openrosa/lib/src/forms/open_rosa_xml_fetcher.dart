// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaXmlFetcher), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:dartrosa/javarosa.dart';

import '../http/http_credentials.dart';
import '../http/http_results.dart';
import '../http/open_rosa_http_interface.dart';
import '../http/uri_utils.dart';
import 'document_fetch_result.dart';

/// Provides the credentials to use for a URL.
///
/// Port of Collect's `OpenRosaXmlFetcher.WebCredentialsProvider`.
abstract interface class WebCredentialsProvider {
  /// The credentials for requests to [url].
  HttpCredentialsInterface? getCredentials(Uri url);
}

/// Fetches documents with a `deviceID` query parameter and the right
/// credentials.
///
/// Port of Collect's `org.odk.collect.openrosa.forms.OpenRosaXmlFetcher`.
final class OpenRosaXmlFetcher {
  /// Creates a fetcher.
  OpenRosaXmlFetcher(
    this._httpInterface,
    this._webCredentialsProvider,
    this._deviceId,
  );

  static const _httpContentTypeTextXml = 'text/xml';

  final OpenRosaHttpInterface _httpInterface;
  WebCredentialsProvider _webCredentialsProvider;
  final String? _deviceId;

  /// Gets the XML document at [urlString].
  Future<DocumentFetchResult> getXml(String urlString) async {
    final inputStreamResult = await fetch(urlString, _httpContentTypeTextXml);

    if (inputStreamResult.statusCode != 200) {
      final error =
          'getXML failed while accessing $urlString with status code: '
          '${inputStreamResult.statusCode}';
      return DocumentFetchResult.error(error, inputStreamResult.statusCode);
    }

    final bytes = await inputStreamResult.inputStream!.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    final doc = getXmlDocument(utf8.decode(bytes, allowMalformed: true));
    return DocumentFetchResult(
      doc,
      isOpenRosaResponse: inputStreamResult.isOpenRosaResponse,
      hash: inputStreamResult.hash,
    );
  }

  /// GETs [downloadUrl] (with the device id appended) checking the
  /// returned content type against [contentType] (`text/xml` also
  /// computes a hash).
  ///
  /// Throws a [FormatException] for a malformed URL and an
  /// [OpenRosaHttpException] for one without a host name.
  Future<HttpGetResult> fetch(String downloadUrl, String? contentType) {
    // assume the downloadUrl is escaped properly
    // java.net.URL(...).toURI()
    if (!hasValidJavaUriCharacters(downloadUrl)) {
      throw FormatException('Illegal character in URL: $downloadUrl');
    }
    final uri = Uri.parse(downloadUrl);
    if (!uri.hasScheme) {
      // java.net.URL needs a protocol.
      throw FormatException('no protocol: $downloadUrl');
    }
    if (uri.host.isEmpty) {
      throw OpenRosaHttpException(
        'Invalid server URL (no hostname): $downloadUrl',
      );
    }
    final withDeviceId = Uri.parse(
      appendQueryParameters(downloadUrl, [('deviceID', _deviceId)]),
    );
    return _httpInterface.executeGetRequest(
      withDeviceId,
      contentType,
      _webCredentialsProvider.getCredentials(withDeviceId),
    );
  }

  /// Replaces the credentials provider.
  set webCredentialsProvider(WebCredentialsProvider provider) =>
      _webCredentialsProvider = provider;
}
