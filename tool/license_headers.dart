// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Checks or adds SPDX license headers (ISO/IEC 5962) on the repository's
// .dart, .java, .sh and .py sources. See docs/legal/README.md.
//
//   dart run tool/license_headers.dart --check
//   dart run tool/license_headers.dart --apply [path ...]
//       [--upstream javarosa=<checkout>] [--upstream collect=<checkout>]
//
// --check exits 1 when a file lacks a header, or lacks the "Derived from"
// line although it ports upstream code. --apply adds what is missing and
// never rewrites an existing header, so it is idempotent and hand-edited
// headers survive. Paths limit either mode to those files or directories.
//
// A file ports upstream code when it says so: a "Port of ..." comment
// naming JavaRosa, Collect, opencsv, Joda-Time, ... (or, unnamed, the
// project its package ports). With --upstream, the "Derived from" line
// carries the copyright lines of the upstream files the comment names;
// otherwise the project's usual holders (NOTICE.md lists them in full).
import 'dart:io';

/// A project DartRosa code is translated from.
final class Upstream {
  const Upstream(
    this.key,
    this.name,
    this.holder, {
    required this.pattern,
    this.license = 'Apache-2.0',
  });

  /// The key for `--upstream <key>=<dir>`.
  final String key;

  /// The name used in the header.
  final String name;

  /// The copyright line used when no upstream checkout is given.
  final String holder;

  /// The SPDX id of the upstream license.
  final String license;

  /// Matches a "Port of" comment naming this project.
  final RegExp pattern;
}

final upstreams = <Upstream>[
  Upstream(
    'javarosa',
    'JavaRosa',
    'Copyright (C) 2009 JavaRosa and contributors',
    pattern: RegExp(r'^\w+ \w+ (?:the [\w ]+ of )?JavaRosa\b|org\.javarosa'),
  ),
  Upstream(
    'collect',
    'ODK Collect',
    'Copyright University of Washington, Nafundi and contributors',
    pattern: RegExp(
      r'^\w+ \w+ (?:the [\w ]+ of )?(?:ODK )?Collect\b|org\.odk\.collect',
    ),
  ),
  Upstream(
    'opencsv',
    'opencsv',
    'Copyright 2005 Bytecode Pty Ltd.',
    pattern: RegExp('opencsv'),
  ),
  Upstream(
    'joda',
    'Joda-Time',
    'Copyright 2001-2015 Stephen Colebourne',
    pattern: RegExp(r'\bJoda\b'),
  ),
  Upstream(
    'persianjodatime',
    'persianjodatime',
    'Copyright the persianjodatime authors',
    pattern: RegExp(r'persianjodatime|PersianChronology'),
  ),
  Upstream(
    'bikramsambat',
    'bikram-sambat',
    'Copyright Medic Mobile and contributors',
    pattern: RegExp(r'bikram-sambat|BsCalendar'),
  ),
  Upstream(
    'myanmar',
    'myanmar-calendar (mmcalendar)',
    'Copyright (c) 2017 Chan Mrate Ko Ko, (c) 2018 Yan Naing Aye',
    license: 'MIT',
    pattern: RegExp(r'myanmar-calendar|mmcalendar|Yan Naing Aye'),
  ),
];

/// The project each package ports, for "Port of `X`" comments that don't
/// name one.
const packageDefaults = {
  'dartrosa': 'javarosa',
  'dartrosa_calendars': 'collect',
  'dartrosa_collect': 'collect',
  'dartrosa_encryption': 'collect',
  'dartrosa_entities': 'collect',
  'dartrosa_external_data': 'collect',
  'dartrosa_openrosa': 'collect',
  'dartrosa_flutter': 'collect',
};

const extensions = {'.dart', '.java', '.sh', '.py'};

/// Paths never given a header: data, vectors, assets and upstream files
/// kept unmodified (they keep their own notices).
final excluded = <RegExp>[
  RegExp(r'^conformance/(forms|traces)/'),
  RegExp(r'/test/vectors/'),
  RegExp(r'/example/assets/'),
  RegExp(r'(^|/)(build|\.dart_tool)/'),
  RegExp(r'\.(g|freezed|mocks)\.dart$'),
  RegExp(r'^packages/dartrosa_calendars/tool/oracle/src/org/odk/'),
];

final generatedMarker = RegExp(r'GENERATED|DO NOT EDIT|Do not edit');
final portComment = RegExp(r'\b[Pp]ort(?:ed)? (?:of|from)\b');
// Split so that REUSE tooling doesn't read these literals as license tags.
const spdxTag =
    'SPDX-License-'
    'Identifier:';
final spdxLine = RegExp(spdxTag);
const ownCopyright = 'The DartRosa Authors';
const headerScan = 25;

