// Fails if a pure-Dart core package imports something that would stop it
// running on every platform (web, server, Flutter). See docs/development/PORTING_PLAN.md §3.
import 'dart:io';

const corePackages = [
  'dartrosa',
  'dartrosa_calendars',
  'dartrosa_collect',
  'dartrosa_encryption',
  'dartrosa_entities',
  'dartrosa_external_data',
  'dartrosa_openrosa',
];
final forbidden = RegExp(
  r'''^\s*(import|export)\s+['"](dart:io|dart:html|dart:mirrors|dart:ffi|package:flutter/|package:web/)''',
  multiLine: true,
);

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final problems = <String>[];
  for (final package in corePackages) {
    final lib = Directory('${root.path}/packages/$package/lib');
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in forbidden.allMatches(file.readAsStringSync())) {
        problems.add('${file.path}: ${match.group(0)!.trim()}');
      }
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('Core packages must stay platform-neutral:');
    problems.forEach(stderr.writeln);
    exit(1);
  }
  stdout.writeln('Core purity check passed (${corePackages.join(', ')}).');
}
