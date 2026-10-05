// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaXmlFetcherTest), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of Collect's OpenRosaXmlFetcherTest.
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  late FakeHttpInterface httpInterface;
  late OpenRosaXmlFetcher fetcher;

  setUp(() {
    httpInterface = FakeHttpInterface();
    fetcher = OpenRosaXmlFetcher(
      httpInterface,
      StubWebCredentialsProvider(),
      'myDeviceId',
    );
  });

  test('getXML returns result with 0 status', () async {
    httpInterface.onGet = (_) async =>
        getResult('<xml></xml>', openRosaHeaders, 'hash', 200);
    final result = await fetcher.getXml('http://testurl');
    expect(result.responseCode, 0);
    expect(result.isOpenRosaResponse, true);
    expect(result.errorMessage, isNull);
    expect(result.hash, 'hash');
    expect(result.doc!.name, 'xml');
  });

  test(
    'getXML when unsuccessful returns result with status and error message',
    () async {
      httpInterface.onGet = (_) async => getResult(null, {}, '', 500);
      final result = await fetcher.getXml('http://testurl');
      expect(result.responseCode, 500);
      expect(
        result.errorMessage,
        'getXML failed while accessing http://testurl with status code: 500',
      );
    },
  );

  test('fetch appends the device id and asks for the content type', () async {
    httpInterface.onGet = (_) async => getResult('', {}, '', 200);
    await fetcher.fetch('https://x.org/a?b=c%20d#frag', 'text/xml');
    final call = httpInterface.gets.single;
    expect(
      call.uri.toString(),
      'https://x.org/a?b=c%20d&deviceID=myDeviceId#frag',
    );
    expect(call.contentType, 'text/xml');
    expect(call.credentials, const HttpCredentials('', ''));
  });

  test('fetch rejects URLs without a host', () {
    expect(
      () => fetcher.fetch('file:///x', null),
      throwsA(
        isA<OpenRosaHttpException>().having(
          (e) => e.message,
          'message',
          'Invalid server URL (no hostname): file:///x',
        ),
      ),
    );
    expect(() => fetcher.fetch('blah', null), throwsFormatException);
    expect(
      () => fetcher.fetch('http://x.org/a b', null),
      throwsFormatException,
    );
  });
}