void main(List<String> args) {
  final check = args.contains('--check');
  final apply = args.contains('--apply');
  if (check == apply) {
    stderr.writeln(
      'Usage: dart run tool/license_headers.dart (--check | --apply) '
      '[--upstream <key>=<dir>]... [path ...]',
    );
    exit(64);
  }
  final checkouts = <String, Directory>{};
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--upstream' && i + 1 < args.length) {
      final [key, dir] = args[++i].split('=');
      checkouts[key] = Directory(dir);
    } else if (!arg.startsWith('--')) {
      paths.add(arg.endsWith('/') ? arg.substring(0, arg.length - 1) : arg);
    }
  }
  final root = File.fromUri(Platform.script).parent.parent.path;
  final indexes = {
    for (final MapEntry(:key, :value) in checkouts.entries)
      key: _UpstreamIndex(value),
  };
  final years = _creationYears(root);
  final thisYear = DateTime.now().year;

  final missing = <String>[];
  var ok = 0, skipped = 0;
  for (final path in _sourceFiles(root)) {
    if (paths.isNotEmpty &&
        !paths.any((p) => path == p || path.startsWith('$p/'))) {
      continue;
    }
    final file = File('$root/$path');
    final text = file.readAsStringSync();
    final lines = text.split('\n');
    if (lines.take(5).any(generatedMarker.hasMatch)) {
      skipped++;
      continue;
    }
    final derived = _derivedFrom(path, text, indexes);
    final head = lines.take(headerScan).toList();
    final hasSpdx = head.any(spdxLine.hasMatch);
    final hasDerived = head.any((l) => l.contains('Derived from'));
    if (hasSpdx && (derived.isEmpty || hasDerived)) {
      ok++;
      continue;
    }
    missing.add(path);
    if (!apply) continue;
    final comment = path.endsWith('.sh') || path.endsWith('.py') ? '#' : '//';
    final year = years[path] ?? thisYear;
    file.writeAsStringSync(
      _withHeader(lines, comment, year, derived, hasSpdx: hasSpdx),
    );
  }

  if (check) {
    for (final path in missing) {
      stdout.writeln('missing header: $path');
    }
    stdout.writeln(
      '${ok + missing.length} files checked, $ok with headers, '
      '${missing.length} missing, $skipped generated skipped.',
    );
    if (missing.isNotEmpty) {
      stdout.writeln('Run: dart run tool/license_headers.dart --apply');
      exit(1);
    }
  } else {
    for (final path in missing) {
      stdout.writeln('added header: $path');
    }
    stdout.writeln('${missing.length} headers added, $ok already present.');
  }
}

/// Tracked and untracked (not ignored) source files, relative to [root].
List<String> _sourceFiles(String root) {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${result.stderr}');
    exit(2);
  }
  return [
    for (final path in (result.stdout as String).split('\n'))
      if (extensions.any(path.endsWith) &&
          !excluded.any((e) => e.hasMatch(path)) &&
          File('$root/$path').existsSync())
        path,
  ]..sort();
}

/// The year each tracked file was added to the repository.
Map<String, int> _creationYears(String root) {
  final result = Process.runSync('git', [
    'log',
    '--diff-filter=A',
    '--format=@%ad',
    '--date=format:%Y',
    '--name-only',
  ], workingDirectory: root);
  final years = <String, int>{};
  if (result.exitCode != 0) return years;
  int? year;
  // Newest first, so the last value written is the first addition.
  for (final line in (result.stdout as String).split('\n')) {
    if (line.startsWith('@')) {
      year = int.tryParse(line.substring(1));
    } else if (line.isNotEmpty && year != null) {
      years[line] = year;
    }
  }
  return years;
}

/// One upstream a file is derived from, with what it names.
final class _Derivation {
  _Derivation(this.upstream);

  final Upstream upstream;
  final names = <String>{};
  final holders = <String>{};
}

/// The upstream projects [text] says it ports, keyed by [Upstream.key].
List<_Derivation> _derivedFrom(
  String path,
  String text,
  Map<String, _UpstreamIndex> indexes,
) {
  final lines = text.split('\n');
  final package = RegExp(r'^packages/([^/]+)/').firstMatch(path)?.group(1);
  final found = <String, _Derivation>{};
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final match = portComment.firstMatch(line);
    if (match == null || !line.trimLeft().startsWith(RegExp('//|#|\\*'))) {
      continue;
    }
    // The sentence starting at "Port of", up to the end of the next line.
    var context = line.substring(match.start);
    if (i + 1 < lines.length) {
      context += ' ${lines[i + 1].trim().replaceFirst(_commentLead, '')}';
    }
    final end = _sentenceEnd.firstMatch(context);
    if (end != null) context = context.substring(0, end.start + 1);
    var matched = upstreams.where((u) => u.pattern.hasMatch(context)).toList();
    if (matched.isEmpty) {
      final key = packageDefaults[package];
      if (key == null) continue;
      matched = [upstreams.firstWhere((u) => u.key == key)];
    }
    final names = _classNames(context);
    for (final upstream in matched) {
      final derivation = found.putIfAbsent(
        upstream.key,
        () => _Derivation(upstream),
      );
      derivation.names.addAll(names);
      final index = indexes[upstream.key];
      if (index != null) {
        for (final name in names) {
          derivation.holders.addAll(index.copyrightsOf(name));
        }
      }
    }
  }
  return found.values.toList();
}

