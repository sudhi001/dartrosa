// Port of Collect's OpenRosaClientTest (Mockito mocks replaced by fakes).
import 'package:dartrosa/javarosa.dart' show KElement;
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

final class FakeParser implements OpenRosaResponseParser {
  List<FormListItem>? formList;
  List<MediaFile>? manifest;
  List<EntityIntegrity>? integrity;

  @override
  List<FormListItem>? parseFormList(KElement? document) => formList;

  @override
  List<MediaFile>? parseManifest(KElement? document) => manifest;

  @override
  List<EntityIntegrity>? parseIntegrityResponse(KElement? document) =>
      integrity;
}

const response = '''
<xforms xmlns="http://openrosa.org/xforms/xformsList">
<xform><formID>one</formID>
<name>The First Form</name>
<majorMinorVersion></majorMinorVersion>
<version></version>
<hash>md5:b71c92bec48730119eab982044a8adff</hash>
<downloadUrl>https://example.com/formXml?formId=one</downloadUrl>
</xform>
<xform><formID>two</formID>
<name>The Second Form</name>
<majorMinorVersion></majorMinorVersion>
<version></version>
<hash>md5:4428adffbbec48771c9230119eab9820</hash>
<downloadUrl>https://example.com/formXml?formId=two</downloadUrl>
</xform>
</xforms>
''';

