// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaClient), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../http/open_rosa_constants.dart';
import '../http/open_rosa_http_interface.dart';
import '../http/uri_utils.dart';
import '../parse/open_rosa_response_parser.dart';
import 'form_source.dart';
import 'models.dart';
import 'open_rosa_xml_fetcher.dart';

/// A [FormSource] and [EntitySource] backed by an OpenRosa server.
///
/// Port of Collect's `org.odk.collect.openrosa.forms.OpenRosaClient`.
final class OpenRosaClient implements FormSource, EntitySource {
  /// Creates a client for the server at [serverUrl] sending through
  /// [openRosaHttpInterface] as device [deviceId].
  OpenRosaClient(
    this.serverUrl,
    OpenRosaHttpInterface openRosaHttpInterface,
    WebCredentialsProvider webCredentialsProvider, {
    required String deviceId,
    OpenRosaResponseParser openRosaResponseParser =
        const Kxml2OpenRosaResponseParser(),
  }) : _openRosaResponseParser = openRosaResponseParser,
       _openRosaXmlFetcher = OpenRosaXmlFetcher(
         openRosaHttpInterface,
         webCredentialsProvider,
         deviceId,
       );

  final OpenRosaXmlFetcher _openRosaXmlFetcher;
  final OpenRosaResponseParser _openRosaResponseParser;

  /// The server URL (settable: Collect's `updateUrl`).
  String serverUrl;

  @override
  Future<List<FormListItem>> fetchFormList() async {
    final result = await _mapException(
      () => _openRosaXmlFetcher.getXml(_formListUrl()),
    );

    if (result.errorMessage != null) {
      switch (result.responseCode) {
        case 401:
          throw const FormSourceAuthRequired();
        case 404:
          throw FormSourceUnreachable(serverUrl);
        default:
          throw FormSourceServerError(result.responseCode, serverUrl);
      }
    }

    if (result.isOpenRosaResponse) {
      final formList = _openRosaResponseParser.parseFormList(result.doc);
      if (formList != null) return formList;
      throw FormSourceParseError(serverUrl);
    } else {
      throw const FormSourceServerNotOpenRosaError();
    }
  }

  @override
  Future<ManifestFile?> fetchManifest(String? manifestUrl) async {
    if (manifestUrl == null) return null;

    final result = await _mapException(
      () => _openRosaXmlFetcher.getXml(manifestUrl),
    );

    if (result.errorMessage != null) {
      if (result.responseCode != 200) {
        throw FormSourceServerError(result.responseCode, serverUrl);
      } else {
        throw const FormSourceFetchError();
      }
    }

    if (!result.isOpenRosaResponse) throw FormSourceParseError(serverUrl);

    final mediaFiles = _openRosaResponseParser.parseManifest(result.doc);
    if (mediaFiles != null) return ManifestFile(result.hash, mediaFiles);
    throw FormSourceParseError(serverUrl);
  }

  @override
  Future<Stream<List<int>>> fetchForm(String formUrl) => _fetchStream(formUrl);

  @override
  Future<Stream<List<int>>> fetchMediaFile(String mediaFileUrl) =>
      _fetchStream(mediaFileUrl);

  /// Changes the credentials provider (Collect's
  /// `updateWebCredentialsUtils`).
  set webCredentialsProvider(WebCredentialsProvider provider) =>
      _openRosaXmlFetcher.webCredentialsProvider = provider;

  @override
  Future<List<(String, bool)>> fetchDeletedStates(
    String integrityUrl,
    List<String> ids,
  ) async {
    final uri = appendQueryParameters(integrityUrl, [('id', ids.join(','))]);

    final result = await _mapException(() => _openRosaXmlFetcher.getXml(uri));
    if (!result.isOpenRosaResponse) throw FormSourceParseError(serverUrl);

    final parsedResponse = _openRosaResponseParser.parseIntegrityResponse(
      result.doc,
    );
    if (parsedResponse != null) {
      return [for (final e in parsedResponse) (e.id, e.deleted)];
    }
    throw FormSourceParseError(serverUrl);
  }

  Future<Stream<List<int>>> _fetchStream(String url) async {
    final result = await _mapException(
      () => _openRosaXmlFetcher.fetch(url, null),
    );
    final stream = result.inputStream;
    if (stream == null) {
      throw FormSourceServerError(result.statusCode, serverUrl);
    }
    return stream;
  }

  Future<T> _mapException<T>(Future<T> Function() callable) async {
    try {
      return await callable();
    } on Exception catch (e) {
      if (isUnknownHostException(e)) throw FormSourceUnreachable(serverUrl);
      if (isSslException(e)) throw FormSourceSecurityError(serverUrl);
      throw const FormSourceFetchError();
    }
  }

  String _formListUrl() {
    var downloadListUrl = serverUrl;
    while (downloadListUrl.endsWith('/')) {
      downloadListUrl = downloadListUrl.substring(
        0,
        downloadListUrl.length - 1,
      );
    }
    return downloadListUrl + OpenRosaConstants.formList;
  }
}

/// Whether [e] means the host name couldn't be resolved (Java's
/// `UnknownHostException`): an [UnknownHostException], or a failed host
/// lookup as `dart:io` reports it through `package:http`.
bool isUnknownHostException(Exception e) {
  if (e is UnknownHostException) return true;
  final text = e.toString();
  return text.contains('Failed host lookup') ||
      text.contains('nodename nor servname') ||
      text.contains('No address associated with hostname');
}

/// Whether [e] is a failed secure connection (Java's `SSLException`): an
/// [SslException], or a `dart:io` TLS failure.
bool isSslException(Exception e) {
  if (e is SslException) return true;
  final text = e.toString();
  return text.contains('HandshakeException') ||
      text.contains('TlsException') ||
      text.contains('CertificateException') ||
      text.contains('CERTIFICATE_VERIFY_FAILED');
}
