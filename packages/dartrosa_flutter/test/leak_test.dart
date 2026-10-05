// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The renderer's own objects are garbage collected once a form is gone
// (flutter_test_config.dart checks that everything is disposed).
import 'dart:developer' show reachabilityBarrier;

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<FormSession> _form() => formSession(
  '<a/><b/><g><c/></g>',
  '<bind nodeset="/data/b" type="string" relevant="/data/a = \'y\'"/>',
  '<select1 ref="/data/a"><label>A</label>${items(['Y', 'N'])}</select1>'
      '<input ref="/data/b"><label>B</label></input>'
      '<group ref="/data/g"><label>G</label>'
      '<input ref="/data/g/c"><label>C</label></input></group>',
);

/// The controller of the form shown by [tester].
XFormController _controller(WidgetTester tester) =>
    XFormScope.of(tester.element(find.byType(QuestionWidget).first)).controller;

/// Allocates until the VM has run [cycles] full garbage collections (as
/// leak_tracker's `forceGC` does).
Future<void> _forceGC({int cycles = 3}) async {
  final barrier = reachabilityBarrier;
  final storage = <List<int>>[];
  while (reachabilityBarrier < barrier + cycles) {
    await Future<void>.delayed(Duration.zero);
    storage.add(List.generate(30000, (n) => n));
    if (storage.length > 100) storage.removeAt(0);
  }
}

Future<void> _expectCollected(
  WidgetTester tester,
  WeakReference<Object> reference,
) async {
  await tester.runAsync(_forceGC);
  expect(reference.target, isNull);
}

void main() {
  // The framework's platform channel calls (tap feedback, clipboard
  // checks, ...) wait for an answer the test engine never gives, holding
  // their callers' widgets; answer them.
  const channels = [SystemChannels.platform, SystemChannels.processText];
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  setUp(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final mode in XFormMode.values) {
    testWidgets('${mode.name} mode: the controller is collected', (
      tester,
    ) async {
      final session = await _form();
      await tester.pumpWidget(app(XFormView(session: session, mode: mode)));
      await tester.pump();
      final controller = WeakReference<Object>(_controller(tester));
      if (mode == XFormMode.scroll) {
        await tester.tap(find.text('Y'));
        await tester.pump();
        expect(find.text('B'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      // Ink splashes and other timers end.
      await tester.pumpAndSettle();
      // The session outlives the view; it must not keep the view alive.
      expect(session.root.children, isNotEmpty);
      await _expectCollected(tester, controller);
    });
  }

  testWidgets('a new session replaces the controller and its listeners', (
    tester,
  ) async {
    final first = await _form();
    final second = await _form();
    await tester.pumpWidget(
      app(XFormView(session: first, mode: XFormMode.scroll)),
    );
    final old = WeakReference<Object>(_controller(tester));
    await tester.pumpWidget(
      app(XFormView(session: second, mode: XFormMode.scroll)),
    );
    expect(_controller(tester).session, same(second));

    // Answers to the old session no longer reach the view.
    first.answer(question(first, 0).index, const StringValue('y'));
    await tester.pump();
    expect(find.text('B'), findsNothing);
    await _expectCollected(tester, old);

    await tester.tap(find.text('Y'));
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
  });
}
