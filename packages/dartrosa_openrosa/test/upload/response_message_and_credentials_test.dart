// Tests of the ports of Collect's ResponseMessageParser and
// WebCredentialsUtils (including WebCredentialsUtilsTest).
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

void main() {
  group('ResponseMessageParser', () {
    test('reads the message of an OpenRosaResponse', () {
      final parser = ResponseMessageParser()
        ..setMessageResponse(
          '<OpenRosaResponse xmlns="http://openrosa.org/http/response">'
          '<message nature="submit_success">Thanks <b>a lot</b>!</message>'
          '</OpenRosaResponse>',
        );
      expect(parser.isValid, isTrue);
      expect(parser.messageResponse, 'Thanks a lot!');
    });

    test('is not valid without OpenRosaResponse or message', () {
      final parser = ResponseMessageParser()
        ..setMessageResponse('<message>hi</message>');
      expect(parser.isValid, isFalse);
      parser.setMessageResponse('<OpenRosaResponse/>');
      expect(parser.isValid, isFalse);
    });

    test('is not valid for malformed XML', () {
      final parser = ResponseMessageParser()
        ..setMessageResponse('OpenRosaResponse <message>');
      expect(parser.isValid, isFalse);
    });

    test('matches qualified names, as a non-namespace-aware DOM', () {
      final parser = ResponseMessageParser()
        ..setMessageResponse(
          '<or:OpenRosaResponse xmlns:or="urn:x"><or:message>a</or:message>'
          '<message>b</message></or:OpenRosaResponse>',
        );
      expect(parser.messageResponse, 'b');
    });
  });

  group('WebCredentialsUtils', () {
    late InMemoryServerCredentialsSettings settings;
    late WebCredentialsUtils utils;

    setUp(() {
      settings = InMemoryServerCredentialsSettings(
        serverUrl: 'https://server.org/v1/key/x',
        username: 'user',
        password: 'pass',
      );
      utils = WebCredentialsUtils(settings);
    });

    test('saveCredentialsPreferences should save new credentials', () {
      utils.saveCredentialsPreferences('username', 'password');
      expect(settings.username, 'username');
      expect(settings.password, 'password');
    });

    test('uses the saved credentials for the server host', () {
      expect(
        utils.getCredentials(Uri.parse('https://SERVER.org/formList')),
        const HttpCredentials('user', 'pass'),
      );
    });

    test('uses empty credentials for other hosts', () {
      expect(
        utils.getCredentials(Uri.parse('https://other.org/formList')),
        const HttpCredentials('', ''),
      );
    });

    test('temporary credentials win and can be cleared', () {
      utils
        ..saveCredentials('https://server.org', 'temp', 'p')
        ..saveCredentials('https://other.org/x', 'o', 'p')
        ..saveCredentials('https://ignored.org/x', '', 'p');
      expect(
        utils.getCredentials(Uri.parse('https://server.org/a')),
        const HttpCredentials('temp', 'p'),
      );
      expect(
        utils.getCredentials(Uri.parse('https://other.org/a')),
        const HttpCredentials('o', 'p'),
      );
      utils.clearCredentials('https://server.org/z');
      expect(
        utils.getCredentials(Uri.parse('https://server.org/a')),
        const HttpCredentials('user', 'pass'),
      );
      utils.clearAllCredentials();
      expect(
        utils.getCredentials(Uri.parse('https://other.org/a')),
        const HttpCredentials('', ''),
      );
    });
  });
}
