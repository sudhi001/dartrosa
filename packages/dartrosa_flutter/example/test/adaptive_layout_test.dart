// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The app's layout per window size, the unsaved-changes prompt and the
// desktop shortcuts.
import 'dart:io';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:dartrosa_flutter_example/src/corpus.dart';
import 'package:dartrosa_flutter_example/src/fill_screen.dart';
import 'package:dartrosa_flutter_example/src/home.dart';
import 'package:dartrosa_flutter_example/src/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Workspace> _app(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = Workspace(
    Corpus.fromJson(File('$corpusRoot/index.json').readAsStringSync()),
  );
  addTearDown(workspace.dispose);
  await tester.pumpWidget(MaterialApp(home: HomeScreen(workspace: workspace)));
  await tester.pumpAndSettle();
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

/// The form's first text field (not the forms search).
final _formField = find
    .descendant(of: find.byType(XFormView), matching: find.byType(TextField))
    .first;

void main() {
  // The bundle caches loads as futures of the test that made them, which
  // never complete in a later test.
  tearDown(rootBundle.clear);

  testWidgets('phones: navigation bar; a form opens full screen', (
    tester,
  ) async {
    await _app(tester, const Size(360, 780));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await _open(tester, 'collect/form8.xml');
    expect(find.byType(FillScreen), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium: navigation rail; a form opens full screen', (
    tester,
  ) async {
    await _app(tester, const Size(700, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Outbox'));
    await tester.pumpAndSettle();
    expect(find.text('Finalized forms are exported here.'), findsOneWidget);
  });

  testWidgets('wide: the form opens beside the list and survives resizing', (
    tester,
  ) async {
    await _app(tester, const Size(1440, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Choose a form to fill'), findsOneWidget);
    await _open(tester, 'collect/form8.xml');
    // List and form side by side, with the form's outline panel.
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.byType(FillScreen), findsOneWidget);
    expect(find.text('Form outline'), findsOneWidget);
    await tester.enterText(_formField, 'Amina');
    await tester.pump();

    // Narrower: the form fills the window, with its answer kept.
    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsNothing);
    expect(find.text('Amina'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Closing asks about the unsaved answer.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Leave this form?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Amina'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(find.byType(FillScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('saving from the prompt keeps a draft', (tester) async {
    final workspace = await _app(tester, const Size(1280, 800));
    await _open(tester, 'collect/form8.xml');
    await tester.enterText(_formField, 'Amina');
    await tester.pump();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await _settle(tester);
    expect(find.byType(FillScreen), findsNothing);
    expect(workspace.instances, hasLength(1));
    expect(workspace.instances.single.xml, contains('Amina'));
  });

  testWidgets('keyboard: Ctrl+S saves, Ctrl+F searches', (tester) async {
    final workspace = await _app(tester, const Size(1280, 800));
    await _open(tester, 'collect/form8.xml');
    await tester.enterText(_formField, 'Amina');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(find.text('Draft saved'), findsOneWidget);
    expect(workspace.instances, hasLength(1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final search = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(search.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the app bar opens the outline on phones', (tester) async {
    await _app(tester, const Size(360, 780));
    await _open(tester, 'collect/form8.xml');
    await tester.tap(find.byTooltip('Form outline').first);
    await tester.pumpAndSettle();
    expect(find.text('Form outline'), findsOneWidget);
    expect(find.byType(XFormView), findsOneWidget);
  });
}
