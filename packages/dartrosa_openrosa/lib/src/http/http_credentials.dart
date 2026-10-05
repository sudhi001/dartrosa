import 'package:meta/meta.dart';

/// A username and password.
///
/// Port of Collect's `HttpCredentialsInterface`.
abstract interface class HttpCredentialsInterface {
  /// The username.
  String get username;

  /// The password.
  String get password;
}

/// Credentials; `null`s become empty strings.
///
/// Port of Collect's `org.odk.collect.openrosa.http.HttpCredentials`.
@immutable
final class HttpCredentials implements HttpCredentialsInterface {
  /// Creates credentials.
  const HttpCredentials(String? username, String? password)
    : username = username ?? '',
      password = password ?? '';

  @override
  final String username;

  @override
  final String password;

  @override
  bool operator ==(Object other) =>
      other is HttpCredentialsInterface &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => (username + password).hashCode;

  @override
  String toString() => 'HttpCredentials($username, ****)';
}
