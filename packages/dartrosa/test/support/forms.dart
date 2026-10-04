/// Test helpers for loading conformance forms (VM only).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';

/// The repository's `conformance/` directory.
Directory conformanceDir() {
  for (var dir = Directory.current; ; dir = dir.parent) {
    final candidate = Directory('${dir.path}/conformance');
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) throw StateError('conformance/ not found');
  }
}

/// The conformance form called [name] (JavaRosa's
/// `ResourcePathHelper.r`). JavaRosa's resources are searched first, then
/// DartRosa's and ODK Collect's, since some file names repeat.
File formFile(String name) {
  final forms = '${conformanceDir().path}/forms';
  for (final dir in ['javarosa', 'dartrosa', 'collect']) {
    final root = Directory('$forms/$dir');
    if (!root.existsSync()) continue;
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (f.uri.pathSegments.last == name) return f;
    }
  }
  throw StateError('form $name not found');
}

/// Resolves `jr://<scheme>/x` to the file `x` in [dir].
final class DirectoryResolver implements ResourceResolver {
  /// Creates a resolver for [dir].
  DirectoryResolver(this.dir);

  /// The directory files are read from.
  final Directory dir;

  @override
  Future<Uint8List> read(String uri) async {
    final match = RegExp(r'^jr://[^/]+/(.*)$').firstMatch(uri);
    final file = File('${dir.path}/${match?.group(1) ?? uri}');
    if (!file.existsSync()) throw ResourceNotFoundException(uri);
    return file.readAsBytes();
  }
}

/// Parses the form [file], resolving `jr://` files next to it.
Future<FormDef> parseFile(File file, {String? lastSavedSrc}) => XFormParser(
  resolver: DirectoryResolver(file.parent),
).parse(file.readAsStringSync(), lastSavedSrc: lastSavedSrc);

/// Parses the conformance form [name].
Future<FormDef> parseForm(String name, {String? lastSavedSrc}) {
  final file = formFile(name);
  return XFormParser(
    resolver: DirectoryResolver(file.parent),
  ).parse(file.readAsStringSync(), lastSavedSrc: lastSavedSrc);
}

/// Parses form XML [xml] (e.g. built with the testing DSL).
Future<FormDef> parseXml(String xml) => XFormParser().parse(xml);

/// Why a comparison with oracle traces that contain local date-times is
/// skipped: the JVM oracle runs with TZ=UTC. `null` in UTC.
String? get skipUnlessUtc =>
    DateTime(2018).timeZoneOffset == Duration.zero &&
        DateTime(2018, 7).timeZoneOffset == Duration.zero
    ? null
    : 'oracle traces are recorded with TZ=UTC';

/// A [Scenario] for the conformance form [name] (JavaRosa's
/// `Scenario.init(String formFileName)`), resolving `jr://` files next to
/// it.
Future<Scenario> scenarioFor(String name) async =>
    Scenario.fromFormDef(await parseForm(name));
