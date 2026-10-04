// Drives the app: fill, save a draft, resume, finalize, audit, edit,
// encrypt and export.
import 'dart:io';

import 'package:dartrosa_flutter_example/main.dart';
import 'package:dartrosa_flutter_example/src/corpus.dart';
import 'package:dartrosa_flutter_example/src/home.dart';
import 'package:dartrosa_flutter_example/src/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Workspace> _app(WidgetTester tester) async {
  final workspace = Workspace(
    Corpus.fromJson(File('$corpusRoot/index.json').readAsStringSync()),
  );
  await tester.pumpWidget(MaterialApp(home: HomeScreen(workspace: workspace)));
  return workspace;
}

/// Lets the form load (real asset reads), then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String path) async {
  await tester.enterText(find.byType(SearchBar), path);
  await tester.pump();
  await tester.tap(find.widgetWithText(ListTile, path));
  await _settle(tester);
}

Future<void> _finalize(WidgetTester tester) async {
  // Snack bars would cover the pager's buttons.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .clearSnackBars();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finalize'));
  await _settle(tester);
}

Future<void> _instanceMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await _settle(tester);
}

void main() {
  testWidgets('starts on the bundled form list', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await _settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Search 190 forms'), findsOneWidget);
  });

  testWidgets('fills, saves, resumes, finalizes and audits a form', (
    tester,
  ) async {
    final workspace = await _app(tester);
    expect(find.byType(ListTile), findsWidgets);

    await _open(tester, 'collect/one-question-audit.xml');
    expect(find.text('what is your age'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.byTooltip('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final draft = workspace.instances.single;
    expect(draft.finalized, isFalse);
    expect(draft.xml, contains('<age>42</age>'));

    // Resume the draft from the instances tab, then finalize it.
    await tester.tap(find.text('Instances'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('One Question Audit'));
    await _settle(tester);
    expect(find.text('42'), findsOneWidget);
    await _finalize(tester);
    expect(draft.finalized, isTrue);
    expect(workspace.outbox.single.files.keys, ['submission.xml']);

    await _instanceMenu(tester, 'Audit log');
    expect(find.text('event'), findsOneWidget);
    expect(find.text('form start'), findsOneWidget);
    expect(find.text('form resume'), findsOneWidget);
    expect(find.text('form finalize'), findsOneWidget);
  });

  testWidgets('finalizes, encrypts, exports and edits a form', (tester) async {
    final workspace = await _app(tester);
    await _open(tester, 'collect/encrypted.xml');
    await tester.enterText(find.byType(TextField), 'secret');
    await _finalize(tester);

    final original = workspace.outbox.single;
    expect(original.encrypted, isTrue);
    expect(
      original.files.keys,
      unorderedEquals(['submission.xml', 'submission.xml.enc']),
    );

    await tester.tap(find.text('Outbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Encrypted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('submission.xml'));
    await tester.pumpAndSettle();
    expect(find.textContaining('base64EncryptedKey'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Instances'));
    await tester.pumpAndSettle();
    await _instanceMenu(tester, 'Edit');
    expect(find.text('secret'), findsOneWidget);
    await _finalize(tester);

    final edit = workspace.instances.first;
    expect(edit.editOf, original.instance);
    expect(
      edit.xml,
      contains('<deprecatedID>${original.instance.instanceId}</deprecatedID>'),
    );
    expect(workspace.outbox, hasLength(2));
  });
}
