// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Fills, saves, resumes, edits, finalizes, encrypts and exports the
// DartRosa conformance corpus. Bundle the corpus with
// `dart run tool/bundle_corpus.dart`, add platforms with `flutter create .`
// in this directory, then `flutter run`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/corpus.dart';
import 'src/home.dart';
import 'src/workspace.dart';

void main() => runApp(const ExampleApp());

/// The example app.
class ExampleApp extends StatefulWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final Future<Workspace> _workspace = Corpus.load(
    rootBundle,
  ).then(Workspace.new);

  @override
  void dispose() {
    // The workspace is a ChangeNotifier owned by the app.
    _workspace
        .then((workspace) => workspace.dispose(), onError: (_) {})
        .ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DartRosa',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    ),
    home: FutureBuilder(
      future: _workspace,
      builder: (context, snapshot) => switch (snapshot.data) {
        final workspace? => HomeScreen(workspace: workspace),
        null => Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Text('Run tool/bundle_corpus.dart: ${snapshot.error}')
                : const CircularProgressIndicator(),
          ),
        ),
      },
    ),
  );
}
