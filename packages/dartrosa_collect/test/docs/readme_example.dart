// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim below the imports its placeholders
// need; run by api_examples_test.dart.
// ignore_for_file: avoid_print, directives_ordering
import '../../example/example.dart' show xform;
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';

Future<void> main() async {
  final lastSaved = LastSaved(InMemoryLastSavedStore(), 'visit-v1');
  final config = collectFormConfig(
    media: MapResourceResolver(const {}), // the form's media files
    lastSaved: lastSaved,
  );

  final session = (await FormDefinition.parse(
    xform,
    config: config,
  )).createSession();
  // ... answer questions ...
  final submission = (session.finalize() as FinalizeSuccess).submission;
  await lastSaved.instanceSaved(session); // pre-fills the next instance

  // Editing a finalized submission gives it a new instanceID.
  final edit = (await FormDefinition.parse(
    xform,
    config: config,
  )).createSession(existingInstance: submission.xml);
  const InstanceEdit(editOf: 1).markSession(edit);
  print((edit.finalize() as FinalizeSuccess).submission.xml); // deprecatedID
}
