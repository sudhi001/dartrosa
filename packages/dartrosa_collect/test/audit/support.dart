// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';

/// Given an XPath path, a fake [FormIndex] whose levels have the instance
/// indexes of the path's repeat positions (and the whole reference), like
/// `getTestFormIndex` in Collect's `AsyncTaskAuditEventWriterTest`.
FormIndex getTestFormIndex(String xpathPath) {
  final nodes = xpathPath.split('/').skip(1).toList(); // leading /
  var treeReference = const TreeReference.root();
  final positions = <int>[];
  for (final node in nodes) {
    final parts = node.split('[');
    final nodeName = parts[0];
    var position = 0;
    if (parts.length > 1) {
      position = int.parse(parts[1].replaceAll(']', '')) - 1;
      positions.add(position);
    } else {
      positions.add(-1);
    }
    treeReference = treeReference.extend(nodeName, position);
  }
  FormIndex? formIndex;
  for (var i = nodes.length - 1; i > 0; i--) {
    // exclude the root node
    formIndex = FormIndex(
      -1,
      instanceIndex: positions[i],
      nextLevel: formIndex,
      reference: treeReference,
    );
  }
  return formIndex!;
}

/// `/data/text1` as a one-level index, like Collect's
/// `AuditEventCSVLineTest.getTestFormIndex`.
FormIndex text1Index() => FormIndex(
  0,
  reference: const TreeReference.root().extend('data', 0).extend('text1', 0),
);

/// A clock that only moves when told to.
final class FakeAuditClock implements AuditClock {
  /// Creates the clock at [now] (and elapsed time 0).
  FakeAuditClock([this.now = 1000]);

  /// Milliseconds since the epoch.
  int now;

  /// Monotonic milliseconds.
  int elapsed = 0;

  /// Moves both clocks forward by [ms].
  void advance(int ms) {
    now += ms;
    elapsed += ms;
  }

  @override
  int currentTimeMillis() => now;

  @override
  int elapsedRealtime() => elapsed;
}

/// Collects written events (Collect's `TestWriter`).
final class TestWriter implements AuditEventWriter {
  /// The events written.
  final auditEvents = <AuditEvent>[];

  @override
  void writeEvents(List<AuditEvent> auditEvents) =>
      this.auditEvents.addAll(auditEvents);

  @override
  bool get isWriting => false;
}

/// A form state answering "The answer" everywhere, with no field lists
/// (Collect's mocked `FormController`).
final class FakeFormState implements AuditFormState {
  @override
  String? answerDisplayText(FormIndex? index) => 'The answer';

  @override
  bool indexIsInFieldList(FormIndex? index) => false;
}
