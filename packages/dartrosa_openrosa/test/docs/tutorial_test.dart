// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The download, encrypt and submit code of
// docs/tutorials/build-a-data-collection-app.md, run against a fake ODK
// Central so the tutorial can't rot (packages/dartrosa/test/docs checks
// that its snippets are here or in
// packages/dartrosa_flutter/test/docs/tutorial_test.dart).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'submit_guide_test.dart' show fakeCentral;

/// What the app keeps: forms with their media, drafts, files and the
/// outbox. This one lives in memory; a real app writes files under
/// getApplicationDocumentsDirectory() or uses a database.
class FormStore {
  /// Form id -> its XML and media files (file name -> bytes).
  final forms = <String, ({String xml, Map<String, Uint8List> media})>{};

  /// Draft id -> the instance XML from saveDraft().
  final drafts = <String, String>{};

  /// Photos, signatures and recordings, by file name.
  final files = <String, Uint8List>{};

  /// instanceID -> a finalized submission waiting to be sent.
  final outbox = <String, ({String formId, Submission submission})>{};
}

/// Serves a form's media files (jr://file-csv/villages.csv, ...) from
/// memory.
class StoredMediaResolver implements ResourceResolver {
  StoredMediaResolver(this.media);

  final Map<String, Uint8List> media;

  @override
  Future<Uint8List> read(String uri) async =>
      media[Uri.parse(uri).pathSegments.last] ??
      (throw ResourceNotFoundException(uri));
}

/// Parses the stored form [formId].
Future<FormDefinition> loadForm(FormStore store, String formId) {
  final form = store.forms[formId]!;
  return FormDefinition.parse(
    form.xml,
    config: DartRosaConfig(resolver: StoredMediaResolver(form.media)),
  );
}

/// Downloads the project's forms and their media files into [store].
Future<void> downloadForms(OpenRosaClient client, FormStore store) async {
  for (final form in await client.fetchFormList()) {
    final xml = await utf8.decodeStream(
      await client.fetchForm(form.downloadUrl),
    );
    final media = <String, Uint8List>{};
    final manifest = await client.fetchManifest(form.manifestUrl);
    for (final file in manifest?.mediaFiles ?? const <MediaFile>[]) {
      final chunks = await client.fetchMediaFile(file.downloadUrl);
      media[file.filename] = Uint8List.fromList(
        await chunks.expand((chunk) => chunk).toList(),
      );
    }
    store.forms[form.formId] = (xml: xml, media: media);
  }
}

/// The upload of a finalized submission: encrypted when the form has a
/// public key (ODK Central's encryption setting), plain otherwise.
Future<InstanceUpload> prepareUpload(
  FormStore store,
  String formId,
  Submission submission,
) async {
  final definition = await loadForm(store, formId);
  return InstanceUpload.forForm(
    definition.formDef,
    submission,
    attachments: {
      // The files your delegates saved that this submission names.
      for (final name in submission.attachments) name: ?store.files[name],
    },
  );
}

/// Sends every submission in the outbox. Failed ones stay there; returns
/// why they failed.
Future<List<String>> sendOutbox(
  FormStore store,
  OpenRosaInstanceUploader uploader,
  String serverUrl,
) async {
  final problems = <String>[];
  for (final MapEntry(key: id, value: (:formId, :submission))
      in store.outbox.entries.toList()) {
    try {
      final upload = await prepareUpload(store, formId, submission);
      await uploader.uploadOneSubmission(
        upload,
        serverUrl: serverUrl,
        deviceId: 'visit-app:device-1',
      );
      store.outbox.remove(id);
    } on FormUploadException catch (e) {
      // Offline, or refused by the server: keep it and try again later.
      problems.add(e.message);
    }
  }
  return problems;
}

void main() {
  test('download, fill, encrypt and send', () async {
    final requests = <http.Request>[];
    final httpClient = fakeCentral(requests);
    const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';

    final connection = HttpClientConnection(
      client: httpClient, // an http.Client
      fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
      userAgent: 'visit-app/1.0',
    );
    final credentials = WebCredentialsUtils(
      // The App User's URL from ODK Central carries its token.
      InMemoryServerCredentialsSettings(serverUrl: serverUrl),
    );
    final client = OpenRosaClient(
      serverUrl,
      connection,
      credentials,
      deviceId: 'visit-app:device-1',
    );
    final uploader = OpenRosaInstanceUploader(connection, credentials);

    final store = FormStore();
    await downloadForms(client, store);
    expect(store.forms.keys, ['household']);
    expect(store.forms['household']!.media.keys, ['towns.csv']);

    final session = (await loadForm(store, 'household')).createSession();
    final name = session.root.children.first as QuestionNode;
    session.answer(name.index, const StringValue('Amina'));
    final photo = session.root.children[1] as QuestionNode;
    session.answer(photo.index, const UncastValue('photo-1.jpg'));
    store.files['photo-1.jpg'] = Uint8List.fromList([1, 2, 3]);
    final submission = (session.finalize() as FinalizeSuccess).submission;
    store.outbox[submission.instanceId!] = (
      formId: 'household',
      submission: submission,
    );

    await sendOutbox(store, uploader, serverUrl);

    expect(store.outbox, isEmpty);
    final body = latin1.decode(requests.last.bodyBytes);
    expect(body, contains('submission.xml.enc'));
    expect(body, contains('photo-1.jpg.enc'));
    expect(body, isNot(contains('Amina')));
  });

  test('a failed upload stays in the outbox', () async {
    final httpClient = MockClient(
      (request) async => http.Response('', 500, headers: const {}),
    );
    const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';
    final connection = HttpClientConnection(
      client: httpClient,
      fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
      userAgent: 'visit-app/1.0',
    );
    final credentials = WebCredentialsUtils(
      InMemoryServerCredentialsSettings(serverUrl: serverUrl),
    );
    final uploader = OpenRosaInstanceUploader(connection, credentials);
    final store = FormStore();
    final requests = <http.Request>[];
    await downloadForms(
      OpenRosaClient(
        serverUrl,
        HttpClientConnection(
          client: fakeCentral(requests),
          fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
          userAgent: 'visit-app/1.0',
        ),
        credentials,
        deviceId: 'd',
      ),
      store,
    );
    final session = (await loadForm(store, 'household')).createSession();
    final submission = (session.finalize() as FinalizeSuccess).submission;
    store.outbox[submission.instanceId!] = (
      formId: 'household',
      submission: submission,
    );

    final problems = await sendOutbox(store, uploader, serverUrl);

    expect(store.outbox, hasLength(1));
    expect(problems.single, contains('500'));
  });
}
