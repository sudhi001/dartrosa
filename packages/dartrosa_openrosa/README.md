# dartrosa_openrosa

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

Not on pub.dev yet; depend on it from Git, overriding its DartRosa
siblings to the same source:

```yaml
dependencies:
  dartrosa_openrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa_openrosa}
dependency_overrides:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
  dartrosa_encryption:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa_encryption}
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

- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect's
`open-rosa` module and uploader (Apache-2.0); see
[NOTICE.md](https://github.com/sudhi001/dartrosa/blob/main/NOTICE.md).
