# dartrosa_openrosa

[![pub package](https://img.shields.io/pub/v/dartrosa_openrosa.svg)](https://pub.dev/packages/dartrosa_openrosa)
[![pub points](https://img.shields.io/pub/points/dartrosa_openrosa)](https://pub.dev/packages/dartrosa_openrosa/score)
[![CI](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml/badge.svg)](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

An [OpenRosa](https://docs.getodk.org/openrosa/) server client for
[DartRosa](https://github.com/sudhi001/dartrosa) (ODK Central, KoboToolbox
and other OpenRosa servers). A port of ODK Collect's `open-rosa` module
and its OpenRosa instance uploader, over `package:http`, so it works on
the VM, in Flutter and on the web.

- `OpenRosaClient`: form list, manifests, form and media downloads,
  entity list integrity checks.
- `OpenRosaInstanceUploader`: `multipart/form-data` submission with
  `xml_submission_file`, split to respect the server's
  `X-OpenRosa-Accept-Content-Length`.
- `HttpClientConnection`: Collect's headers and Digest/Basic
  authentication; `WebCredentialsUtils` chooses the credentials.
- `InstanceUpload.forForm` turns a `FormSession` submission into an
  upload, encrypting it (with `dartrosa_encryption`) when the form asks.

## Install

```sh
dart pub add dartrosa_openrosa
```

## Example

```dart
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';
  final connection = HttpClientConnection(
    client: http.Client(),
    fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
    userAgent: 'my-app/1.0',
  );
  final credentials = WebCredentialsUtils(
    InMemoryServerCredentialsSettings(serverUrl: serverUrl),
  );
  final client = OpenRosaClient(
    serverUrl,
    connection,
    credentials,
    deviceId: 'my-app:device-1',
  );
  for (final form in await client.fetchFormList()) {
    print('${form.formId} ${form.version}: ${form.downloadUrl}');
  }

  // Uploading a finalized FormSession submission:
  // final uploader = OpenRosaInstanceUploader(connection, credentials);
  // await uploader.uploadOneSubmission(
  //   InstanceUpload.forForm(definition.formDef, submission),
  //   serverUrl: serverUrl,
  //   deviceId: 'my-app:device-1',
  // );
}
```

[example/example.dart](example/example.dart) runs the form-list fetch
against a mock server.

## Documentation

- [API reference](https://pub.dev/documentation/dartrosa_openrosa/latest/)
- [Documentation index](https://github.com/sudhi001/dartrosa/blob/main/docs/README.md)
- [Download forms, encrypt and submit](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/encrypt-and-submit.md)
- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect's
`open-rosa` module and uploader (Apache-2.0); see
[the licensing notes](https://github.com/sudhi001/dartrosa/blob/main/docs/legal/README.md).
