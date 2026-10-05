# dartrosa_encryption

Encrypted ODK submissions for [DartRosa](https://github.com/sudhi001/dartrosa):
a port of ODK Collect's `EncryptionUtils`.

When a form's `<submission>` has a `base64RsaPublicKey`, the submission
XML and its attachments are encrypted with a random AES key (itself
RSA-OAEP encrypted with the form's key) and replaced by a plaintext
manifest carrying the encrypted key and an element signature. The output
is byte-compatible with what ODK Collect produces, so ODK Central and ODK
Briefcase decrypt it. Pure Dart (`pointycastle`), works on the web.

## Install

Not on pub.dev yet; depend on it from Git, overriding its DartRosa
siblings to the same source:

```yaml
dependencies:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
  dartrosa_encryption:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa_encryption}
dependency_overrides:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
```

## Example

```dart
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';

Future<void> main() async {
  final definition = await FormDefinition.parse(encryptedFormXml);
  final session = definition.createSession();
  // ... answer questions ...
  if (session.finalize() case FinalizeSuccess(:final submission)) {
    final encrypted = encryptSubmission(
      utf8.encode(submission.xml),
      {'photo.jpg': photoBytes}, // attachments: file name -> bytes
      definition.formDef,
    );
    if (encrypted != null) {
      // Upload encrypted.manifestBytes as xml_submission_file and
      // encrypted.encryptedFiles (submission.xml.enc, photo.jpg.enc).
    }
  }
}
```

`encryptSubmission` returns `null` for forms that aren't encrypted. See
[example/example.dart](example/example.dart) for a runnable program;
`dartrosa_openrosa`'s `InstanceUpload.forForm` does this automatically
when uploading.

## Documentation

- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect's
`EncryptionUtils` (Apache-2.0); see
[NOTICE.md](https://github.com/sudhi001/dartrosa/blob/main/NOTICE.md).
