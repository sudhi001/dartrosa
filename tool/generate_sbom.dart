// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Writes docs/legal/sbom.spdx.json: an SPDX 2.3 (ISO/IEC 5962) software
// bill of materials for the DartRosa packages, their runtime dependencies
// (with the licenses read from each dependency's LICENSE file) and the
// upstream projects they are translated from. See docs/legal/README.md.
//
//   dart pub get
//   (cd packages/dartrosa_flutter && flutter pub get)
//   dart run tool/generate_sbom.dart [--check]
//
// Versions and checksums come from the pubspec.lock files, dependency edges
// from each package's pubspec.yaml, located through
// .dart_tool/package_config.json. Dev dependencies (test, lints, ...) are
// not distributed and are left out. --check exits 1 if the committed file
// is out of date instead of writing it.
import 'dart:convert';
import 'dart:io';

const outputPath = 'docs/legal/sbom.spdx.json';
const repository = 'https://github.com/sudhi001/dartrosa';
const supplier = 'Organization: The DartRosa Authors';

/// Licenses of DartRosa packages that contain code under another license
/// besides Apache-2.0 (see NOTICE.md).
const packageLicenses = {'dartrosa_calendars': 'Apache-2.0 AND MIT'};

/// Projects DartRosa packages are translated from (not dependencies: their
/// code was ported to Dart, see NOTICE.md).
const upstreams = [
  (
    id: 'javarosa',
    name: 'JavaRosa',
    version: 'v6.0.0',
    url: 'https://github.com/getodk/javarosa',
    license: 'Apache-2.0',
    copyright:
        'Copyright (C) 2009 JavaRosa; Copyright 2017-2019 Nafundi; '
        'Copyright 2022 ODK; and contributors',
    portedBy: ['dartrosa'],
  ),
  (
    id: 'collect',
    name: 'ODK Collect',
    version: 'NOASSERTION',
    url: 'https://github.com/getodk/collect',
    license: 'Apache-2.0',
    copyright:
        'Copyright University of Washington; Copyright Nafundi; '
        'and contributors',
    portedBy: [
      'dartrosa_calendars',
      'dartrosa_collect',
      'dartrosa_encryption',
      'dartrosa_entities',
      'dartrosa_external_data',
      'dartrosa_openrosa',
      'dartrosa_flutter',
    ],
  ),
  (
    id: 'opencsv',
    name: 'opencsv',
    version: '5.12.0',
    url: 'https://opencsv.sourceforge.net/',
    license: 'Apache-2.0',
    copyright: 'Copyright 2005 Bytecode Pty Ltd.',
    portedBy: ['dartrosa_collect', 'dartrosa_external_data'],
  ),
  (
    id: 'joda-time',
    name: 'Joda-Time',
    version: '2.14.0',
    url: 'https://www.joda.org/joda-time/',
    license: 'Apache-2.0',
    copyright: 'Copyright 2001-2015 Stephen Colebourne',
    portedBy: ['dartrosa_calendars'],
  ),
  (
    id: 'persianjodatime',
    name: 'persianjodatime',
    version: '1.2',
    url: 'https://github.com/mohamadian/persianjodatime',
    license: 'Apache-2.0',
    copyright: 'NOASSERTION',
    portedBy: ['dartrosa_calendars'],
  ),
  (
    id: 'bikram-sambat',
    name: 'bikram-sambat',
    version: '1.8.1',
    url: 'https://github.com/medic/bikram-sambat',
    license: 'Apache-2.0',
    copyright: 'NOASSERTION',
    portedBy: ['dartrosa_calendars'],
  ),
  (
    id: 'myanmar-calendar',
    name: 'myanmar-calendar (mmcalendar)',
    version: '1.1.1.RELEASE',
    url: 'https://github.com/chanmratekoko/mmcalendar',
    license: 'MIT',
    copyright:
        'Copyright (c) 2017 Chan Mrate Ko Ko; '
        'Copyright (c) 2018 Yan Naing Aye',
    portedBy: ['dartrosa_calendars'],
  ),
];

/// Workspaces to read: the pub workspace at the root and the standalone
/// Flutter package (not in the workspace).
const roots = ['.', 'packages/dartrosa_flutter'];

