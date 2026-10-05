// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Rebuild budgets: answering a question rebuilds that question and its
// dependents, not the form; long forms build lazily. The counts are
// printed so that regressions show in the test log (see the package
// README, "Performance").
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets show debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Builds of each widget type while [action] runs.
Future<Map<Type, int>> _builds(Future<void> Function() action) async {
  final counts = <Type, int>{};
  widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
    final type = element.widget.runtimeType;
    counts[type] = (counts[type] ?? 0) + 1;
  };
  try {
    await action();
  } finally {
    widgets.debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

/// The number of question bodies (their labels) built.
int _questions(Map<Type, int> builds) => builds[XFormLabel] ?? 0;

/// A flat form of [count] text questions `q0`, `q1`, ...: `q1` must not
/// be `bad`, and `q2` is shown once `q0` is answered.
Future<FormSession> _longForm(int count) => formSession(
  [for (var i = 0; i < count; i++) '<q$i/>'].join(),
  [
    for (var i = 0; i < count; i++)
      '<bind nodeset="/data/q$i" type="string"'
          '${switch (i) {
            1 => ' constraint=". != \'bad\'"',
            2 => ' relevant="/data/q0 != \'\'"',
            _ => '',
          }}/>',
  ].join(),
  [
    for (var i = 0; i < count; i++)
      '<input ref="/data/q$i"><label>Question $i</label></input>',
  ].join(),
);

void _report(String name, Object value) =>
    debugPrint('rebuild budget | $name: $value');

void main() {
  testWidgets('scroll mode builds lazily and answers rebuild one question', (
    tester,
  ) async {
    final session = await _longForm(1000);
    late Map<Type, int> builds;
    final stopwatch = Stopwatch()..start();
    builds = await _builds(
      () => tester.pumpWidget(
        app(XFormView(session: session, mode: XFormMode.scroll)),
      ),
    );
    _report(
      'first build of 1000 questions, questions built',
      _questions(builds),
    );
    _report('first build, ms', stopwatch.elapsedMilliseconds);
    expect(_questions(builds), lessThan(30));

    // q3 has no dependents: only it rebuilds.
    builds = await _builds(() async {
      await tester.enterText(find.byType(TextField).at(2), 'x');
      await tester.pump();
    });
    _report('answer without dependents, questions rebuilt', _questions(builds));
    expect(_questions(builds), lessThanOrEqualTo(1));

    // q1 has a constraint (the engine reports it as a condition).
    builds = await _builds(() async {
      await tester.enterText(find.byType(TextField).at(1), 'ok');
      await tester.pump();
    });
    _report('answer with a constraint, questions rebuilt', _questions(builds));
    expect(_questions(builds), lessThanOrEqualTo(1));

    // q0 makes q2 relevant: q0 and the newly shown q2 build.
    builds = await _builds(() async {
      await tester.enterText(find.byType(TextField).at(0), 'x');
      await tester.pump();
    });
    expect(find.text('Question 2'), findsOneWidget);
    _report('answer showing a question, questions rebuilt', _questions(builds));
    expect(_questions(builds), lessThanOrEqualTo(2));

    // Scrolling to the end builds each question about once.
    var frames = 0;
    stopwatch.reset();
    builds = await _builds(() async {
      await tester.scrollUntilVisible(
        find.text(const XFormLocalizations().finish),
        3000,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 1000,
      );
      frames = await tester.pumpAndSettle();
    });
    _report('scroll to the end, questions built', _questions(builds));
    _report('scroll to the end, ms', stopwatch.elapsedMilliseconds);
    _report('scroll to the end, settle frames', frames);
    expect(_questions(builds), lessThan(1100));
  });

  testWidgets('pager mode: an answer rebuilds its dependents, not the page', (
    tester,
  ) async {
    final session = await formSession(
      '<g>${[for (var i = 0; i < 20; i++) '<q$i/>'].join()}</g>',
      // q0 has a constraint, q1 is shown once q0 is answered.
      '<bind nodeset="/data/g/q0" type="string" constraint=". != \'bad\'"/>'
          '<bind nodeset="/data/g/q1" type="string" '
          'relevant="/data/g/q0 != \'\'"/>',
      '<group ref="/data/g" appearance="field-list">'
          '${[for (var i = 0; i < 20; i++) '<input ref="/data/g/q$i"><label>Q$i</label></input>'].join()}'
          '</group>',
    );
    await tester.pumpWidget(app(XFormView(session: session)));
    final builds = await _builds(() async {
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.pump();
    });
    expect(find.text('Q1'), findsOneWidget);
    _report('pager field-list of 20, questions rebuilt', _questions(builds));
    expect(_questions(builds), lessThanOrEqualTo(2));
  });

  testWidgets('relevance and read-only reach nested and repeated questions', (
    tester,
  ) async {
    // `s` shows `g/b` and each repeat instance's `r/c`, and makes the
    // group `g` (so the number `g/a`) read-only.
    final session = await formSession(
      '<s/><g><a/><b/></g><r><c/></r>',
      '<bind nodeset="/data/g" readonly="/data/s = \'y\'"/>'
          '<bind nodeset="/data/g/a" type="int"/>'
          '<bind nodeset="/data/g/b" type="string" relevant="/data/s = \'y\'"/>'
          '<bind nodeset="/data/r" relevant="/data/s = \'y\'"/>'
          '<bind nodeset="/data/r/c" type="string"/>',
      '<select1 ref="/data/s"><label>S</label>${items(['Y', 'N'])}</select1>'
          '<group ref="/data/g"><label>G</label>'
          '<input ref="/data/g/a"><label>A</label></input>'
          '<input ref="/data/g/b"><label>B</label></input></group>'
          '<repeat nodeset="/data/r"><input ref="/data/r/c">'
          '<label>C</label></input></repeat>',
    );
    await tester.pumpWidget(
      app(XFormView(session: session, mode: XFormMode.scroll)),
    );
    // Read-only, the answer shows as text in place of the field.
    bool aEnabled() => find
        .descendant(
          of: find.widgetWithText(QuestionWidget, 'A'),
          matching: find.byType(TextField),
        )
        .evaluate()
        .isNotEmpty;
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsNothing);
    expect(aEnabled(), isTrue);

    await tester.tap(find.text('Y'));
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(aEnabled(), isFalse);

    await tester.tap(find.text('N'));
    await tester.pump();
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsNothing);
    expect(aEnabled(), isTrue);
  });
}
