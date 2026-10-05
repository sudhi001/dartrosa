// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim below the imports its placeholders
// need; run by api_examples_test.dart.
// ignore_for_file: directives_ordering
import 'dart:typed_data';

import '../../example/example.dart' as example;
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

/// The form of example/example.dart, which is encrypted.
const encryptedFormXml = example.xform;

/// A photo attachment.
final photoBytes = Uint8List.fromList([1, 2, 3]);
