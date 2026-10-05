// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run against a mock OpenRosa server so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;
import 'submit_guide_test.dart' show fakeCentral, formXml;

const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';

void main() {
  final requests = <http.Request>[];

  /// Runs [body] with `http.Client()` talking to a fake ODK Central.
  Future<void> withFakeCentral(Future<void> Function() body) =>
      http.runWithClient(body, () => fakeCentral(requests));

  setUp(requests.clear);

  test('library: dartrosa_openrosa', () async {
    final definition = await FormDefinition.parse(formXml);
    final form = definition.formDef;
    final submission =
        (definition.createSession().finalize() as FinalizeSuccess).submission;
    final files = {
      'photo.jpg': Uint8List.fromList([1, 2, 3]),
    };

    await withFakeCentral(() async {
      final connection = HttpClientConnection(
        client: http.Client(),
        fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
        userAgent: 'my-app/1.0',
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
        deviceId: 'my-app:device-1',
      );
      final forms = await client.fetchFormList();

      final uploader = OpenRosaInstanceUploader(connection, credentials);
      final message = await uploader.uploadOneSubmission(
        InstanceUpload.forForm(form, submission, attachments: files),
        serverUrl: serverUrl,
        deviceId: 'my-app:device-1',
      );

      expect(forms.single.formId, 'household');
      expect(message, 'Thanks!');
    });
  });

  test('OpenRosaClient', () async {
    final printed = <String>[];
    await withFakeCentral(() async {
      final connection = HttpClientConnection(
        client: http.Client(),
        fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
        userAgent: 'my-app/1.0',
      );
      final credentials = WebCredentialsUtils(
        InMemoryServerCredentialsSettings(serverUrl: serverUrl),
      );
      await runZonedPrints(printed, () async {
        final client = OpenRosaClient(
          serverUrl,
          connection,
          credentials,
          deviceId: 'my-app:device-1',
        );
        for (final form in await client.fetchFormList()) {
          final manifest = await client.fetchManifest(form.manifestUrl);
          print('${form.formId}: ${manifest?.mediaFiles.length} media files');
        }
      });
    });
    expect(printed, ['household: 1 media files']);
  });

  test('README example', () async {
    await withFakeCentral(() async {
      await expectLater(readme.main, prints(contains('household 3')));
    });
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints(contains('household v3')));
  });
}

/// Runs [body], adding what it prints to [printed] instead of printing it.
Future<void> runZonedPrints(
  List<String> printed,
  Future<void> Function() body,
) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) => printed.add(line),
  ),
);
