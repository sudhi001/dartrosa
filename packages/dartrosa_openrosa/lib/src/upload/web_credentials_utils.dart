import '../forms/open_rosa_xml_fetcher.dart';
import '../http/http_credentials.dart';

/// The project settings [WebCredentialsUtils] reads and writes.
abstract interface class ServerCredentialsSettings {
  /// The configured server URL.
  String? get serverUrl;

  /// The saved username.
  String? get username;

  /// The saved password.
  String? get password;

  /// Saves the username and password.
  void saveCredentials(String username, String password);
}

/// In-memory [ServerCredentialsSettings].
final class InMemoryServerCredentialsSettings
    implements ServerCredentialsSettings {
  /// Creates settings.
  InMemoryServerCredentialsSettings({
    this.serverUrl,
    this.username,
    this.password,
  });

  @override
  String? serverUrl;

  @override
  String? username;

  @override
  String? password;

  @override
  void saveCredentials(String username, String password) {
    this.username = username;
    this.password = password;
  }
}

/// Chooses the credentials for a URL: temporary per-host credentials if
/// there are any, else the saved ones for the configured server's host,
/// else empty credentials.
///
/// Port of Collect's `org.odk.collect.android.utilities.WebCredentialsUtils`.
/// Collect keeps the temporary credentials in a static map shared by all
/// instances; here each instance has its own (share an instance to share
/// them).
final class WebCredentialsUtils implements WebCredentialsProvider {
  /// Creates the utility over [settings].
  WebCredentialsUtils(this.settings);

  /// The project settings.
  final ServerCredentialsSettings settings;

  final Map<String?, HttpCredentialsInterface> _hostCredentials = {};

  /// Remembers temporary credentials for the host of [url] (ignored for an
  /// empty [username]).
  void saveCredentials(String url, String username, String password) {
    if (username.isEmpty) return;
    _hostCredentials[_host(url)] = HttpCredentials(username, password);
  }

  /// Saves [userName] and [password] to the settings.
  void saveCredentialsPreferences(String userName, String password) =>
      settings.saveCredentials(userName, password);

  /// Forgets the temporary credentials for the host of [url].
  void clearCredentials(String url) {
    if (url.isEmpty) return;
    final host = _host(url);
    if (host != null) _hostCredentials.remove(host);
  }

  /// Forgets all temporary credentials.
  void clearAllCredentials() => _hostCredentials.clear();

  /// The configured server URL.
  String? get serverUrlFromPreferences => settings.serverUrl;

  /// The saved password.
  String? get passwordFromPreferences => settings.password;

  /// The saved username.
  String? get userNameFromPreferences => settings.username;

  @override
  HttpCredentialsInterface getCredentials(Uri url) {
    final host = url.host;
    final serverPrefsUrl = serverUrlFromPreferences;
    final prefsServerHost = serverPrefsUrl == null
        ? null
        : _host(serverPrefsUrl);

    final hostCredentials = _hostCredentials[host];

    // URL host is the same as the host in preferences
    if (prefsServerHost != null &&
        prefsServerHost.toLowerCase() == host.toLowerCase()) {
      // Use the temporary credentials if they exist, otherwise use the
      // credentials saved to preferences
      return hostCredentials ??
          HttpCredentials(userNameFromPreferences, passwordFromPreferences);
    } else {
      return hostCredentials ?? const HttpCredentials('', '');
    }
  }

  /// Android's `Uri.parse(url).getHost()`: `null` without an authority.
  static String? _host(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return null;
    return uri.host;
  }
}
