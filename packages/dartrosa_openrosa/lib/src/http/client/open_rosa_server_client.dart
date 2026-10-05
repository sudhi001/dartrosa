// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaServerClient, OpenRosaServerClientProvider,
//  OkHttpOpenRosaServerClientProvider, DispatchingAuthenticator), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:http/http.dart' as http;

import '../http_credentials.dart';
import '../open_rosa_constants.dart';
import 'authenticators.dart';

/// Builds a fresh request each time it's called (a request may be sent
/// more than once, e.g. to answer an authentication challenge).
typedef RequestFactory = http.BaseRequest Function();

/// Sends requests with Collect's headers and authentication.
///
/// Port of Collect's `OpenRosaServerClient`.
abstract interface class OpenRosaServerClient {
  /// Sends the request [request] builds, adding the `User-Agent`,
  /// `X-OpenRosa-Version` and `Date` ([currentTime]) headers and answering
  /// authentication challenges.
  Future<http.StreamedResponse> makeRequest(
    RequestFactory request,
    DateTime currentTime,
  );
}

/// Provides an [OpenRosaServerClient] per scheme and credentials.
///
/// Port of Collect's `OpenRosaServerClientProvider`.
abstract interface class OpenRosaServerClientProvider {
  /// The client for [scheme] requests with [credentials].
  OpenRosaServerClient get(
    String scheme,
    String userAgent,
    HttpCredentialsInterface? credentials,
  );
}

/// An [OpenRosaServerClientProvider] over a `package:http` [http.Client],
/// with Collect's authentication: Digest always, Basic only over HTTPS,
/// cached per host so that later requests authenticate proactively. A
/// client (and its authentication cache) is kept per scheme and
/// credentials.
///
/// Port of Collect's `OkHttpOpenRosaServerClientProvider` (with
/// `okhttp-digest`'s `DispatchingAuthenticator`,
/// `CachingAuthenticatorDecorator` and `AuthenticationCacheInterceptor`).
/// OkHttp's timeouts, HTTP cache, transparent gzip and redirects are left
/// to the [http.Client] (`dart:io` and browsers decompress and follow
/// redirects themselves).
final class HttpOpenRosaServerClientProvider
    implements OpenRosaServerClientProvider {
  /// Creates a provider sending through [baseClient]; [random] makes
  /// Digest client nonces.
  HttpOpenRosaServerClientProvider(this.baseClient, {Random? random})
    : _random = random;

  /// The client requests are sent with.
  final http.Client baseClient;

  final Random? _random;

  /// How many clients (scheme and credentials pairs, each with its
  /// authentication cache) are kept; the least recently used is dropped,
  /// so changed credentials don't accumulate (Collect keeps only the
  /// client of the last credentials).
  static const maxClients = 8;

  final Map<(String, HttpCredentialsInterface?), _Client> _clients = {};

  @override
  OpenRosaServerClient get(
    String scheme,
    String userAgent,
    HttpCredentialsInterface? credentials,
  ) {
    final key = (scheme, credentials);
    final existing = _clients.remove(key);
    if (existing != null) return _clients[key] = existing; // most recent
    final client = _clients[key] = _Client(
      baseClient,
      scheme,
      userAgent,
      credentials,
      _random,
    );
    if (_clients.length > maxClients) _clients.remove(_clients.keys.first);
    return client;
  }
}

final class _Client implements OpenRosaServerClient {
  _Client(
    this._base,
    this._scheme,
    this._userAgent,
    this._credentials,
    this._random,
  );

  static const _maxFollowUps = 20;

  final http.Client _base;
  final String _scheme;
  final String _userAgent;
  final HttpCredentialsInterface? _credentials;
  final Random? _random;
  final Map<String, Authenticator> _authCache = {};

  @override
  Future<http.StreamedResponse> makeRequest(
    RequestFactory request,
    DateTime currentTime,
  ) async {
    http.BaseRequest build(String? authorization) {
      final r = request();
      r.headers['User-Agent'] = _userAgent;
      r.headers[OpenRosaConstants.versionHeader] = '1.0';
      r.headers['Date'] = httpHeaderDate(currentTime);
      if (authorization != null) r.headers['Authorization'] = authorization;
      return r;
    }

    final first = request();
    final key = '${first.url.scheme}:${first.url.host}:${first.url.port}';
    final cached = _credentials == null ? null : _authCache[key];
    var authorization = cached?.authorize(first.method, first.url);
    var response = await _base.send(build(authorization));

    for (var i = 0; i < _maxFollowUps && response.statusCode == 401; i++) {
      // AuthenticationCacheInterceptor: a cached authenticator that fails
      // is forgotten.
      if (i == 0 && cached != null) _authCache.remove(key);
      final credentials = _credentials;
      if (credentials == null) break;
      final header = response.headers['www-authenticate'];
      if (header == null) break;
      final match = _dispatch(credentials, parseAuthChallenges(header), key);
      if (match == null) break;
      final (authenticator, challenge) = match;
      if (!authenticator.accepts(challenge, authorization)) break;
      authenticator.takeChallenge(challenge);
      authorization = authenticator.authorize(first.method, first.url);
      _authCache[key] = authenticator;
      await _discard(response);
      response = await _base.send(build(authorization));
    }
    return response;
  }

  (Authenticator, AuthChallenge)? _dispatch(
    HttpCredentialsInterface credentials,
    List<AuthChallenge> challenges,
    String key,
  ) {
    for (final challenge in challenges) {
      final scheme = challenge.scheme.toLowerCase();
      final existing = _authCache[key];
      if (scheme == 'digest') {
        return (
          existing is DigestAuthenticator
              ? existing
              : DigestAuthenticator(credentials, random: _random),
          challenge,
        );
      }
      if (scheme == 'basic' && _scheme.toLowerCase() == 'https') {
        return (
          existing is BasicAuthenticator
              ? existing
              : BasicAuthenticator(credentials),
          challenge,
        );
      }
    }
    return null;
  }
}

Future<void> _discard(http.StreamedResponse response) async {
  try {
    await response.stream.drain<void>();
  } on Exception {
    // Ignored, as Collect does.
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats [time] for the `Date` header as Collect does, with
/// `SimpleDateFormat("E, dd MMM yyyy hh:mm:ss zz", Locale.US)` in GMT —
/// including its 12-hour clock (`hh`) and no AM/PM marker.
String httpHeaderDate(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${_days[t.weekday - 1]}, ${two(t.day)} ${_months[t.month - 1]} '
      '${t.year.toString().padLeft(4, '0')} ${two(hour12)}:${two(t.minute)}:'
      '${two(t.second)} GMT';
}
