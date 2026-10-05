// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OkHttpConnection), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../case_insensitive_headers.dart';
import '../http_credentials.dart';
import '../http_results.dart';
import '../open_rosa_http_interface.dart';
import 'multipart.dart';
import 'open_rosa_server_client.dart';

final _log = Logger('dartrosa_openrosa');

final _charsetParameter = RegExp(
  r'charset\s*=\s*"?([^";\s]+)',
  caseSensitive: false,
);

/// An [OpenRosaHttpInterface] over `package:http`, so it works on the VM
/// and the web.
///
/// Port of Collect's `OkHttpConnection`.
final class HttpClientConnection implements OpenRosaHttpInterface {
  /// Creates a connection sending through [client] (or through clients
  /// from [clientProvider]), uploading files with the content types of
  /// [fileToContentTypeMapper] and identifying itself as [userAgent].
  /// [random] makes multipart boundaries and Digest client nonces.
  HttpClientConnection({
    required this.fileToContentTypeMapper,
    required this.userAgent,
    http.Client? client,
    OpenRosaServerClientProvider? clientProvider,
    Random? random,
  }) : assert(
         (client == null) != (clientProvider == null),
         'Pass exactly one of client and clientProvider',
       ),
       _clientFactory =
           clientProvider ??
           HttpOpenRosaServerClientProvider(client!, random: random),
       _random = random;

  static const _httpContentTypeTextXml = 'text/xml';

  final OpenRosaServerClientProvider _clientFactory;
  final Random? _random;

  /// Maps attachment names to content types.
  final FileToContentTypeMapper fileToContentTypeMapper;

  /// The `User-Agent` header value.
  final String userAgent;

  @override
  Future<HttpGetResult> executeGetRequest(
    Uri uri,
    String? contentType,
    HttpCredentialsInterface? credentials,
  ) async {
    final httpClient = _clientFactory.get(uri.scheme, userAgent, credentials);
    final response = await httpClient.makeRequest(
      () => http.Request('GET', uri),
      clock.now(),
    );
    final statusCode = response.statusCode;

    if (statusCode != 200) {
      await _discardEntityBytes(response);
      _log.info('Error: ${response.reasonPhrase} ($statusCode at $uri');
      return HttpGetResult(null, {}, '', statusCode);
    }

    if (contentType != null && contentType.isNotEmpty) {
      final type = response.headers['content-type'];
      if (type != null && !type.toLowerCase().contains(contentType)) {
        await _discardEntityBytes(response);
        throw OpenRosaHttpException(
          'ContentType: $type returned from: $uri is not $contentType.  '
          'This is often caused by a network proxy.  Do you need to login '
          'to your network?',
        );
      }
    }

    Stream<List<int>> downloadStream = response.stream;
    var hash = '';
    if (contentType == _httpContentTypeTextXml) {
      final bytes = await response.stream.toBytes();
      downloadStream = Stream.value(bytes);
      hash = md5.convert(bytes).toString();
    }

    return HttpGetResult(
      downloadStream,
      Map.of(response.headers),
      hash,
      statusCode,
    );
  }

  @override
  Future<HttpHeadResult> executeHeadRequest(
    Uri uri,
    HttpCredentialsInterface? credentials,
  ) async {
    final httpClient = _clientFactory.get(uri.scheme, userAgent, credentials);
    _log.info('Issuing HEAD request to: $uri');
    final response = await httpClient.makeRequest(
      () => http.Request('HEAD', uri),
      clock.now(),
    );
    final statusCode = response.statusCode;

    CaseInsensitiveHeaders responseHeaders =
        const CaseInsensitiveEmptyHeaders();
    if (statusCode == 204) {
      responseHeaders = ListCaseInsensitiveHeaders.fromMap(response.headers);
    }
    await _discardEntityBytes(response);
    return HttpHeadResult(statusCode, responseHeaders);
  }

  @override
  Future<HttpPostResult> uploadSubmissionAndFiles(
    UploadFile submissionFile,
    List<UploadFile> fileList,
    Uri uri,
    HttpCredentialsInterface? credentials,
    int contentLength, {
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? () => false;
    HttpPostResult? postResult;

    var first = true;
    var fileIndex = 0;
    int lastFileIndex;
    while (fileIndex < fileList.length || first) {
      lastFileIndex = fileIndex;
      first = false;
      var byteCount = 0;

      final parts = [
        FormDataPart.file(
          'xml_submission_file',
          submissionFile,
          _httpContentTypeTextXml,
        ),
      ];
      _log.info('added xml_submission_file: ${submissionFile.name}');
      byteCount += submissionFile.length;

      for (; fileIndex < fileList.length; fileIndex++) {
        final file = fileList[fileIndex];
        final contentType = fileToContentTypeMapper.map(file.name);
        parts.add(FormDataPart.file(file.name, file, contentType));
        byteCount += file.length;
        _log.info("added file of type '$contentType' ${file.name}");

        // we've added at least one attachment to the request...
        if (fileIndex + 1 < fileList.length) {
          if ((fileIndex - lastFileIndex + 1 > 100) ||
              (byteCount + fileList[fileIndex + 1].length > contentLength)) {
            // the next file would exceed the 10MB threshold...
            _log.info('Extremely long post is being split into multiple posts');
            parts.add(FormDataPart.field('*isIncomplete*', 'yes'));
            ++fileIndex; // advance over the last attachment added...
            break;
          }
        }
      }

      postResult = await _executePostRequest(
        uri,
        credentials,
        parts,
        cancelled,
      );
      if (postResult.responseCode != 201 && postResult.responseCode != 202) {
        return postResult;
      }
    }
    return postResult!;
  }

  Future<HttpPostResult> _executePostRequest(
    Uri uri,
    HttpCredentialsInterface? credentials,
    List<FormDataPart> parts,
    bool Function() isCancelled,
  ) async {
    final httpClient = _clientFactory.get(uri.scheme, userAgent, credentials);
    final response = await httpClient.makeRequest(
      () => MultipartFormRequest(
        uri,
        parts,
        isCancelled: isCancelled,
        random: _random,
      ),
      clock.now(),
    );

    if (response.statusCode == 204) {
      await _discardEntityBytes(response);
      throw const OpenRosaHttpException();
    }

    final body = await response.stream.toBytes();
    return HttpPostResult(
      _charset(response.headers['content-type']).decode(body),
      response.statusCode,
      response.reasonPhrase ?? '',
    );
  }

  /// The charset of [contentType] (UTF-8 by default, as OkHttp's
  /// `ResponseBody.string`).
  static Encoding _charset(String? contentType) {
    final match = contentType == null
        ? null
        : _charsetParameter.firstMatch(contentType);
    final named = match == null ? null : Encoding.getByName(match.group(1));
    return named == null || named == utf8
        ? const Utf8Codec(allowMalformed: true)
        : named;
  }

  /// Drains the response so that its connection can be reused.
  static Future<void> _discardEntityBytes(
    http.StreamedResponse response,
  ) async {
    try {
      await response.stream.drain<void>();
    } on Exception catch (e) {
      _log.info(e);
    }
  }
}
