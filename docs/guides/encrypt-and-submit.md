# Download forms, encrypt and submit to ODK Central

**Audience:** developers connecting a DartRosa app to ODK Central, ODK
Aggregate, KoboToolbox or another OpenRosa server. **Type:** how-to
guide.

ODK servers and apps talk a small HTTP protocol called OpenRosa: the app
asks for the list of forms, downloads a form and its media files, and
later uploads each finished submission. `dartrosa_openrosa` is a port of
ODK Collect's OpenRosa client, and `dartrosa_encryption` of its
encryption, so submissions arrive exactly as Collect would send them,
encrypted ones included.

![Stages 2 and 3 of the form lifecycle: download, fill, finalize, encrypt, submit](../images/form-lifecycle.svg)

Every Dart snippet below is run against a fake server by
`packages/dartrosa_openrosa/test/docs/submit_guide_test.dart`.

## Before you start

* Add `dartrosa_openrosa` (it brings `dartrosa_encryption`) and
  `package:http` to your app: `dart pub add dartrosa_openrosa http` (or
  `flutter pub add`).
* The server URL. For ODK Central, create an App User in the project and
  use the URL from its QR code, shaped like
  `https://central.example.org/v1/key/<token>/projects/<id>`. For servers
  with accounts (ODK Aggregate, KoboToolbox), the server URL plus a
  username and password.

## 1. Connect

One connection serves the whole app. It sends Collect's headers and
handles Digest and Basic authentication:

```dart
const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';

final connection = HttpClientConnection(
  client: httpClient, // an http.Client
  fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
  userAgent: 'my-app/1.0',
);
final credentials = WebCredentialsUtils(
  // ODK Central app users and public links carry their token in the
  // URL; for a username and password, pass username: and password:.
  InMemoryServerCredentialsSettings(serverUrl: serverUrl),
);
final client = OpenRosaClient(
  serverUrl,
  connection,
  credentials,
  deviceId: 'my-app:device-1',
);
```

`InMemoryServerCredentialsSettings` keeps the credentials in memory;
implement `ServerCredentialsSettings` to keep them in your app's secure
storage.

## 2. Download forms and their media

```dart
for (final form in await client.fetchFormList()) {
  // form.formId, form.version and form.hash tell what changed.
  final xml = await utf8.decodeStream(
    await client.fetchForm(form.downloadUrl),
  );
  final manifest = await client.fetchManifest(form.manifestUrl);
  for (final file in manifest?.mediaFiles ?? const <MediaFile>[]) {
    // Skip files whose file.hash you already have.
    final bytes = await client.fetchMediaFile(file.downloadUrl);
```

Save the XML and the media files together (for example one folder per
form and version). [Show a form in a Flutter app](render-a-form-in-flutter.md)
reads such a folder.

## 3. Finalize, encrypt and upload

`InstanceUpload.forForm` prepares the upload. If the form has an
encryption key (a `base64RsaPublicKey` on its `<submission>`; in XLSForm,
the `public_key` setting, which ODK Central sets when you turn on
encryption), it encrypts the submission and its files first, so only the
holder of the private key can read them. The uploader then sends
everything as one or more `multipart/form-data` requests:

```dart
if (session.finalize() case FinalizeSuccess(:final submission)) {
  // Encrypted when the form has a base64RsaPublicKey, plain otherwise.
  final upload = InstanceUpload.forForm(
    definition.formDef,
    submission,
    attachments: {'photo.jpg': photoBytes}, // file name -> bytes
  );
  final uploader = OpenRosaInstanceUploader(connection, credentials);
  try {
    message = await uploader.uploadOneSubmission(
      upload,
      serverUrl: serverUrl,
      deviceId: 'my-app:device-1',
    );
  } on FormUploadAuthRequestedException {
    // Ask for a username and password, save them in the credentials
    // settings and try again.
  } on FormUploadException catch (e) {
    // Keep the submission and retry later; e.message says why.
```

`attachments` holds the files the submission refers to (photos,
recordings, signatures). `submission.attachments` lists their names: the
file names answered to media questions (as the Flutter renderer stores
captured files), in form order, leaving out answers to hidden questions.
Look up each name among the files your delegates saved
(the [tutorial](../tutorials/build-a-data-collection-app.md#8-finalize-and-encrypt)
does). Every file you pass is uploaded, as Collect uploads every file of
an instance's folder, so pass only those.
`uploadOneSubmission` returns the server's message, if it sent one, and
posts to the form's own submission URL when the form names one.

Keep a submission until its upload succeeds: phones are often offline
in the field.

## Encrypt without uploading

To send submissions some other way (a USB transfer, a different
protocol), encrypt them yourself:

```dart
final files = {'photo.jpg': photoBytes}; // file name -> bytes
final encrypted = encryptSubmission(
  utf8.encode(submission.xml),
  files,
  definition.formDef,
);
// null when the form is not encrypted. Otherwise send
// encrypted.manifestBytes as submission.xml, plus
// encrypted.encryptedFiles (submission.xml.enc, photo.jpg.enc).
```

The output is byte-compatible with ODK Collect's, so ODK Central and ODK
Briefcase decrypt it with the form's private key.

## Related

* [OpenRosa specification](https://docs.getodk.org/openrosa/)
* [dartrosa_openrosa README](../../packages/dartrosa_openrosa/README.md)
  and [dartrosa_encryption README](../../packages/dartrosa_encryption/README.md)
* [Save and resume drafts](save-and-resume-drafts.md)
* [STANDARDS.md](../STANDARDS.md#openrosa): what DartRosa implements of
  OpenRosa and how it is checked
