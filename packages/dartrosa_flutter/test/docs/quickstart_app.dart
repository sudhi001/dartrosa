// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The app of docs/QUICKSTART.md, as the reader's lib/main.dart; run by
// quickstart_test.dart (packages/dartrosa/test/docs checks that the
// quick start's snippets are here).
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final xml = await rootBundle.loadString('assets/visit.xml');
  final definition = await FormDefinition.parse(xml);
  runApp(QuickStartApp(session: definition.createSession()));
}

class QuickStartApp extends StatelessWidget {
  const QuickStartApp({required this.session, super.key});

  final FormSession session;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: Scaffold(
      appBar: AppBar(title: Text(session.definition.title ?? 'Form')),
      body: XFormView(
        session: session,
        onFinalized: (submission) {
          // The finished form, ready to save or upload.
          debugPrint(submission.xml);
        },
      ),
    ),
  );
}
