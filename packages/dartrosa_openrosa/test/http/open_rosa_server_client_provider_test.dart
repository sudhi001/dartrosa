// Port of Collect's OpenRosaServerClientProviderTest and
// OkHttpOpenRosaServerClientProviderTest.
import 'dart:math';

import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../support/mock_web_server.dart';

const _digestChallenge =
    'Digest realm="ODK Aggregate", qop="auth", '
    'nonce="MTU2NTA4MjEzODI4OTpmMjc4MDM5N2YxZTJiNDRiNjNiYTBiMThiOWQ4ZTlkMg=="';

void enqueueSuccess(MockWebServer server) => server.enqueue(MockResponse());

void enqueueBasicChallenge(MockWebServer server) => server.enqueue(
  MockResponse(
    code: 401,
    headers: {'www-authenticate': 'Basic realm="protected area"'},
    body: 'Please authenticate.',
  ),
);

void enqueueDigestChallenge(MockWebServer server) => server.enqueue(
  MockResponse(
    code: 401,
    headers: {'www-authenticate': _digestChallenge},
    body: 'Please authenticate.',
  ),
);

RequestFactory buildRequest(MockWebServer server, String path) =>
    () => http.Request('GET', server.url(path));

void main() {
  late MockWebServer mockWebServer;
  late OpenRosaServerClientProvider subject;

  setUp(() {
    mockWebServer = MockWebServer();
    subject = HttpOpenRosaServerClientProvider(
      mockWebServer.client,
      random: Random(1),
    );
  });

  test('sends OpenRosa headers', () async {
    enqueueSuccess(mockWebServer);
    await subject
        .get('http', 'Android', null)
        .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
    expect(
      mockWebServer.takeRequest().header(OpenRosaConstants.versionHeader),
      '1.0',
    );
  });

  test('sends date header', () async {
    enqueueSuccess(mockWebServer);
    await subject
        .get('http', 'Android', null)
        .makeRequest(
          buildRequest(mockWebServer, ''),
          DateTime.utc(2019, 8, 6, 15, 4, 9),
        );
    // SimpleDateFormat("E, dd MMM yyyy hh:mm:ss zz"): a 12-hour clock.
    expect(
      mockWebServer.takeRequest().header('Date'),
      'Tue, 06 Aug 2019 03:04:09 GMT',
    );
  });

  test('date header formats midnight as 12', () {
    expect(
      httpHeaderDate(DateTime.utc(2026, 10, 4)),
      'Sun, 04 Oct 2026 12:00:00 GMT',
    );
  });

  test(
    'sends accepts gzip header',
    () {},
    skip:
        'Accept-Encoding is set by the transport (dart:io, browsers), which '
        'also decompresses.',
  );

  test(
    'with credentials, when basic challenge received, when http, does not retry with credentials',
    () async {
      enqueueBasicChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      final response = await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      expect(mockWebServer.requestCount, 1);
      expect(response.statusCode, 401);
    },
  );

  test(
    'with credentials, when basic challenge received, when https, retries with credentials',
    () async {
      enqueueBasicChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('https', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      expect(mockWebServer.requestCount, 2);
      mockWebServer.takeRequest();
      expect(
        mockWebServer.takeRequest().header('Authorization'),
        'Basic dXNlcjpwYXNz',
      );
    },
  );

  test(
    'with credentials, when digest challenge received, retries with credentials',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      expect(mockWebServer.requestCount, 2);
      mockWebServer.takeRequest();
      expect(
        mockWebServer.takeRequest().header('Authorization'),
        startsWith('Digest'),
      );
    },
  );

  test(
    'with credentials, when digest challenge received, when https, retries with credentials',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('https', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      expect(mockWebServer.requestCount, 2);
      mockWebServer.takeRequest();
      expect(
        mockWebServer.takeRequest().header('Authorization'),
        startsWith('Digest'),
      );
    },
  );

  test(
    'with credentials, once basic challenged, when https, proactively sends credentials',
    () async {
      enqueueBasicChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      enqueueSuccess(mockWebServer);
      final client = subject.get(
        'https',
        'Android',
        HttpCredentials('user', 'pass'),
      );
      await client.makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await client.makeRequest(
        buildRequest(mockWebServer, '/different'),
        DateTime.now(),
      );
      expect(mockWebServer.requestCount, 3);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      expect(
        mockWebServer.takeRequest().header('Authorization'),
        'Basic dXNlcjpwYXNz',
      );
    },
  );

  test(
    'with credentials, once digest challenged, proactively sends credentials',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      enqueueSuccess(mockWebServer);
      final client = subject.get(
        'http',
        'Android',
        HttpCredentials('user', 'pass'),
      );
      await client.makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await client.makeRequest(
        buildRequest(mockWebServer, '/different'),
        DateTime.now(),
      );
      expect(mockWebServer.requestCount, 3);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      final authorization = mockWebServer.takeRequest().header(
        'Authorization',
      )!;
      expect(authorization, startsWith('Digest'));
      expect(authorization, contains('uri="/different"'));
      expect(authorization, contains('nc=00000002'));
    },
  );

  test(
    'with credentials, once digest challenged, when https, proactively sends credentials',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      enqueueSuccess(mockWebServer);
      final client = subject.get(
        'https',
        'Android',
        HttpCredentials('user', 'pass'),
      );
      await client.makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await client.makeRequest(
        buildRequest(mockWebServer, '/different'),
        DateTime.now(),
      );
      expect(mockWebServer.requestCount, 3);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      expect(
        mockWebServer.takeRequest().header('Authorization'),
        startsWith('Digest'),
      );
    },
  );

  test('authentication is cached between instances', () async {
    enqueueDigestChallenge(mockWebServer);
    enqueueSuccess(mockWebServer);
    enqueueSuccess(mockWebServer);
    await subject
        .get('http', 'Android', HttpCredentials('user', 'pass'))
        .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
    await subject
        .get('http', 'Android', HttpCredentials('user', 'pass'))
        .makeRequest(buildRequest(mockWebServer, '/different'), DateTime.now());
    expect(mockWebServer.requestCount, 3);
    mockWebServer
      ..takeRequest()
      ..takeRequest();
    expect(
      mockWebServer.takeRequest().header('Authorization'),
      startsWith('Digest'),
    );
  });

  test(
    'when using different credentials, authentication is not cached between instances',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await subject
          .get('http', 'Android', HttpCredentials('new-user', 'pass'))
          .makeRequest(
            buildRequest(mockWebServer, '/different'),
            DateTime.now(),
          );
      expect(mockWebServer.requestCount, 4);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      expect(mockWebServer.takeRequest().header('Authorization'), isNull);
    },
  );

  test(
    'when using null and then non-null credentials, authentication is not cached between instances',
    () async {
      enqueueSuccess(mockWebServer);
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('http', 'Android', null)
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await subject
          .get('http', 'Android', HttpCredentials('new-user', 'pass'))
          .makeRequest(
            buildRequest(mockWebServer, '/different'),
            DateTime.now(),
          );
      expect(mockWebServer.requestCount, 3);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      expect(mockWebServer.takeRequest().header('Authorization'), isNotNull);
    },
  );

  test(
    'when connecting to different hosts, authentication is not cached between instances',
    () async {
      final host1 = MockWebServer('http://host1:8080');
      final host2 = MockWebServer('http://host2:8080');
      final provider = HttpOpenRosaServerClientProvider(
        routingClient([host1, host2]),
      );
      enqueueDigestChallenge(host1);
      enqueueSuccess(host1);
      enqueueDigestChallenge(host2);
      enqueueSuccess(host2);
      await provider
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(host1, ''), DateTime.now());
      await provider
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(host2, ''), DateTime.now());
      expect(host2.requestCount, 2);
      expect(host2.takeRequest().header('Authorization'), isNull);
    },
  );

  test(
    'when using https then http, does not respond to basic auth challenges in second instance',
    () async {
      enqueueDigestChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      enqueueBasicChallenge(mockWebServer);
      enqueueSuccess(mockWebServer);
      await subject
          .get('https', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      expect(mockWebServer.requestCount, 3);
      mockWebServer
        ..takeRequest()
        ..takeRequest();
      expect(mockWebServer.takeRequest().header('Authorization'), isNull);
    },
  );

  test(
    'when last request set cookies, next request does not send them',
    () async {
      mockWebServer.enqueue(MockResponse(headers: {'set-cookie': 'blah=blah'}));
      enqueueSuccess(mockWebServer);
      await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      await subject
          .get('http', 'Android', HttpCredentials('user', 'pass'))
          .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
      mockWebServer.takeRequest();
      expect(mockWebServer.takeRequest().header('Cookie'), isNull);
    },
  );

  test('different credentials have different instances', () {
    final instance1 = subject.get(
      'http',
      'Android',
      HttpCredentials('user', 'pass'),
    );
    final instance2 = subject.get(
      'http',
      'Android',
      HttpCredentials('other', 'pass'),
    );
    final instance3 = subject.get(
      'http',
      'Android',
      HttpCredentials('user', 'pass'),
    );
    expect(identical(instance1, instance2), isFalse);
    expect(identical(instance1, instance3), isTrue);
  });

  test('wrong credentials are not retried forever', () async {
    enqueueDigestChallenge(mockWebServer);
    enqueueDigestChallenge(mockWebServer);
    enqueueSuccess(mockWebServer);
    final response = await subject
        .get('http', 'Android', HttpCredentials('user', 'wrong'))
        .makeRequest(buildRequest(mockWebServer, ''), DateTime.now());
    expect(response.statusCode, 401);
    expect(mockWebServer.requestCount, 2);
  });

  group('Digest (not in Collect)', () {
    test('computes the RFC 2617 response', () {
      // RFC 2617 section 3.5's example.
      final authenticator =
          DigestAuthenticator(
            HttpCredentials('Mufasa', 'Circle Of Life'),
            cnonce: () => '0a4f113b',
          )..takeChallenge(
            parseAuthChallenges(
              'Digest realm="testrealm@host.com", qop="auth,auth-int", '
              'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", '
              'opaque="5ccc069c403ebaf9f0171e9517f40e41"',
            ).single,
          );
      final header = authenticator.authorize(
        'GET',
        Uri.parse('http://www.nowhere.org/dir/index.html'),
      );
      expect(header, startsWith('Digest username="Mufasa"'));
      expect(header, contains('uri="/dir/index.html"'));
      expect(header, contains('qop=auth, nc=00000001'));
      expect(header, contains('opaque="5ccc069c403ebaf9f0171e9517f40e41"'));
      expect(header, contains('response="6629fae49393a05397450978507c4ef1"'));
      expect(header, contains('cnonce="0a4f113b"'));
    });

    test('parses several challenges', () {
      final challenges = parseAuthChallenges(
        'Negotiate abc==, Basic realm="a, b", Digest realm="r", nonce=n1',
      );
      expect(challenges.map((c) => c.scheme), ['Negotiate', 'Basic', 'Digest']);
      expect(challenges[1].parameters, {'realm': 'a, b'});
      expect(challenges[2].parameters, {'realm': 'r', 'nonce': 'n1'});
    });
  });
}
