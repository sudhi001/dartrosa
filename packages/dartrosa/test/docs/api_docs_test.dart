// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Keeps the code examples of the pure-Dart packages' API docs and READMEs
// compiling and running: every ```dart block of a lib/ doc comment must be
// in a doc test (packages/*/test/docs/), every ```dart block of a README
// in a doc test or in the package's example/example.dart, and the main
// entry points must have an example.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'doc_snippets.dart';

/// The declarations (start of the line after the doc comment) whose doc
/// comment must contain a ```dart example, by package and file.
const entryPoints = {
  'dartrosa': {
    'lib/dartrosa.dart': ['library;'],
    'lib/src/session/form_session.dart': [
      'final class FormDefinition',
      'final class FormSession',
      'final class FormNavigator',
    ],
    'lib/src/session/config.dart': ['final class DartRosaConfig'],
    'lib/src/session/answer_result.dart': ['sealed class AnswerResult'],
  },
  'dartrosa_calendars': {
    'lib/dartrosa_calendars.dart': ['library;'],
    'lib/src/custom_calendar.dart': ['sealed class CustomCalendar'],
  },
  'dartrosa_collect': {
    'lib/src/collect_config.dart': ['DartRosaConfig collectFormConfig('],
  },
  'dartrosa_encryption': {
    'lib/dartrosa_encryption.dart': ['library;'],
    'lib/src/encryption_utils.dart': [
      'EncryptedSubmission? encryptSubmission(',
    ],
  },
  'dartrosa_entities': {
    'lib/src/entities_config.dart': ['DartRosaConfig withEntities('],
  },
  'dartrosa_external_data': {
    'lib/src/external_data_plugin.dart': ['final class ExternalDataPlugin'],
  },
  'dartrosa_openrosa': {
    'lib/dartrosa_openrosa.dart': ['library;'],
    'lib/src/forms/open_rosa_client.dart': ['final class OpenRosaClient'],
  },
};

void main() {
  final sources = docTestSources();

  for (final package in pureDartPackages) {
    final root = '${repoRoot.path}/packages/$package';

    test('$package: API doc examples are tested', () {
      final files = Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        for (final (:comment, :declaration) in docComments(
          file.readAsStringSync(),
        )) {
          for (final block in dartBlocks(comment)) {
            expect(
              containsSnippet(sources, block),
              isTrue,
              reason:
                  'This example of ${file.path} ($declaration) is not in a '
                  'doc test:\n$block',
            );
          }
        }
      }
    });

    test('$package: README examples are tested', () {
      final readme = File('$root/README.md').readAsStringSync();
      final example = File('$root/example/example.dart').readAsStringSync();
      final blocks = dartBlocks(readme);
      expect(blocks, isNotEmpty);
      for (final block in blocks) {
        expect(
          containsSnippet(sources, block) || containsSnippet(example, block),
          isTrue,
          reason:
              'This example of $package/README.md is not in a doc test:\n'
              '$block',
        );
      }
    });

    test('$package: main entry points have examples', () {
      for (final MapEntry(key: path, value: declarations)
          in entryPoints[package]!.entries) {
        final comments = docComments(File('$root/$path').readAsStringSync());
        for (final declaration in declarations) {
          final documented = comments.where(
            (c) => c.declaration.startsWith(declaration),
          );
          expect(documented, hasLength(1), reason: '$path: $declaration');
          expect(
            dartBlocks(documented.single.comment),
            isNotEmpty,
            reason: '$path: $declaration has no ```dart example',
          );
        }
      }
    });
  }
}
