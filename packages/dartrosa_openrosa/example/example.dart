// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Fetches an OpenRosa form list. A MockClient stands in for the server
// here; pass `http.Client()` and your server's URL in an app.
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const formList = '''
<xforms xmlns="http://openrosa.org/xforms/xformsList">
  <xform>
    <formID>household</formID>
    <name>Household survey</name>
    <version>3</version>
    <hash>md5:a0ba2f8b1fe3e6f9d1cb9d45cbb3c60c</hash>
    <downloadUrl>https://example.org/forms/household.xml</downloadUrl>
  </xform>
</xforms>
''';

Future<void> main() async {
  final server = MockClient(
    (request) async => http.Response(
      formList,
      200,
      headers: {
        'content-type': 'text/xml; charset=utf-8',
        'x-openrosa-version': '1.0',
      },
    ),
  );
  const serverUrl = 'https://example.org';
  final connection = HttpClientConnection(
    client: server,
    fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
    userAgent: 'dartrosa-example/1.0',
  );
  final credentials = WebCredentialsUtils(
    InMemoryServerCredentialsSettings(
      serverUrl: serverUrl,
      username: 'user',
      password: 'pass',
    ),
  );
  final client = OpenRosaClient(
    serverUrl,
    connection,
    credentials,
    deviceId: 'example:device',
  );

  for (final form in await client.fetchFormList()) {
    _log('${form.formId} v${form.version}: ${form.name} <${form.downloadUrl}>');
  }
}

// ignore: avoid_print
void _log(Object? message) => print(message);
