// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaServerInstanceUploader), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

// Tests of the port of Collect's OpenRosaServerInstanceUploader (Collect
// has no unit tests for it; these follow its code paths).
import 'dart:convert';

import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/mock_web_server.dart';

UploadFile file(String name, [String content = 'x']) =>
    BytesUploadFile(name, utf8.encode(content));

InstanceUpload instance({String? submissionUri, List<UploadFile>? files}) =>
    InstanceUpload(
      instanceFileName: 'form_2024.xml',
      files:
          files ??
          [file('form_2024.xml', '<data/>'), file('a.jpg'), file('.hidden')],
      submissionUri: submissionUri,
    );

const okResponse =
    '<OpenRosaResponse xmlns="http://openrosa.org/http/response">'
    '<message>Success!</message></OpenRosaResponse>';

void main() {
  late FakeHttpInterface http;
  late OpenRosaInstanceUploader uploader;

  setUp(() {
    http = FakeHttpInterface()
      ..onHead = ((_) async =>
          const HttpHeadResult(204, CaseInsensitiveEmptyHeaders()))
      ..onUpload = ((_) async =>
          const HttpPostResult(okResponse, 201, 'Created'));
    uploader = OpenRosaInstanceUploader(http, StubWebCredentialsProvider());
  });

  Future<String?> upload({
    InstanceUpload? upload,
    String? overrideUrl,
    String? serverUrl = 'https://server.org/',
    bool Function()? isCancelled,
  }) => uploader.uploadOneSubmission(
    upload ?? instance(),
    deviceId: 'collect:1',
    overrideUrl: overrideUrl,
    serverUrl: serverUrl,
    isCancelled: isCancelled,
  );

  Matcher failsWith(String message) => throwsA(
    isA<FormUploadException>().having((e) => e.message, 'message', message),
  );

  group('submission URL', () {
    test('is the server URL + /submission with the device id', () async {
      expect(await upload(), 'Success!');
      const url = 'https://server.org/submission?deviceID=collect%3A1';
      expect(http.heads.single.toString(), url);
      expect(http.uploads.single.uri.toString(), url);
    });

    test('strips only one trailing slash from the server URL', () async {
      await upload(serverUrl: 'https://server.org//');
      expect(
        http.heads.single.toString(),
        'https://server.org//submission?deviceID=collect%3A1',
      );
    });

    test("is the form's submission URL, trimmed", () async {
      await upload(upload: instance(submissionUri: ' https://f.org/s?a=b '));
      expect(
        http.heads.single.toString(),
        'https://f.org/s?a=b&deviceID=collect%3A1',
      );
    });

    test('is the override URL first', () async {
      await upload(
        upload: instance(submissionUri: 'https://f.org/s'),
        overrideUrl: 'https://o.org/s',
      );
      expect(
        http.heads.single.toString(),
        'https://o.org/s?deviceID=collect%3A1',
      );
    });

    test('must have a host', () async {
      await expectLater(
        upload(overrideUrl: 'blah'),
        failsWith('Error:  Host name may not be null'),
      );
    });

    test('must be a valid URI', () async {
      await expectLater(
        upload(overrideUrl: 'https://o.org/a b'),
        failsWith('Sorry, invalid URL!'),
      );
    });
  });

  group('HEAD request', () {
    test('204 with Accept-Content-Length sets the split size', () async {
      http.onHead = (_) async => HttpHeadResult(
        204,
        ListCaseInsensitiveHeaders([
          ('x-openrosa-accept-content-length', '1234'),
        ]),
      );
      await upload();
      expect(http.uploads.single.contentLength, 1234);
    });

    test('an unparseable Accept-Content-Length keeps 10 MB', () async {
      http.onHead = (_) async => HttpHeadResult(
        204,
        ListCaseInsensitiveHeaders([
          (OpenRosaConstants.acceptContentLengthHeader, ' 12'),
        ]),
      );
      await upload();
      expect(http.uploads.single.contentLength, 10000000);
    });

    test('401 asks for credentials', () async {
      http.onHead = (_) async =>
          const HttpHeadResult(401, CaseInsensitiveEmptyHeaders());
      await expectLater(
        upload(),
        throwsA(
          isA<FormUploadAuthRequestedException>()
              .having(
                (e) => e.message,
                'message',
                'Invalid username or password for server: server.org',
              )
              .having(
                (e) => e.authRequestingServer.toString(),
                'server',
                'https://server.org/submission?deviceID=collect%3A1',
              ),
        ),
      );
      expect(http.uploads, isEmpty);
    });

    test('other 2xx responses are not OpenRosa endpoints', () async {
      http.onHead = (_) async =>
          const HttpHeadResult(200, CaseInsensitiveEmptyHeaders());
      await expectLater(
        upload(),
        failsWith(
          'Failed to send to https://server.org/submission?deviceID=collect%3A1. '
          'Is this an OpenRosa submission endpoint? If you have a web proxy '
          'you may need to log in to your network.\n\n'
          'HEAD request result status code: 200',
        ),
      );
    });

    test('other responses (e.g. 404) still go on to POST', () async {
      http.onHead = (_) async =>
          const HttpHeadResult(404, CaseInsensitiveEmptyHeaders());
      expect(await upload(), 'Success!');
    });

    test('failures are reported with their message', () async {
      http.onHead = (_) async => throw const OpenRosaHttpException('boom');
      await expectLater(upload(), failsWith('Error: boom'));
    });

    test('a same-host redirect is followed and remembered', () async {
      http.onHead = (_) async => HttpHeadResult(
        204,
        ListCaseInsensitiveHeaders([
          ('Location', 'https%3A%2F%2FSERVER.org%2Fv2%2Fsubmission'),
        ]),
      );
      await upload();
      const redirected =
          'https://SERVER.org/v2/submission?deviceID=collect%3A1';
      expect(
        http.uploads.single.uri.toString(),
        redirected.replaceFirst('SERVER', 'server'),
      );

      await upload();
      expect(http.heads.length, 1, reason: 'the remap skips the HEAD');
      expect(http.uploads.length, 2);
      expect(http.uploads[1].uri, http.uploads[0].uri);
    });

    test('a redirect with a query keeps it', () async {
      http.onHead = (_) async => HttpHeadResult(
        204,
        ListCaseInsensitiveHeaders([('location', 'https://server.org/v2?x=1')]),
      );
      await upload();
      expect(http.uploads.single.uri.toString(), 'https://server.org/v2?x=1');
    });

    test('a redirect to another host is refused', () async {
      http.onHead = (_) async => HttpHeadResult(
        204,
        ListCaseInsensitiveHeaders([('Location', 'https://evil.org/s')]),
      );
      await expectLater(
        upload(),
        failsWith(
          'Error: https://server.org/submission?deviceID=collect%3A1 '
          'FormUploadException: Error: Unexpected redirection attempt to a '
          'different host: https://evil.org/s',
        ),
      );
    });
  });

  group('files', () {
    test('uploads the instance file and the other visible files', () async {
      await upload();
      final call = http.uploads.single;
      expect(call.submissionFile.name, 'form_2024.xml');
      expect(call.files.map((f) => f.name), ['a.jpg']);
    });

    test('uploads submission.xml instead of the instance file', () async {
      await upload(
        upload: instance(
          files: [
            file('form_2024.xml'),
            file('submission.xml'),
            file('a.jpg.enc'),
            file('a.jpg'),
          ],
        ),
      );
      final call = http.uploads.single;
      expect(call.submissionFile.name, 'submission.xml');
      expect(call.files.map((f) => f.name), ['a.jpg.enc', 'a.jpg']);
    });

    test('fails without the instance file', () async {
      await expectLater(
        upload(upload: instance(files: [file('a.jpg')])),
        failsWith('Error: instance XML file does not exist!'),
      );
    });
  });

  group('POST result', () {
    void respond(int code, [String body = '', String reason = 'Reason']) =>
        http.onUpload = (_) async => HttpPostResult(body, code, reason);

    test('202 without a message returns null', () async {
      respond(202);
      expect(await upload(), isNull);
    });

    test('200 is a network login failure', () async {
      respond(200, okResponse);
      await expectLater(
        upload(),
        failsWith('Error:  Error: Network login failure? Again?'),
      );
    });

    test('401 reports the reason phrase', () async {
      respond(401, okResponse, 'Unauthorized');
      await expectLater(
        upload(),
        failsWith(
          'Error: Unauthorized (401) at '
          'https://server.org/submission?deviceID=collect%3A1',
        ),
      );
    });

    test("other failures report the server's message", () async {
      respond(500, okResponse);
      await expectLater(upload(), failsWith('Error: Success!'));
    });

    test('400 asks to check the form accepts submissions', () async {
      respond(400);
      await expectLater(
        upload(),
        failsWith(
          'Failed to upload. Please make sure the form is configured to '
          'accept submissions on the server',
        ),
      );
    });

    test('other failures report the reason phrase', () async {
      respond(503, 'down', 'Service Unavailable');
      await expectLater(
        upload(),
        failsWith(
          'Error: Service Unavailable (503) at '
          'https://server.org/submission?deviceID=collect%3A1',
        ),
      );
    });

    test('exceptions are reported with their message', () async {
      http.onUpload = (_) async => throw const OpenRosaHttpException('reset');
      await expectLater(upload(), failsWith('reset'));
    });
  });

  group('cancellation', () {
    test('before starting', () async {
      await expectLater(
        upload(isCancelled: () => true),
        throwsA(isA<FormUploadInterruptedException>()),
      );
      expect(http.heads, isEmpty);
    });

    test('during the upload', () async {
      var cancelled = false;
      http.onUpload = (_) async {
        cancelled = true;
        throw const UploadCancelledException();
      };
      await expectLater(
        upload(isCancelled: () => cancelled),
        throwsA(isA<FormUploadInterruptedException>()),
      );
    });
  });

  test('end to end through HttpClientConnection', () async {
    final server = MockWebServer('https://server.org')
      ..enqueue(
        MockResponse(
          code: 204,
          headers: {'x-openrosa-accept-content-length': '10'},
        ),
      )
      ..enqueue(MockResponse(code: 201))
      ..enqueue(MockResponse(code: 201, body: okResponse));
    final connection = HttpClientConnection(
      client: server.client,
      fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
      userAgent: 'test',
    );
    final message =
        await OpenRosaInstanceUploader(
          connection,
          StubWebCredentialsProvider(),
        ).uploadOneSubmission(
          InstanceUpload(
            instanceFileName: 'i.xml',
            files: [
              file('i.xml', '<data/>'),
              file('a.jpg', 'aaaa'),
              file('b.png', 'bbbb'),
            ],
          ),
          serverUrl: 'https://server.org',
          deviceId: 'd',
        );
    expect(message, 'Success!');
    expect(server.requestCount, 3);
    expect(server.takeRequest().method, 'HEAD');
    final first = splitMultiPart(server.takeRequest());
    expect(first.length, 3);
    expect(first[1][2], 'Content-Type: image/jpeg');
    expect(first[2][1], contains('*isIncomplete*'));
    final second = splitMultiPart(server.takeRequest());
    expect(second.length, 2);
    expect(second[1][2], 'Content-Type: image/png');
  });
}
