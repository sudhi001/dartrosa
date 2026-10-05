// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// End to end: a media question answered with a file name (as the Flutter
// renderer's capture widgets do) → finalize → Submission.attachments →
// encryption and OpenRosa upload send the file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/mock_web_server.dart';
import 'instance_upload_test.dart' show form, testPublicKeyBase64;

/// Fills [xml]'s form like the renderer: a name and a photo file name.
Future<(FormDefinition, Submission)> fill(String xml) async {
  final definition = await FormDefinition.parse(xml);
  final session = definition.createSession();
  final [name, photo] = session.root.visibleChildren.cast<QuestionNode>();
  expect(photo.dataType, DataType.binary);
  session
    ..answer(name.index, const StringValue('Zoë'))
    ..answer(photo.index, const UncastValue('photo.jpg'));
  final result = session.finalize() as FinalizeSuccess;
  return (definition, result.submission);
}

OpenRosaInstanceUploader uploader(MockWebServer server) =>
    OpenRosaInstanceUploader(
      HttpClientConnection(
        client: server.client,
        fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
        userAgent: 'test',
      ),
      WebCredentialsUtils(InMemoryServerCredentialsSettings()),
    );

void main() {
  final savedFiles = {
    'photo.jpg': Uint8List.fromList(List.generate(64, (i) => i)),
    'unrelated.jpg': Uint8List.fromList([9, 9, 9]),
  };

  /// The saved files the submission names.
  Map<String, Uint8List> attachmentsOf(Submission submission) => {
    for (final name in submission.attachments) name: savedFiles[name]!,
  };

  test('finalize lists the photo answered with a file name', () async {
    final (_, submission) = await fill(form());
    expect(submission.xml, contains('<photo>photo.jpg</photo>'));
    expect(submission.attachments, ['photo.jpg']);
  });

  test('encryptSubmission encrypts the photo', () async {
    final (definition, submission) = await fill(
      form(
        submission: '<submission base64RsaPublicKey="$testPublicKeyBase64"/>',
      ),
    );
    final encrypted = encryptSubmission(
      utf8.encode(submission.xml),
      attachmentsOf(submission),
      definition.formDef,
      instanceId: submission.instanceId,
    )!;
    expect(encrypted.mediaFileNames, ['photo.jpg']);
    expect(encrypted.encryptedFiles.keys, [
      'photo.jpg.enc',
      'submission.xml.enc',
    ]);
    expect(utf8.decode(encrypted.manifestBytes), contains('photo.jpg.enc'));
  });

  test('the upload sends the photo', () async {
    final (definition, submission) = await fill(form());
    final server = MockWebServer('https://s.org')
      ..enqueue(MockResponse(code: 204))
      ..enqueue(MockResponse(code: 201));
    await uploader(server).uploadOneSubmission(
      InstanceUpload.forForm(
        definition.formDef,
        submission,
        attachments: attachmentsOf(submission),
      ),
      serverUrl: 'https://s.org',
    );
    server.takeRequest(); // HEAD
    final parts = splitMultiPart(server.takeRequest());
    expect(parts.length, 2);
    expect(parts[0][1], contains('filename="submission.xml"'));
    expect(parts[1][1], contains('filename="photo.jpg"'));
    expect(parts[1][2], 'Content-Type: image/jpeg');
  });

  test('the encrypted upload sends the encrypted photo', () async {
    final (definition, submission) = await fill(
      form(
        submission: '<submission base64RsaPublicKey="$testPublicKeyBase64"/>',
      ),
    );
    final server = MockWebServer('https://s.org')
      ..enqueue(MockResponse(code: 204))
      ..enqueue(MockResponse(code: 201));
    await uploader(server).uploadOneSubmission(
      InstanceUpload.forForm(
        definition.formDef,
        submission,
        attachments: attachmentsOf(submission),
      ),
      serverUrl: 'https://s.org',
    );
    server.takeRequest(); // HEAD
    final parts = splitMultiPart(server.takeRequest());
    expect(parts.map((p) => p[1]), [
      contains('filename="submission.xml"'),
      contains('filename="photo.jpg.enc"'),
      contains('filename="submission.xml.enc"'),
    ]);
  });
}
