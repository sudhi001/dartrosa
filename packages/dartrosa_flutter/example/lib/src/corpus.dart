import 'dart:convert';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where tool/bundle_corpus.dart puts the corpus.
const corpusRoot = 'assets/forms';

/// A bundled conformance form.
class CorpusForm {
  /// Creates an entry for the form at [path] (relative to [corpusRoot]).
  const CorpusForm(
    this.path, {
    this.title,
    this.javarosaParses = true,
    this.javarosaInitializes = true,
  });

  /// The form's path, e.g. `collect/basic.xml`.
  final String path;

  /// Its `<h:title>`, if any.
  final String? title;

  /// Whether JavaRosa parses it (the oracle's `parse.ok`).
  final bool javarosaParses;

  /// Whether JavaRosa starts a new instance of it (the oracle's
  /// `initialize.ok`; plain JavaRosa lacks Collect's `pulldata()` and
  /// location, so some forms only start with the Collect services).
  final bool javarosaInitializes;

  /// The folder it and its media are in, e.g. `collect`.
  String get folder => path.substring(0, path.lastIndexOf('/'));

  /// Its file name.
  String get fileName => path.substring(path.lastIndexOf('/') + 1);

  /// The title, or the file name for untitled forms.
  String get displayTitle => title ?? fileName;
}

/// The bundled corpus: its forms and the files of each folder.
class Corpus {
  /// Creates a corpus.
  const Corpus(this.forms, this.files);

  /// Reads `index.json` written by tool/bundle_corpus.dart.
  factory Corpus.fromJson(String json) {
    final index = jsonDecode(json) as Map<String, Object?>;
    return Corpus(
      [
        for (final f
            in (index['forms']! as List<Object?>).cast<Map<String, Object?>>())
          CorpusForm(
            f['path']! as String,
            title: f['title'] as String?,
            javarosaParses: f['javarosaParses']! as bool,
            javarosaInitializes: f['javarosaInitializes']! as bool,
          ),
      ],
      {
        for (final MapEntry(:key, :value)
            in (index['files']! as Map<String, Object?>).entries)
          key: (value! as List<Object?>).cast<String>(),
      },
    );
  }

  /// Loads the corpus index from [bundle].
  static Future<Corpus> load(AssetBundle bundle) async =>
      Corpus.fromJson(await bundle.loadString('$corpusRoot/index.json'));

  /// The forms.
  final List<CorpusForm> forms;

  /// File names by folder.
  final Map<String, List<String>> files;

  /// The files next to [form] (its media, CSVs, GeoJSON, ...).
  List<String> mediaOf(CorpusForm form) => [
    for (final name in files[form.folder] ?? const <String>[])
      if (name != form.fileName) name,
  ];
}

/// Serves a form's `jr://` media (`jr://file/x`, `jr://images/x`,
/// `jr://file-csv/x`, ...) from the asset folder it was bundled in.
class AssetResolver implements ResourceResolver {
  /// Creates a resolver for the asset [folder] of [bundle].
  const AssetResolver(this.bundle, this.folder);

  /// The bundle read from.
  final AssetBundle bundle;

  /// The folder, relative to [corpusRoot].
  final String folder;

  /// The asset key of [uri], or `null` if it isn't a `jr://` URI.
  String? assetKey(String uri) {
    final match = RegExp(r'^jr://[^/]+/(.+)$').firstMatch(uri);
    return match == null ? null : '$corpusRoot/$folder/${match.group(1)}';
  }

  @override
  Future<Uint8List> read(String uri) async {
    final key = assetKey(uri);
    if (key == null) throw ResourceNotFoundException(uri);
    try {
      final data = await bundle.load(key);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on FlutterError {
      throw ResourceNotFoundException(uri);
    }
  }
}
