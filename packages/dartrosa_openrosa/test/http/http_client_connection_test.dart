// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Ports of Collect's OpenRosaGetRequestTest, OpenRosaHeadRequestTest and
// OpenRosaPostRequestTest (run there against OkHttpConnection), with
// package:http's MockClient in place of OkHttp's MockWebServer.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/mock_web_server.dart';

const userAgent = 'Test Agent';

final class XmlOrBlahContentTypeMapper implements FileToContentTypeMapper {
  @override
  String map(String fileName) =>
      fileName.endsWith('.xml') ? 'text/xml' : 'text/blah';
}

var _tempCounter = 0;

UploadFile tempFile(String content, [String extension = '.tmp']) =>
    BytesUploadFile(
      'tempfile${_tempCounter++}$extension',
      utf8.encode(content),
    );

Future<String> readAll(Stream<List<int>>? stream) async =>
    utf8.decode(await stream!.expand((c) => c).toList());

void main() {
  late MockWebServer mockWebServer;
  late OpenRosaHttpInterface subject;

  setUp(() {
    mockWebServer = MockWebServer();
    subject = HttpClientConnection(
      client: mockWebServer.client,
      fileToContentTypeMapper: XmlOrBlahContentTypeMapper(),
      userAgent: userAgent,
    );
  });

  group('GET', () {
    test('makes a GET request to uri', () async {
      mockWebServer.enqueue(MockResponse());
      final uri = mockWebServer.url('/blah');
      await subject.executeGetRequest(uri, null, null);
      expect(mockWebServer.requestCount, 1);
      final request = mockWebServer.takeRequest();
      expect(request.method, 'GET');
      expect(request.url, uri);
    });

    test('sends Collect headers', () async {
      mockWebServer.enqueue(MockResponse());
      await subject.executeGetRequest(mockWebServer.url(''), null, null);
      final request = mockWebServer.takeRequest();
      expect(request.header('User-Agent'), userAgent);
      expect(request.header(OpenRosaConstants.versionHeader), '1.0');
    });

    test('returns body with empty hash', () async {
      mockWebServer.enqueue(MockResponse(body: 'I AM BODY'));
      final result = await subject.executeGetRequest(
        mockWebServer.url(''),
        null,
        null,
      );
      expect(await readAll(result.inputStream), 'I AM BODY');
      expect(result.hash, '');
    });

    test(
      'when response is gzipped returns body',
      () {},
      skip:
          "Content decoding is the http.Client's job (dart:io and browsers "
          'decompress transparently, as OkHttp does).',
    );

    test('when content type is XML returns body with MD5 hash', () async {
      mockWebServer.enqueue(
        MockResponse(body: 'I AM BODY', headers: {'content-type': 'text/xml'}),
      );
      final result = await subject.executeGetRequest(
        mockWebServer.url(''),
        'text/xml',
        null,
      );
      expect(await readAll(result.inputStream), 'I AM BODY');
      expect(result.hash, md5.convert(utf8.encode('I AM BODY')).toString());
    });

    test(
      'with content type, when response has different content type, throws exception',
      () async {
        mockWebServer.enqueue(
          MockResponse(headers: {'content-type': 'application/json'}),
        );
        await expectLater(
          subject.executeGetRequest(mockWebServer.url(''), 'text/xml', null),
          throwsA(isA<OpenRosaHttpException>()),
        );
      },
    );

    test(
      'with content type, when response contains content type, returns result',
      () async {
        mockWebServer.enqueue(
          MockResponse(
            body: 'I AM BODY',
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        final result = await subject.executeGetRequest(
          mockWebServer.url(''),
          'application/json',
          null,
        );
        expect(await readAll(result.inputStream), 'I AM BODY');
      },
    );

    test('returns OpenRosa version', () async {
      mockWebServer.enqueue(
        MockResponse(headers: {OpenRosaConstants.versionHeader: '1.0'}),
      );
      final result1 = await subject.executeGetRequest(
        mockWebServer.url(''),
        null,
        null,
      );
      expect(result1.isOpenRosaResponse, isTrue);

      mockWebServer.enqueue(MockResponse());
      final result2 = await subject.executeGetRequest(
        mockWebServer.url(''),
        null,
        null,
      );
      expect(result2.isOpenRosaResponse, isFalse);
    });

    test(
      'when status code is not 200 returns null body and status code',
      () async {
        mockWebServer.enqueue(MockResponse(code: 500));
        final result = await subject.executeGetRequest(
          mockWebServer.url(''),
          null,
          null,
        );
        expect(result.inputStream, isNull);
        expect(result.statusCode, 500);
      },
    );

    test(
      'when response body is null returns null body and status code',
      () async {
        mockWebServer.enqueue(MockResponse(code: 204));
        final result1 = await subject.executeGetRequest(
          mockWebServer.url(''),
          null,
          null,
        );
        expect(result1.inputStream, isNull);
        expect(result1.statusCode, 204);

        mockWebServer.enqueue(MockResponse(code: 304));
        final result2 = await subject.executeGetRequest(
          mockWebServer.url(''),
          null,
          null,
        );
        expect(result2.inputStream, isNull);
        expect(result2.statusCode, 304);
      },
    );
  });

  group('HEAD', () {
    test('makes a HEAD request to uri', () async {
      mockWebServer.enqueue(MockResponse());
      final uri = mockWebServer.url('/blah');
      await subject.executeHeadRequest(uri, null);
      expect(mockWebServer.requestCount, 1);
      final request = mockWebServer.takeRequest();
      expect(request.method, 'HEAD');
      expect(request.url, uri);
    });

    test('sends Collect headers', () async {
      mockWebServer.enqueue(MockResponse());
      await subject.executeHeadRequest(mockWebServer.url(''), null);
      expect(mockWebServer.takeRequest().header('User-Agent'), userAgent);
    });

    test('when 204 response returns headers', () async {
      mockWebServer.enqueue(
        MockResponse(code: 204, headers: {'x-1': 'Blah1', 'x-2': 'Blah2'}),
      );
      final result = await subject.executeHeadRequest(
        mockWebServer.url(''),
        null,
      );
      expect(result.headers.getAnyValue('X-1'), 'Blah1');
      expect(result.headers.getAnyValue('X-2'), 'Blah2');
    });

    // https://github.com/getodk/collect/issues/3068
    test('when 204 response returns lower case headers', () async {
      mockWebServer.enqueue(
        MockResponse(code: 204, headers: {'header-case-test': 'value'}),
      );
      final result = await subject.executeHeadRequest(
        mockWebServer.url(''),
        null,
      );
      expect(result.headers.containsHeader('Header-Case-Test'), isTrue);
      expect(result.headers.getAnyValue('Header-Case-Test'), 'value');
    });

    test('other responses have no headers', () async {
      mockWebServer.enqueue(MockResponse(headers: {'x-1': 'Blah1'}));
      final result = await subject.executeHeadRequest(
        mockWebServer.url(''),
        null,
      );
      expect(result.statusCode, 200);
      expect(result.headers.containsHeader('X-1'), isFalse);
    });

    test('when request fails throws exception with message', () async {
      try {
        await subject.executeHeadRequest(
          Uri.parse('http://localhost:8443'),
          null,
        );
        fail('no exception');
      } on Exception catch (e) {
        expect(exceptionMessage(e), isNotEmpty);
      }
    });
  });

  group('POST', () {
    Future<HttpPostResult> upload(
      UploadFile submission,
      List<UploadFile> files,
      int contentLength, {
      bool Function()? isCancelled,
    }) => subject.uploadSubmissionAndFiles(
      submission,
      files,
      mockWebServer.url('/blah'),
      null,
      contentLength,
      isCancelled: isCancelled,
    );

    test('makes a POST request to uri', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      await upload(tempFile(''), [], 0);
      expect(mockWebServer.requestCount, 1);
      final request = mockWebServer.takeRequest();
      expect(request.method, 'POST');
      expect(request.url, mockWebServer.url('/blah'));
      expect(
        request.header('Content-Type'),
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.header('User-Agent'), userAgent);
      expect(request.header(OpenRosaConstants.versionHeader), '1.0');
    });

    test('returns post result', () async {
      mockWebServer.enqueue(MockResponse(body: 'I AM BODY'));
      final response = await upload(tempFile(''), [], 0);
      expect(response.responseCode, 200);
      expect(response.httpResponse, 'I AM BODY');
    });

    test(
      'when response is gzipped returns body',
      () {},
      skip: "Content decoding is the http.Client's job.",
    );

    test('when response is 204 throws exception', () async {
      mockWebServer.enqueue(MockResponse(code: 204));
      await expectLater(
        upload(tempFile(''), [], 0),
        throwsA(isA<OpenRosaHttpException>()),
      );
    });

    test('when there is a server error returns post body', () async {
      mockWebServer.enqueue(MockResponse(code: 500, body: 'blah'));
      final response = await upload(tempFile(''), [], 0);
      expect(response.responseCode, 500);
      expect(response.httpResponse, 'blah');
    });

    test('when request fails throws exception with message', () async {
      try {
        await subject.uploadSubmissionAndFiles(
          tempFile(''),
          [],
          Uri.parse('http://localhost:8443'),
          null,
          0,
        );
        fail('no exception');
      } on Exception catch (e) {
        expect(exceptionMessage(e), isNotEmpty);
      }
    });

    test('sends submission file as first part of body', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      final file = tempFile('<node>content</node>');
      await upload(file, [], 0);
      final firstPartLines = splitMultiPart(mockWebServer.takeRequest())[0];
      expect(firstPartLines[1], contains('name="xml_submission_file"'));
      expect(firstPartLines[1], contains('filename="${file.name}"'));
      expect(firstPartLines[2], contains('Content-Type: text/xml'));
      expect(firstPartLines[3], '');
      expect(firstPartLines[4], '<node>content</node>');
    });

    test('sends attachments as parts of body', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      final attachment1 = tempFile('blah blah blah');
      final attachment2 = tempFile('blah2 blah2 blah2');
      await upload(tempFile('<node>content</node>'), [
        attachment1,
        attachment2,
      ], 1024);
      final parts = splitMultiPart(mockWebServer.takeRequest());

      expect(parts[1][1], contains('name="${attachment1.name}"'));
      expect(parts[1][1], contains('filename="${attachment1.name}"'));
      expect(parts[1][4], 'blah blah blah');
      expect(parts[2][1], contains('name="${attachment2.name}"'));
      expect(parts[2][1], contains('filename="${attachment2.name}"'));
      expect(parts[2][4], 'blah2 blah2 blah2');
    });

    test('sends attachments as parts of body with content type', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      final xmlAttachment = tempFile('<node>blah blah blah</node>', '.xml');
      final plainAttachment = tempFile('blah', '.blah');
      await upload(tempFile('<node>content</node>'), [
        xmlAttachment,
        plainAttachment,
      ], 1024);
      final parts = splitMultiPart(mockWebServer.takeRequest());
      expect(parts[1][2], contains('Content-Type: text/xml'));
      expect(parts[2][2], contains('Content-Type: text/blah'));
    });

    test('body length matches the Content-Length', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      await upload(tempFile('<a/>'), [tempFile('x' * 20000)], 1 << 20);
      final request = mockWebServer.takeRequest();
      expect(request.body.length, greaterThan(20000));
      expect(request.bodyText, endsWith('--\r\n'));
    });

    test(
      'when more than one attachment and request is larger than max content length sends two requests',
      () async {
        mockWebServer
          ..enqueue(MockResponse(code: 201))
          ..enqueue(MockResponse(code: 201));
        final attachment1 = tempFile('blah blah blah');
        final attachment2 = tempFile('blah2 blah2 blah2');
        await upload(tempFile('<node>content</node>'), [
          attachment1,
          attachment2,
        ], 0);

        var parts = splitMultiPart(mockWebServer.takeRequest());
        expect(parts.length, 3);
        expect(parts[1][1], contains('name="${attachment1.name}"'));
        expect(parts[1][1], contains('filename="${attachment1.name}"'));
        expect(parts[1][4], 'blah blah blah');
        expect(parts[2][1], contains('name="*isIncomplete*"'));
        expect(parts[2][3], 'yes');

        parts = splitMultiPart(mockWebServer.takeRequest());
        expect(parts.length, 2);
        expect(parts[1][1], contains('name="${attachment2.name}"'));
        expect(parts[1][1], contains('filename="${attachment2.name}"'));
        expect(parts[1][4], 'blah2 blah2 blah2');
      },
    );

    test(
      'when more than one attachment and request is larger than max content length and first request is 500 returns error result',
      () async {
        mockWebServer.enqueue(MockResponse(code: 500));
        final response = await upload(tempFile('<node>content</node>'), [
          tempFile('blah blah blah'),
          tempFile('blah2 blah2 blah2'),
        ], 0);
        expect(mockWebServer.requestCount, 1);
        expect(response.responseCode, 500);
      },
    );

    test(
      'when more than one attachment and request is larger than max content length and second request is 500 returns error result',
      () async {
        mockWebServer
          ..enqueue(MockResponse(code: 201))
          ..enqueue(MockResponse(code: 500));
        final response = await upload(tempFile('<node>content</node>'), [
          tempFile('blah blah blah'),
          tempFile('blah2 blah2 blah2'),
        ], 0);
        expect(mockWebServer.requestCount, 2);
        expect(response.responseCode, 500);
      },
    );

    test('splits after 100 attachments', () async {
      for (var i = 0; i < 3; i++) {
        mockWebServer.enqueue(MockResponse(code: 202));
      }
      final files = [for (var i = 0; i < 250; i++) tempFile('x')];
      await upload(tempFile('<a/>'), files, 1 << 30);
      expect(mockWebServer.requestCount, 3);
      // 101 attachments, then *isIncomplete*: Collect checks the count
      // after adding.
      expect(splitMultiPart(mockWebServer.takeRequest()).length, 1 + 101 + 1);
      expect(splitMultiPart(mockWebServer.takeRequest()).length, 1 + 101 + 1);
      expect(splitMultiPart(mockWebServer.takeRequest()).length, 1 + 48);
    });

    test('when canceled during upload aborts request', () async {
      mockWebServer.enqueue(MockResponse(code: 201));
      await expectLater(
        upload(
          tempFile('<node>content</node>'),
          [],
          0,
          isCancelled: () => true,
        ),
        throwsA(isA<UploadCancelledException>()),
      );
    });
  });
}