void main() {
  late FakeHttpInterface httpInterface;
  late FakeParser responseParser;

  setUp(() {
    httpInterface = FakeHttpInterface();
    responseParser = FakeParser();
  });

  OpenRosaClient client([String url = 'http://blah.com']) => OpenRosaClient(
    url,
    httpInterface,
    StubWebCredentialsProvider(),
    openRosaResponseParser: responseParser,
    deviceId: 'myDeviceId',
  );

  void returns(HttpGetResult Function() result) =>
      httpInterface.onGet = (_) async => result();

  void throws(Exception e) => httpInterface.onGet = (_) async => throw e;

  test('fetchFormList removes trailing slashes from url', () async {
    returns(() => getResult(response, openRosaHeaders, '', 200));
    responseParser.formList = [];
    await client('http://blah.com///').fetchFormList();
    expect(
      httpInterface.gets.single.uri,
      Uri.parse('http://blah.com/formList?deviceID=myDeviceId'),
    );
  });

  test('fetchFormList parses with the real parser', () async {
    returns(() => getResult(response, openRosaHeaders, '', 200));
    final forms = await OpenRosaClient(
      'http://blah.com',
      httpInterface,
      StubWebCredentialsProvider(),
      deviceId: 'myDeviceId',
    ).fetchFormList();
    expect(forms.map((f) => f.formId), ['one', 'two']);
    expect(httpInterface.gets.single.contentType, 'text/xml');
  });

  test(
    'fetchFormList when there is an UnknownHostException throws Unreachable',
    () async {
      throws(const UnknownHostException());
      await expectLater(
        client().fetchFormList(),
        throwsA(
          isA<FormSourceUnreachable>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test(
    'fetchFormList when there is an SSLException throws SecurityError',
    () async {
      throws(const SslException());
      await expectLater(
        client().fetchFormList(),
        throwsA(
          isA<FormSourceSecurityError>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test('fetchFormList when there is a timeout throws FetchError', () async {
    throws(const OpenRosaHttpException('SocketTimeoutException'));
    await expectLater(
      client().fetchFormList(),
      throwsA(isA<FormSourceFetchError>()),
    );
  });

  test('fetchFormList when there is a 404 throws Unreachable', () async {
    returns(() => getResult(null, {}, 'hash', 404));
    await expectLater(
      client().fetchFormList(),
      throwsA(
        isA<FormSourceUnreachable>().having(
          (e) => e.serverUrl,
          'serverUrl',
          'http://blah.com',
        ),
      ),
    );
  });

  test('fetchFormList when there is a 401 throws AuthRequired', () async {
    returns(() => getResult(null, {}, 'hash', 401));
    await expectLater(
      client().fetchFormList(),
      throwsA(isA<FormSourceAuthRequired>()),
    );
  });

  test(
    'fetchFormList when there is a server error throws ServerError',
    () async {
      returns(() => getResult(null, {}, 'hash', 500));
      await expectLater(
        client().fetchFormList(),
        throwsA(
          isA<FormSourceServerError>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.serverUrl, 'serverUrl', 'http://blah.com'),
        ),
      );
    },
  );

  test(
    'fetchFormList when OpenRosa response, when parser fails, throws ParseError',
    () async {
      returns(() => getResult('<xml></xml>', openRosaHeaders, 'hash', 200));
      responseParser.formList = null;
      await expectLater(
        client().fetchFormList(),
        throwsA(
          isA<FormSourceParseError>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test(
    'fetchFormList when response has no OpenRosa header throws ServerNotOpenRosaError',
    () async {
      returns(() => getResult(response, {}, '', 200));
      await expectLater(
        client('http://blah.com///').fetchFormList(),
        throwsA(isA<FormSourceServerNotOpenRosaError>()),
      );
    },
  );

  test('fetchFormList when the XML is malformed throws FetchError', () async {
    returns(() => getResult('<xforms', openRosaHeaders, '', 200));
    await expectLater(
      client().fetchFormList(),
      throwsA(isA<FormSourceFetchError>()),
    );
  });

  test('fetchManifest returns null for a null url', () async {
    expect(await client().fetchManifest(null), isNull);
  });

  test('fetchManifest returns the files and the document hash', () async {
    returns(() => getResult('<manifest/>', openRosaHeaders, 'abc', 200));
    responseParser.manifest = [
      const MediaFile(filename: 'a.png', hash: 'h', downloadUrl: 'u'),
    ];
    final manifest = await client().fetchManifest('http://blah.com/manifest');
    expect(manifest!.hash, 'abc');
    expect(manifest.mediaFiles.single.filename, 'a.png');
    expect(
      httpInterface.gets.single.uri.toString(),
      'http://blah.com/manifest?deviceID=myDeviceId',
    );
  });

  test(
    'fetchManifest when there is an UnknownHostException throws Unreachable',
    () async {
      throws(const UnknownHostException());
      await expectLater(
        client().fetchManifest('http://blah.com/manifest'),
        throwsA(
          isA<FormSourceUnreachable>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test(
    'fetchManifest when there is a server error throws ServerError',
    () async {
      returns(() => getResult(null, {}, 'hash', 503));
      await expectLater(
        client().fetchManifest('http://blah.com/manifest'),
        throwsA(
          isA<FormSourceServerError>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.serverUrl, 'serverUrl', 'http://blah.com'),
        ),
      );
    },
  );

  test(
    'fetchManifest when OpenRosa response, when parser fails, throws ParseError',
    () async {
      returns(() => getResult('<xml></xml>', openRosaHeaders, 'hash', 200));
      responseParser.manifest = null;
      await expectLater(
        client().fetchManifest('http://blah.com/manifest'),
        throwsA(
          isA<FormSourceParseError>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test('fetchManifest when not OpenRosa response throws ParseError', () async {
    returns(() => getResult('<xml></xml>', {}, 'hash', 200));
    await expectLater(
      client().fetchManifest('http://blah.com/manifest'),
      throwsA(
        isA<FormSourceParseError>().having(
          (e) => e.serverUrl,
          'serverUrl',
          'http://blah.com',
        ),
      ),
    );
  });

  test('fetchForm when there is a server error throws ServerError', () async {
    returns(() => getResult(null, {}, 'hash', 500));
    await expectLater(
      client().fetchForm('http://blah.com/form'),
      throwsA(
        isA<FormSourceServerError>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.serverUrl, 'serverUrl', 'http://blah.com'),
      ),
    );
    expect(httpInterface.gets.single.contentType, isNull);
  });

  test('fetchForm returns the body', () async {
    returns(() => getResult('<h:html/>', {}, '', 200));
    final stream = await client().fetchForm('http://blah.com/form');
    expect(
      String.fromCharCodes(await stream.expand((c) => c).toList()),
      '<h:html/>',
    );
  });

  test(
    'fetchMediaFile when there is a server error throws ServerError',
    () async {
      returns(() => getResult(null, {}, 'hash', 500));
      await expectLater(
        client().fetchMediaFile('http://blah.com/mediaFile'),
        throwsA(
          isA<FormSourceServerError>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.serverUrl, 'serverUrl', 'http://blah.com'),
        ),
      );
    },
  );

  test('fetchDeletedStates sends the ids and returns the states', () async {
    returns(() => getResult('<data/>', openRosaHeaders, 'hash', 200));
    responseParser.integrity = [
      const EntityIntegrity('1', deleted: true),
      const EntityIntegrity('2', deleted: false),
    ];
    final states = await client().fetchDeletedStates(
      'http://blah.com/integrity',
      ['1', '2'],
    );
    expect(states, [('1', true), ('2', false)]);
    expect(
      httpInterface.gets.single.uri.toString(),
      'http://blah.com/integrity?id=1%2C2&deviceID=myDeviceId',
    );
  });

  test(
    'fetchDeletedStates when not OpenRosa response throws ParseError',
    () async {
      returns(() => getResult('<xml></xml>', {}, 'hash', 200));
      responseParser.integrity = [];
      await expectLater(
        client().fetchDeletedStates('http://blah.com/integrity', [
          '1',
          '2',
          '3',
        ]),
        throwsA(
          isA<FormSourceParseError>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test(
    'fetchDeletedStates when OpenRosa response, when parser fails, throws ParseError',
    () async {
      returns(() => getResult('<xml></xml>', openRosaHeaders, 'hash', 200));
      responseParser.integrity = null;
      await expectLater(
        client().fetchDeletedStates('http://blah.com/integrity', [
          '1',
          '2',
          '3',
        ]),
        throwsA(isA<FormSourceParseError>()),
      );
    },
  );

  test(
    'fetchDeletedStates when there is an UnknownHostException throws Unreachable',
    () async {
      throws(const UnknownHostException());
      await expectLater(
        client().fetchDeletedStates('http://blah.com/integrity', ['1']),
        throwsA(isA<FormSourceUnreachable>()),
      );
    },
  );

  test(
    'fetchDeletedStates when there is a timeout throws FetchError',
    () async {
      throws(const OpenRosaHttpException('timeout'));
      await expectLater(
        client().fetchDeletedStates('http://blah.com/integrity', ['1']),
        throwsA(isA<FormSourceFetchError>()),
      );
    },
  );

  test(
    'fetchDeletedStates when there is an SSLException throws SecurityError',
    () async {
      throws(const SslException());
      await expectLater(
        client().fetchDeletedStates('http://blah.com/integrity', ['1']),
        throwsA(
          isA<FormSourceSecurityError>().having(
            (e) => e.serverUrl,
            'serverUrl',
            'http://blah.com',
          ),
        ),
      );
    },
  );

  test('serverUrl and credentials provider can be changed', () async {
    returns(() => getResult(response, openRosaHeaders, '', 200));
    responseParser.formList = [];
    final c = client()..serverUrl = 'http://other.org/';
    final credentials = _FixedCredentials(const HttpCredentials('u', 'p'));
    c.webCredentialsProvider = credentials;
    await c.fetchFormList();
    expect(
      httpInterface.gets.single.uri.toString(),
      'http://other.org/formList?deviceID=myDeviceId',
    );
    expect(
      httpInterface.gets.single.credentials,
      const HttpCredentials('u', 'p'),
    );
  });

  group('exception classification of package:http errors', () {
    test('failed host lookups are unknown hosts', () {
      expect(
        isUnknownHostException(
          Exception(
            "ClientException with SocketException: Failed host lookup: 'x'",
          ),
        ),
        isTrue,
      );
    });

    test('TLS failures are SSL errors', () {
      expect(
        isSslException(
          Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED'),
        ),
        isTrue,
      );
      expect(isSslException(Exception('Connection refused')), isFalse);
    });
  });
}

final class _FixedCredentials implements WebCredentialsProvider {
  _FixedCredentials(this.credentials);

  final HttpCredentialsInterface credentials;

  @override
  HttpCredentialsInterface getCredentials(Uri url) => credentials;
}
