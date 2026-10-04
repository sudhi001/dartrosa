// Copies the conformance corpus (conformance/forms/**) into assets/forms/,
// writes assets/forms/index.json and lists the asset folders in
// pubspec.yaml. Run from the example directory:
//
//     dart run tool/bundle_corpus.dart
import 'dart:convert';
import 'dart:io';

const _begin = '    # BEGIN corpus assets (tool/bundle_corpus.dart)';
const _end = '    # END corpus assets';

void main() {
  final conformance = Directory('../../../conformance');
  final source = Directory('${conformance.path}/forms');
  if (!source.existsSync()) {
    stderr.writeln('Run from packages/dartrosa_flutter/example.');
    exitCode = 1;
    return;
  }
  final excluded = File('${conformance.path}/nondeterministic.txt')
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();

  final target = Directory('assets/forms');
  if (target.existsSync()) target.deleteSync(recursive: true);

  final forms = <Map<String, Object?>>[];
  final files = <String, List<String>>{};
  final sourceFiles =
      source.listSync(recursive: true).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in sourceFiles) {
    final path = file.path.substring(source.path.length + 1);
    if (excluded.contains('forms/$path')) continue;
    final copy = File('${target.path}/$path')
      ..parent.createSync(recursive: true);
    file.copySync(copy.path);
    final slash = path.lastIndexOf('/');
    files
        .putIfAbsent(path.substring(0, slash), () => [])
        .add(path.substring(slash + 1));

    // Forms are the files the oracle recorded a structure trace for.
    if (!File('${conformance.path}/traces/structure/$path.json').existsSync()) {
      continue;
    }
    Object? ok(String kind, String key) =>
        switch (File('${conformance.path}/traces/$kind/$path.json')) {
          final f when f.existsSync() =>
            ((jsonDecode(f.readAsStringSync()) as Map<String, Object?>)[key]
                as Map<String, Object?>?)?['ok'],
          _ => null,
        };
    final title = RegExp(
      r'<(?:h:)?title>([^<]*)</(?:h:)?title>',
    ).firstMatch(file.readAsStringSync())?.group(1)?.trim();
    forms.add({
      'path': path,
      'title': (title == null || title.isEmpty) ? null : title,
      'javarosaParses': ok('structure', 'parse') ?? true,
      'javarosaInitializes': ok('init', 'initialize') ?? true,
    });
  }

  File('${target.path}/index.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({'forms': forms, 'files': files}),
  );

  // Flutter asset folders aren't recursive: list every one.
  final pubspec = File('pubspec.yaml');
  final lines = pubspec.readAsLinesSync();
  final begin = lines.indexOf(_begin);
  final end = lines.indexOf(_end);
  if (begin < 0 || end < begin) {
    stderr.writeln('pubspec.yaml has no corpus asset markers.');
    exitCode = 1;
    return;
  }
  final folders = [
    'assets/forms/',
    for (final dir in files.keys) 'assets/forms/$dir/',
  ]..sort();
  lines.replaceRange(begin + 1, end, [for (final f in folders) '    - $f']);
  pubspec.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln(
    'Bundled ${forms.length} forms, '
    '${files.values.fold(0, (n, l) => n + l.length)} files.',
  );
}
