// Keeps the code in docs/*.md compiling: every ```dart block of a guide
// must appear, line for line (ignoring indentation and blank lines), in one
// of the doc test files under packages/*/test/docs/, which run the code.
import 'dart:io';

import 'package:test/test.dart';

/// The repository root (tests run from packages/dartrosa).
final Directory repoRoot = Directory.current.parent.parent;

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
