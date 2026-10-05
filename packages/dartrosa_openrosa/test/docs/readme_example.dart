// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim; run by
// api_examples_test.dart.
// ignore_for_file: avoid_print
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
