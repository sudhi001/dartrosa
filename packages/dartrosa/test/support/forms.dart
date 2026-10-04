/// Test helpers for loading conformance forms (VM only).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';

/// The repository's `conformance/` directory.
Directory conformanceDir() {
  for (var dir = Directory.current; ; dir = dir.parent) {
    final candidate = Directory('${dir.path}/conformance');
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) throw StateError('conformance/ not found');
  }
}

/// The conformance form called [name], wherever it is under `forms/`
/// (port of JavaRosa's `ResourcePathHelper.r`).
File formFile(String name) {
  final forms = Directory('${conformanceDir().path}/forms');
  return forms
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere(
        (f) => f.uri.pathSegments.last == name,
        orElse: () => throw StateError('form $name not found'),
      );
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

/// Parses the conformance form [name].
Future<FormDef> parseForm(String name, {String? lastSavedSrc}) {
  final file = formFile(name);
  return XFormParser(
    resolver: DirectoryResolver(file.parent),
  ).parse(file.readAsStringSync(), lastSavedSrc: lastSavedSrc);
}

/// Parses form XML [xml] (e.g. built with the testing DSL).
Future<FormDef> parseXml(String xml) => XFormParser().parse(xml);