void main(List<String> args) {
  final check = args.contains('--check');
  final repo = File.fromUri(Platform.script).parent.parent.path;
  // Each workspace resolves its own versions; DartRosa packages are shared.
  final ours = <String, _Package>{};
  final byId = <String, _Package>{};
  final edges = <String, Set<String>>{};
  for (final root in roots) {
    final resolution = _readWorkspace(repo, root, ours);
    void visit(_Package p) {
      final deps = edges.putIfAbsent(p.spdxId, () => {});
      if (byId.containsKey(p.spdxId) && deps.isNotEmpty) return;
      byId[p.spdxId] = p;
      for (final name in p.dependencies) {
        final dep = resolution[name];
        if (dep == null) {
          stderr.writeln(
            'Unresolved package $name in $root: run dart pub get (and '
            'flutter pub get in packages/dartrosa_flutter) first.',
          );
          exit(2);
        }
        deps.add(dep.spdxId);
        visit(dep);
      }
    }

    for (final p in resolution.values.where((p) => p.isMemberOf == root)) {
      visit(p);
    }
  }
  final listed = byId.values.toList()
    ..sort((a, b) {
      final byOwner = (a.isOurs ? 0 : 1).compareTo(b.isOurs ? 0 : 1);
      return byOwner != 0 ? byOwner : a.spdxId.compareTo(b.spdxId);
    });
  final described = listed.where((p) => p.isOurs).toList();

  final spdxPackages = <Map<String, Object?>>[
    for (final p in listed) p.toSpdx(),
    for (final u in upstreams)
      {
        'SPDXID': 'SPDXRef-Upstream-${u.id}',
        'name': u.name,
        'versionInfo': u.version,
        'supplier': 'NOASSERTION',
        'downloadLocation': u.url,
        'homepage': u.url,
        'filesAnalyzed': false,
        'licenseConcluded': u.license,
        'licenseDeclared': u.license,
        'copyrightText': u.copyright,
        'comment':
            'Not a dependency: DartRosa code is a Dart translation of '
            'parts of this project.',
      },
  ];
  final relationships = <Map<String, String>>[
    for (final p in described)
      {
        'spdxElementId': 'SPDXRef-DOCUMENT',
        'relationshipType': 'DESCRIBES',
        'relatedSpdxElement': p.spdxId,
      },
    for (final p in listed)
      for (final dep in edges[p.spdxId]!.toList()..sort())
        {
          'spdxElementId': p.spdxId,
          'relationshipType': 'DEPENDS_ON',
          'relatedSpdxElement': dep,
        },
    for (final u in upstreams)
      for (final name in u.portedBy)
        if (ours[name] case final p?)
          {
            'spdxElementId': p.spdxId,
            'relationshipType': 'DESCENDANT_OF',
            'relatedSpdxElement': 'SPDXRef-Upstream-${u.id}',
          },
  ];

  final body = {'packages': spdxPackages, 'relationships': relationships};
  final digest = _fnv1a(jsonEncode(body));
  final out = File('$repo/$outputPath');
  // Keep the creation time when nothing changed, so regenerating is a no-op.
  var created = DateTime.now().toUtc().toIso8601String().split('.').first;
  if (out.existsSync()) {
    final old = jsonDecode(out.readAsStringSync()) as Map<String, Object?>;
    if ((old['documentNamespace'] as String?)?.endsWith(digest) ?? false) {
      created =
          (old['creationInfo']! as Map<String, Object?>)['created']! as String;
    }
  }
  if (!created.endsWith('Z')) created = '${created}Z';
  final document = {
    'spdxVersion': 'SPDX-2.3',
    'dataLicense': 'CC0-1.0',
    'SPDXID': 'SPDXRef-DOCUMENT',
    'name': 'dartrosa',
    'documentNamespace': '$repository/spdx/dartrosa-$digest',
    'creationInfo': {
      'created': created,
      'creators': ['Tool: dartrosa-tool/generate_sbom.dart', supplier],
      'comment':
          'Runtime dependencies only, as resolved by the '
          'pubspec.lock files when this document was generated.',
    },
    ...body,
  };
  final json = '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  if (check) {
    if (!out.existsSync() || out.readAsStringSync() != json) {
      stdout.writeln(
        '$outputPath is out of date: '
        'run dart run tool/generate_sbom.dart',
      );
      exit(1);
    }
    stdout.writeln('$outputPath is up to date.');
    return;
  }
  out
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(json);
  stdout.writeln(
    'Wrote $outputPath: ${described.length} DartRosa packages, '
    '${listed.length - described.length} runtime dependencies, '
    '${upstreams.length} upstream projects.',
  );
  for (final p in listed.where((p) => !p.isOurs)) {
    stdout.writeln('  ${p.name} ${p.version}: ${p.license}');
  }
}

