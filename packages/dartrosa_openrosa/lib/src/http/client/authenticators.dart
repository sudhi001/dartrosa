import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../http_credentials.dart';

/// An authentication challenge from a `WWW-Authenticate` header.
final class AuthChallenge {
  /// Creates a challenge.
  const AuthChallenge(this.scheme, this.parameters);

  /// The scheme (e.g. `Digest`), as sent.
  final String scheme;

  /// The auth-params, with lower-case names.
  final Map<String, String> parameters;

  @override
  String toString() => 'AuthChallenge($scheme, $parameters)';
}

/// Parses the challenges in a `WWW-Authenticate` header value (several
/// headers joined with `,`, as `package:http` reports them).
List<AuthChallenge> parseAuthChallenges(String header) {
  final challenges = <AuthChallenge>[];
  var i = 0;
  String? scheme;
  var parameters = <String, String>{};

  void skipSpaceAndCommas() {
    while (i < header.length &&
        (header[i] == ' ' || header[i] == ',' || header[i] == '\t')) {
      i++;
    }
  }

  String token() {
    final start = i;
    while (i < header.length && !' \t,='.contains(header[i])) {
      i++;
    }
    return header.substring(start, i);
  }

  void finish() {
    if (scheme != null) challenges.add(AuthChallenge(scheme!, parameters));
    scheme = null;
    parameters = {};
  }

  while (true) {
    skipSpaceAndCommas();
    if (i >= header.length) break;
    final name = token();
    var j = i;
    while (j < header.length && (header[j] == ' ' || header[j] == '\t')) {
      j++;
    }
    final isParameter =
        scheme != null &&
        j < header.length &&
        header[j] == '=' &&
        // A token68 ends with '='s and is followed by a comma or the end.
        !RegExp(r'^=+\s*(,|$)').hasMatch(header.substring(j));
    if (!isParameter) {
      if (scheme != null && j < header.length && header[j] == '=') {
        // token68 (e.g. Basic's or Negotiate's): skip it.
        i = j;
        while (i < header.length && header[i] == '=') {
          i++;
        }
        continue;
      }
      finish();
      scheme = name;
      continue;
    }
    i = j + 1;
    while (i < header.length && (header[i] == ' ' || header[i] == '\t')) {
      i++;
    }
    String value;
    if (i < header.length && header[i] == '"') {
      i++;
      final out = StringBuffer();
      while (i < header.length && header[i] != '"') {
        if (header[i] == r'\' && i + 1 < header.length) i++;
        out.write(header[i]);
        i++;
      }
      i++; // closing quote
      value = out.toString();
    } else {
      final start = i;
      while (i < header.length && header[i] != ',') {
        i++;
      }
      value = header.substring(start, i).trim();
    }
    parameters[name.toLowerCase()] = value;
  }
  finish();
  return challenges;
}

/// Answers authentication challenges for one scheme and, once it has,
/// authorizes later requests proactively.
///
/// Mirrors the authenticators of `okhttp-digest` that Collect's
/// `OkHttpOpenRosaServerClientProvider` installs.
abstract interface class Authenticator {
  /// Whether to answer [challenge] for a request that carried
  /// [previousAuthorization] (an `Authorization` header or `null`).
  bool accepts(AuthChallenge challenge, String? previousAuthorization);

  /// Takes the parameters of [challenge] (which it [accepts]).
  void takeChallenge(AuthChallenge challenge);

  /// The `Authorization` header for a [method] request to [url].
  String authorize(String method, Uri url);
}

/// HTTP Basic authentication (`okhttp-digest`'s `BasicAuthenticator`).
final class BasicAuthenticator implements Authenticator {
  /// Creates an authenticator with [credentials].
  BasicAuthenticator(this.credentials);

  /// The credentials to send.
  final HttpCredentialsInterface credentials;

  @override
  bool accepts(AuthChallenge challenge, String? previousAuthorization) =>
      // Already failed with these credentials.
      !(previousAuthorization?.startsWith('Basic') ?? false);

  @override
  void takeChallenge(AuthChallenge challenge) {}

  @override
  String authorize(String method, Uri url) {
    // OkHttp's Credentials.basic encodes as ISO-8859-1.
    final bytes = latin1Bytes(
      '${credentials.username}:${credentials.password}',
    );
    return 'Basic ${base64.encode(bytes)}';
  }
}

/// HTTP Digest authentication, RFC 2617 (MD5 and MD5-sess, `qop=auth`)
/// (`okhttp-digest`'s `DigestAuthenticator`).
final class DigestAuthenticator implements Authenticator {
  /// Creates an authenticator with [credentials]; [random] makes client
  /// nonces.
  DigestAuthenticator(this.credentials, {Random? random})
    : _random = random ?? Random.secure();

  /// The credentials to authenticate with.
  final HttpCredentialsInterface credentials;

  final Random _random;
  Map<String, String> _challenge = const {};
  int _nonceCount = 0;
  String? _lastNonce;

  @override
  bool accepts(AuthChallenge challenge, String? previousAuthorization) {
    if (previousAuthorization == null ||
        !previousAuthorization.startsWith('Digest')) {
      return true;
    }
    // Retry with the same credentials only for a stale nonce.
    return challenge.parameters['stale']?.toLowerCase() == 'true';
  }

  @override
  void takeChallenge(AuthChallenge challenge) {
    _challenge = Map.of(challenge.parameters);
  }

  @override
  String authorize(String method, Uri url) {
    final realm = _challenge['realm'] ?? '';
    final nonce = _challenge['nonce'] ?? '';
    final opaque = _challenge['opaque'];
    final algorithm = _challenge['algorithm'];
    final qops = (_challenge['qop'] ?? '')
        .split(',')
        .map((q) => q.trim().toLowerCase())
        .where((q) => q.isNotEmpty)
        .toList();
    final qop = qops.isEmpty
        ? null
        : qops.contains('auth')
        ? 'auth'
        : qops.first;
    if (nonce != _lastNonce) {
      _lastNonce = nonce;
      _nonceCount = 0;
    }
    _nonceCount++;
    final nc = _nonceCount.toRadixString(16).padLeft(8, '0');
    final cnonce = _cnonce();
    final uri = url.hasQuery
        ? '${url.path.isEmpty ? '/' : url.path}?${url.query}'
        : (url.path.isEmpty ? '/' : url.path);

    var ha1 = _md5('${credentials.username}:$realm:${credentials.password}');
    if (algorithm?.toLowerCase() == 'md5-sess') {
      ha1 = _md5('$ha1:$nonce:$cnonce');
    }
    final ha2 = _md5('$method:$uri');
    final response = qop == null
        ? _md5('$ha1:$nonce:$ha2')
        : _md5('$ha1:$nonce:$nc:$cnonce:$qop:$ha2');

    final parts = [
      'username="${_quote(credentials.username)}"',
      'realm="${_quote(realm)}"',
      'nonce="${_quote(nonce)}"',
      'uri="${_quote(uri)}"',
      'response="$response"',
      if (qop != null) ...['qop=$qop', 'nc=$nc', 'cnonce="$cnonce"'],
      if (algorithm != null) 'algorithm=$algorithm',
      if (opaque != null) 'opaque="${_quote(opaque)}"',
    ];
    return 'Digest ${parts.join(', ')}';
  }

  String _cnonce() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String _md5(String s) => md5.convert(latin1Bytes(s)).toString();

  static String _quote(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

/// [s] encoded as ISO-8859-1, unmappable characters becoming `?` (as
/// Java's `String.getBytes`).
List<int> latin1Bytes(String s) => [
  for (final rune in s.runes) rune > 0xFF ? 0x3F : rune,
];
