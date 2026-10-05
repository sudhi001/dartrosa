// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code examples of the API docs (```dart blocks in lib/ doc comments)
// and of README.md, run as tests so they can't rot.
// packages/dartrosa/test/docs/api_docs_test.dart checks that every such
// block is in a doc test like this one.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:test/test.dart';

import '../../example/example.dart' as example;
import 'readme_example.dart' as readme;

/// The encrypted form of example/example.dart.
const xform = example.xform;

void main() {
  late FormDefinition definition;
  late Submission submission;
  final photoBytes = Uint8List.fromList([1, 2, 3]);

  setUp(() async {
    definition = await FormDefinition.parse(xform);
    final session = definition.createSession();
    submission = (session.finalize() as FinalizeSuccess).submission;
  });

  test('library: dartrosa_encryption', () {
    final xmlBytes = utf8.encode(submission.xml);
    final photo = photoBytes;
    final form = definition.formDef;
    final uploaded = <String>[];
    void upload(Uint8List manifest, Map<String, Uint8List> files) =>
        uploaded.addAll(files.keys);

    final encrypted = encryptSubmission(xmlBytes, {'photo.jpg': photo}, form);
    if (encrypted != null) {
      upload(encrypted.manifestBytes, encrypted.encryptedFiles);
    }

    expect(uploaded, ['photo.jpg.enc', 'submission.xml.enc']);
  });

  test('encryptSubmission', () {
    expect(() {
      final encrypted = encryptSubmission(
        utf8.encode(submission.xml),
        {'photo.jpg': photoBytes}, // attachments: file name -> bytes
        definition.formDef,
      );
      if (encrypted != null) {
        print(encrypted.mediaFileNames); // [photo.jpg]
      }
    }, prints('[photo.jpg]\n'));
  });

  test('README example', () async {
    await readme.main();
  });

  test('example/example.dart', () async {
    await expectLater(example.main, prints(contains('submission.xml.enc')));
  });
}
