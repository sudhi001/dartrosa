// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Keeps the code in docs/*.md and docs/guides/*.md compiling: every
// ```dart block of a guide must appear, line for line (ignoring indentation
// and blank lines), in one of the doc test files under packages/*/test/docs/,
// which run the code. all_docs_test.dart checks every guide.
import 'dart:io';

import 'package:test/test.dart';

import '../support/forms.dart' show conformanceDir;

/// The repository root (found from the package or the root directory).
final Directory repoRoot = conformanceDir().parent;

String _normalize(String code) => code
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

/// The ```dart blocks of [markdown].
List<String> dartBlocks(String markdown) => [
  for (final match in RegExp(
    r'^```dart\n(.*?)^```',
    multiLine: true,
    dotAll: true,
  ).allMatches(markdown))
    match.group(1)!,
];

/// The sources of every doc test (all packages, Flutter included).
String docTestSources() {
  final buffer = StringBuffer();
  final packages = Directory('${repoRoot.path}/packages').listSync();
  for (final package in packages.whereType<Directory>()) {
    final docs = Directory('${package.path}/test/docs');
    if (!docs.existsSync()) continue;
    for (final file in docs.listSync().whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        buffer.writeln(_normalize(file.readAsStringSync()));
      }
    }
  }
  return buffer.toString();
}

/// The guides (relative to the repository root) that contain Dart code:
/// `docs/*.md` and `docs/guides/*.md`.
List<String> guidesWithDartCode() {
  final guides = <String>[];
  for (final dir in ['docs', 'docs/guides']) {
    final directory = Directory('${repoRoot.path}/$dir');
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync().whereType<File>()) {
      if (file.path.endsWith('.md') &&
          dartBlocks(file.readAsStringSync()).isNotEmpty) {
        guides.add('$dir/${file.uri.pathSegments.last}');
      }
    }
  }
  return guides..sort();
}

/// Checks that every Dart block of the guide [docPath] (relative to the
/// repository root) is in a doc test.
void expectSnippetsTested(String docPath) {
  test('$docPath snippets are tested', () {
    final markdown = File('${repoRoot.path}/$docPath').readAsStringSync();
    final blocks = dartBlocks(markdown);
    expect(blocks, isNotEmpty);
    final sources = docTestSources();
    for (final block in blocks) {
      expect(
        sources.contains(_normalize(block)),
        isTrue,
        reason: 'This snippet of $docPath is not in a doc test:\n$block',
      );
    }
  });
}

/// The pure-Dart packages whose API docs and READMEs are checked by
/// api_docs_test.dart.
const pureDartPackages = [
  'dartrosa',
  'dartrosa_calendars',
  'dartrosa_collect',
  'dartrosa_encryption',
  'dartrosa_entities',
  'dartrosa_external_data',
  'dartrosa_openrosa',
];

/// Whether [code] is in [sources], ignoring indentation and blank lines.
bool containsSnippet(String sources, String code) =>
    _normalize(sources).contains(_normalize(code));

/// The `///` doc comments of the Dart [source], without their `///`
/// prefixes, each with the line that follows it (the documented
/// declaration).
List<({String comment, String declaration})> docComments(String source) {
  final comments = <({String comment, String declaration})>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trimLeft().startsWith('///')) continue;
    final comment = StringBuffer();
    for (; i < lines.length && lines[i].trimLeft().startsWith('///'); i++) {
      final text = lines[i].trimLeft().substring(3);
      comment.writeln(text.startsWith(' ') ? text.substring(1) : text);
    }
    comments.add((
      comment: comment.toString(),
      declaration: i < lines.length ? lines[i].trim() : '',
    ));
  }
  return comments;
}