/// One resolved package.
final class _Package {
  _Package({
    required this.name,
    required this.version,
    required this.source,
    required this.dir,
    this.isMemberOf,
    this.sha256,
  });

  final String name;
  final String version;
  final String source;
  final Directory dir;
  final String? sha256;

  /// The workspace root a DartRosa package belongs to; null for others.
  final String? isMemberOf;
  bool get isOurs => isMemberOf != null;
  late final List<String> dependencies = _dependencies();
  late final String license = isOurs
      ? packageLicenses[name] ?? 'Apache-2.0'
      : _detectLicense(_licenseText());
  String get spdxId => 'SPDXRef-Package-pub-${isOurs ? name : '$name-$version'}'
      .replaceAll(RegExp('[^A-Za-z0-9.-]'), '-');

  List<String> _dependencies() {
    final pubspec = _parseYaml(File('${dir.path}/pubspec.yaml'));
    final deps = pubspec['dependencies'];
    return deps is Map<String, Object?> ? deps.keys.toList() : const [];
  }

  String _licenseText() {
    for (final name in ['LICENSE', 'LICENSE.txt', 'LICENSE.md', 'COPYING']) {
      final file = File('${dir.path}/$name');
      if (file.existsSync()) return file.readAsStringSync();
    }
    return '';
  }

  Map<String, Object?> toSpdx() {
    final copyright = isOurs
        ? 'Copyright 2026 The DartRosa Authors'
        : license == 'NOASSERTION'
        ? 'NOASSERTION'
        : _copyrightLine.firstMatch(_licenseText())?.group(0)?.trim() ??
              'NOASSERTION';
    final hosted = source == 'hosted';
    return {
      'SPDXID': spdxId,
      'name': name,
      'versionInfo': version,
      'supplier': isOurs ? supplier : 'NOASSERTION',
      'downloadLocation': isOurs
          ? 'git+$repository.git#packages/$name'
          : hosted
          ? 'https://pub.dev/api/archives/$name-$version.tar.gz'
          : 'NOASSERTION',
      if (hosted) 'homepage': 'https://pub.dev/packages/$name',
      'filesAnalyzed': false,
      if (sha256 != null)
        'checksums': [
          {'algorithm': 'SHA256', 'checksumValue': sha256},
        ],
      'licenseConcluded': license,
      'licenseDeclared': license,
      'copyrightText': copyright,
      if (source == 'sdk')
        'comment': 'Part of the Flutter SDK; see the SDK for its notices.',
      if (hosted || isOurs)
        'externalRefs': [
          {
            'referenceCategory': 'PACKAGE-MANAGER',
            'referenceType': 'purl',
            'referenceLocator': 'pkg:pub/$name@$version',
          },
        ],
    };
  }
}

/// A copyright statement (not the Apache appendix template).
final _copyrightLine = RegExp(
  r'^\s*Copyright\s+(?:\(c\)\s*|©\s*)?\d{4}.*$',
  multiLine: true,
  caseSensitive: false,
);

/// The SPDX license expression for a LICENSE file's [text].
String _detectLicense(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ');
  final found = <String>[
    if (t.contains('Apache License') && t.contains('Version 2.0')) 'Apache-2.0',
    if (t.contains('Permission is hereby granted, free of charge')) 'MIT',
    if (t.contains('Redistribution and use in source and binary forms'))
      t.contains('Neither the name') ||
              t.contains('may be used to endorse or promote')
          ? 'BSD-3-Clause'
          : 'BSD-2-Clause',
  ];
  // The Flutter engine bundles many third-party notices in one file.
  if (found.isEmpty || text.length > 200000) return 'NOASSERTION';
  return found.join(' AND ');
}

