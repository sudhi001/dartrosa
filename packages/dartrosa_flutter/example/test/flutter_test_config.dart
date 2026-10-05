// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Runs every test in this directory with Flutter's leak tracker: a
/// `testWidgets` fails if a disposable object it created (controller,
/// focus node, notifier, gesture recognizer, animation, picture, image
/// handle, ...) is not disposed. No class is excluded.
///
/// The global image cache, which the test binding keeps across tests,
/// holds a handle on every image decoded in a test; it is cleared after
/// each test, as an app clears it when its images are gone.
///
/// The tracker's experimental not-garbage-collected mode stays off here:
/// framework-owned references keep the last widget tree of a test alive
/// past the test (`TextInput`'s last connection, the test binding's
/// focused editable, the pipeline owner's pending semantics geometry, the
/// test restoration manager's channel handler, and platform channel calls
/// the test engine never answers), so every test with a text field or
/// semantics would be reported. dartrosa_flutter's `test/leak_test.dart` checks that
/// the renderer's own objects are garbage collected once a form is gone.
///
/// Run with `--dart-define=LEAK_STACK_TRACES=true` to see where a leaked
/// object was created (slow).
FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  if (const bool.fromEnvironment('LEAK_STACK_TRACES')) {
    LeakTesting.settings = LeakTesting.settings.withCreationStackTrace();
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages(),
  );
  await testMain();
}