const _projectWords = {'Collect', 'JavaRosa', 'Joda', 'Kotlin', 'Yan'};
final _commentLead = RegExp(r'^(///?|#|\*)\s?');
final _sentenceEnd = RegExp(r'[.;:](\s|$)');
final _backticked = RegExp('`([^`]+)`');
final _firstClass = RegExp(r'\b(?:[a-z]\w*\.)*([A-Z][A-Za-z0-9]*[a-z]\w*)');
final _bareName = RegExp(
  r"^[Pp]ort(?:ed)? (?:of|from) (?:the parts of )?(?:(?:ODK )?Collect's |"
  r"JavaRosa(?: v[\d.]+)?(?:'s)? |opencsv [\d.]+'s )?"
  r'((?:[a-z]\w*\.)*[A-Z][A-Za-z0-9]*[a-z]\w*)',
);

/// Upstream class names in a "Port of" sentence: the outer class of each
/// `org.x.Foo.bar` in backticks, and a bare name right after "Port of"
/// ("Port of JavaRosa v6.0.0 FooTest" gives FooTest).
List<String> _classNames(String context) {
  final names = <String>[];
  final bare = _bareName.firstMatch(context)?.group(1);
  for (final candidate in [
    ?bare,
    for (final m in _backticked.allMatches(context)) m.group(1)!,
  ]) {
    final name = _firstClass.firstMatch(candidate)?.group(1);
    if (name != null &&
        !_projectWords.contains(name) &&
        !names.contains(name)) {
      names.add(name);
    }
  }
  return names;
}

/// The header lines for [derived] at the top of a file.
String _withHeader(
  List<String> lines,
  String comment,
  int year,
  List<_Derivation> derived, {
  required bool hasSpdx,
}) {
  final header = <String>[];
  if (!hasSpdx) header.add('$comment Copyright $year $ownCopyright');
  for (final d in derived) {
    final what = d.names.isEmpty ? '' : ' (${d.names.join(', ')})';
    final holders = d.holders.isEmpty ? [d.upstream.holder] : d.holders;
    header.addAll(
      _wrap(
        'Derived from ${d.upstream.name}$what, ${holders.join('; ')}; '
        'modified: translated to Dart.',
        comment,
      ),
    );
  }
  final licenses = {'Apache-2.0', for (final d in derived) d.upstream.license};
  if (!hasSpdx) {
    header.add('$comment $spdxTag ${licenses.join(' AND ')}');
  }

  // Keep a shebang (and a Python coding line) first.
  var at = 0;
  while (at < lines.length &&
      at < 2 &&
      (lines[at].startsWith('#!') || lines[at].contains('coding:'))) {
    at++;
  }
  if (hasSpdx) {
    // Add the missing "Derived from" lines just before the SPDX line.
    final spdx = lines.indexWhere(spdxLine.hasMatch);
    return [
      ...lines.sublist(0, spdx),
      ...header,
      ...lines.sublist(spdx),
    ].join('\n');
  }
  final rest = lines.sublist(at);
  final blank = rest.isNotEmpty && rest.first.trim().isNotEmpty
      ? ['']
      : <String>[];
  return [...lines.sublist(0, at), ...header, ...blank, ...rest].join('\n');
}

/// [text] as comment lines of at most 80 columns.
List<String> _wrap(String text, String comment) {
  final out = <String>[];
  var line = comment;
  for (final word in text.split(' ')) {
    if (line.length + 1 + word.length > 80 && line != comment) {
      out.add(line);
      line = '$comment  ';
      line += word;
    } else {
      line += line.endsWith(' ') ? word : ' $word';
    }
  }
  out.add(line);
  return out;
}

/// Source files of an upstream checkout by class name, and their
/// copyright lines.
final class _UpstreamIndex {
  _UpstreamIndex(Directory dir) {
    if (!dir.existsSync()) {
      stderr.writeln('No upstream checkout at ${dir.path}');
      exit(2);
    }
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      final path = entity.path;
      if (entity is! File || path.contains('/build/')) continue;
      final m = RegExp(r'/([A-Za-z0-9_]+)\.(java|kt)$').firstMatch(path);
      if (m != null) (_files[m.group(1)!] ??= []).add(entity);
    }
  }

  final _files = <String, List<File>>{};
  static final _copyright = RegExp(
    r'Copyright\s+(?:\(C\)\s*|©\s*)?\d{4}[^\n*]*',
    caseSensitive: false,
  );

  /// Copyright lines of the main (else test) source named [name].
  Iterable<String> copyrightsOf(String name) {
    final files = _files[name];
    if (files == null) return const [];
    files.sort((a, b) {
      int rank(File f) => f.path.contains('/src/test/') ? 1 : 0;
      return rank(a).compareTo(rank(b));
    });
    final head = files.first.readAsLinesSync().take(30).join('\n');
    return _copyright.allMatches(head).map((m) => m.group(0)!.trim());
  }
}