/// The packages resolved in the workspace at [repo]/[root], by name.
/// DartRosa packages come from (and are added to) [ours].
Map<String, _Package> _readWorkspace(
  String repo,
  String root,
  Map<String, _Package> ours,
) {
  final base = '$repo/$root';
  final lock = File('$base/pubspec.lock');
  final config = File('$base/.dart_tool/package_config.json');
  if (!lock.existsSync() || !config.existsSync()) {
    stderr.writeln(
      '$root: no pubspec.lock / .dart_tool/package_config.json; '
      'run pub get there first.',
    );
    exit(2);
  }
  final resolution = <String, _Package>{};
  // Workspace members are not in the lock file.
  final rootPubspec = _parseYaml(File('$base/pubspec.yaml'));
  final members = [
    if (rootPubspec['workspace'] case final List<Object?> list)
      for (final m in list) m! as String
    else
      '.',
  ];
  for (final member in members) {
    final dir = Directory('$base/$member');
    final pubspec = _parseYaml(File('${dir.path}/pubspec.yaml'));
    final name = pubspec['name']! as String;
    resolution[name] = ours[name] ??= _Package(
      name: name,
      version: pubspec['version'] as String? ?? '0.0.0',
      source: 'path',
      dir: dir,
      isMemberOf: root,
    );
  }

  final dirs = <String, Directory>{};
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final entry in json['packages']! as List<Object?>) {
    final p = entry! as Map<String, Object?>;
    final uri = config.uri.resolve(p['rootUri']! as String);
    dirs[p['name']! as String] = Directory.fromUri(uri);
  }
  final locked = _parseYaml(lock)['packages']! as Map<String, Object?>;
  for (final MapEntry(key: name, :value) in locked.entries) {
    if (resolution.containsKey(name)) continue;
    if (ours[name] case final p?) {
      resolution[name] = p;
      continue;
    }
    final entry = value! as Map<String, Object?>;
    final description = entry['description'];
    final dir = dirs[name];
    if (dir == null) continue;
    resolution[name] = _Package(
      name: name,
      version: entry['version']! as String,
      source: entry['source']! as String,
      dir: dir,
      sha256: description is Map<String, Object?>
          ? description['sha256'] as String?
          : null,
    );
  }
  return resolution;
}

/// Parses the block-style YAML subset of pubspec files: nested maps, lists
/// of scalars, quoted scalars, comments and folded/literal block scalars.
Map<String, Object?> _parseYaml(File file) {
  final lines = [
    for (final raw in file.readAsLinesSync())
      if (raw.trim().isNotEmpty && !raw.trimLeft().startsWith('#')) raw,
  ];
  var i = 0;
  int indentOf(String line) => line.length - line.trimLeft().length;
  String scalar(String s) {
    s = s.replaceFirst(RegExp(r'\s+#.*$'), '').trim();
    if (s.length >= 2 &&
        (s.startsWith('"') && s.endsWith('"') ||
            s.startsWith("'") && s.endsWith("'"))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  Object? block(int indent) {
    if (i < lines.length && lines[i].trimLeft().startsWith('- ')) {
      final list = <Object?>[];
      while (i < lines.length &&
          indentOf(lines[i]) == indent &&
          lines[i].trimLeft().startsWith('- ')) {
        list.add(scalar(lines[i].trimLeft().substring(2)));
        i++;
        // Skip the rest of a map item (not needed here).
        while (i < lines.length && indentOf(lines[i]) > indent) {
          i++;
        }
      }
      return list;
    }
    final map = <String, Object?>{};
    while (i < lines.length && indentOf(lines[i]) == indent) {
      final line = lines[i].trim();
      final colon = line.indexOf(RegExp(r':(\s|$)'));
      if (colon < 0) {
        i++;
        continue;
      }
      final key = scalar(line.substring(0, colon));
      final rest = line.substring(colon + 1).trim();
      i++;
      if (rest.startsWith('>') || rest.startsWith('|')) {
        final parts = <String>[];
        while (i < lines.length && indentOf(lines[i]) > indent) {
          parts.add(lines[i++].trim());
        }
        map[key] = parts.join(' ');
      } else if (rest.isNotEmpty && !rest.startsWith('#')) {
        map[key] = scalar(rest);
      } else if (i < lines.length && indentOf(lines[i]) > indent) {
        map[key] = block(indentOf(lines[i]));
      } else if (i < lines.length &&
          indentOf(lines[i]) == indent &&
          lines[i].trimLeft().startsWith('- ')) {
        map[key] = block(indent);
      } else {
        map[key] = null;
      }
    }
    return map;
  }

  return lines.isEmpty ? {} : block(0)! as Map<String, Object?>;
}

/// A short stable digest (FNV-1a, 64-bit as two 32-bit halves) of [s].
String _fnv1a(String s) {
  var h1 = 0x811c9dc5, h2 = 0x01000193;
  for (final unit in utf8.encode(s)) {
    h1 = ((h1 ^ unit) * 0x01000193) & 0xffffffff;
    h2 = ((h2 ^ unit) * 0x811c9dc5) & 0xffffffff;
  }
  return h1.toRadixString(16).padLeft(8, '0') +
      h2.toRadixString(16).padLeft(8, '0');
}
