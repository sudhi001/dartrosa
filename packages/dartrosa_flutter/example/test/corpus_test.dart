// Fills every bundled corpus form through the pager, finalizes it, saves a
// draft and resumes it, edits the finalized instance and encrypts and
// exports it when the form asks for it. Prints a per-form summary.
import 'dart:io';

import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:dartrosa_flutter_example/src/corpus.dart';
import 'package:dartrosa_flutter_example/src/external_choices.dart';
import 'package:dartrosa_flutter_example/src/fill_screen.dart';
import 'package:dartrosa_flutter_example/src/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/answers.dart';

const _strings = XFormLocalizations();
const _maxScreens = 300;

/// Forms whose walk fails because of an engine or renderer bug, with the
/// reason (each reproduced in test/known_issues/).
const _knownIssues = <String, String>{};

void main() {
  final corpus = Corpus.fromJson(
    File('$corpusRoot/index.json').readAsStringSync(),
  );
  final outcomes = <String, String>{};

  tearDownAll(() {
    final counts = <String, int>{};
    for (final outcome in outcomes.values) {
      final kind = outcome.split(':').first.split(' (').first;
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    stdout
      ..writeln('\nCorpus: ${outcomes.length} forms')
      ..writeln(
        [for (final e in counts.entries) '${e.key}: ${e.value}'].join(', '),
      );
    for (final MapEntry(:key, :value) in outcomes.entries) {
      stdout.writeln('  $key: $value');
    }
  });

  for (final form in corpus.forms) {
    testWidgets(form.path, skip: _knownIssues.containsKey(form.path), (
      tester,
    ) async {
      outcomes[form.path] = await _fill(tester, Workspace(corpus), form);
    });
  }
}

Future<FormDefinition?> _load(WidgetTester tester, Workspace w, CorpusForm f) =>
    tester.runAsync(() => w.load(f));

Future<Submission?> _show(
  WidgetTester tester,
  Workspace workspace,
  FormSession session,
  CorpusForm form,
) async {
  Submission? submission;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: XFormView(
          key: UniqueKey(),
          session: session,
          delegates: AssetDelegates(
            AssetResolver(workspace.bundle, form.folder),
          ),
          widgetOverrides: externalChoiceOverrides,
          onFinalized: (s) => submission = s,
        ),
      ),
    ),
  );
  await tester.pump();
  return submission;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last, warnIfMissed: false);
  await tester.pump();
}

String _describe(ValidationFailure failure) =>
    '${failure.result is AnswerRequired ? 'required' : 'constraint'} '
    '${failure.index.reference}';

/// Fills [form]; returns its outcome.
Future<String> _fill(
  WidgetTester tester,
  Workspace workspace,
  CorpusForm form,
) async {
  final FormDefinition definition;
  try {
    definition = (await _load(tester, workspace, form))!;
  } on Object catch (e) {
    expect(form.javarosaParses, isFalse, reason: 'JavaRosa loads it: $e');
    return 'rejected (as by JavaRosa)';
  }
  expect(form.javarosaParses, isTrue, reason: 'JavaRosa rejects it');

  // Walk the pager, answering every question.
  final instance = workspace.newInstance(form);
  final session = workspace.open(definition, instance);
  final rng = Rng(seedOf(form.path));
  Submission? submission;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: XFormView(
          session: session,
          delegates: AssetDelegates(
            AssetResolver(workspace.bundle, form.folder),
          ),
          widgetOverrides: externalChoiceOverrides,
          onFinalized: (s) => submission = s,
        ),
      ),
    ),
  );
  await tester.pump();
  final nav = session.navigator;
  String? blocked;
  var repeats = 0;
  for (var screen = 0; screen < _maxScreens; screen++) {
    final event = nav.event;
    if (event == FormEntryEvent.endOfForm) break;
    if (event == FormEntryEvent.promptNewRepeat) {
      final add = repeats < 3 && rng.next(2) == 0;
      if (add) repeats++;
      await _tap(tester, add ? _strings.addGroup : _strings.doNotAdd);
      continue;
    }
    final rejected = answerScreen(rng, session, nav.current);
    await tester.pump();
    final before = nav.position;
    await _tap(tester, _strings.next);
    if (nav.position == before) {
      blocked = '${(rejected.firstOrNull ?? nav.current).ref}';
      break;
    }
  }
  if (blocked == null && nav.event != FormEntryEvent.endOfForm) {
    blocked = 'more than $_maxScreens screens';
  }

  // Save a draft, then finalize.
  await workspace.saveDraft(instance, session);
  final draft = instance.xml;
  final ValidationFailure? invalid;
  if (blocked == null) {
    await _tap(tester, _strings.finalize);
    invalid = submission == null
        ? (session.finalize() as FinalizeFailure).failure
        : null;
  } else {
    switch (session.finalize()) {
      case FinalizeSuccess(submission: final s):
        submission = s;
        invalid = null;
      case FinalizeFailure(:final failure):
        invalid = failure;
    }
  }
  final notes = <String>[];
  OutboxEntry? exported;
  if (submission case final s?) {
    try {
      exported = await workspace.finalize(instance, session, s);
      if (exported.encrypted) notes.add('encrypted');
      if (exported.entities > 0) notes.add('${exported.entities} entities');
    } on EncryptionException catch (e) {
      notes.add('encryption failed: ${e.message}');
    }
  }

  // Resume the draft: same instance, same validity.
  final resumedRecord = workspace.newInstance(form)..xml = draft;
  final resumed = workspace.open(
    (await _load(tester, workspace, form))!,
    resumedRecord,
  );
  if (resumed.saveDraft() != draft) notes.add('resumed draft differs');
  await _show(tester, workspace, resumed, form);
  if ((resumed.finalize() is FinalizeSuccess) != (invalid == null)) {
    notes.add('resumed draft validates differently');
  }

  // Edit the finalized instance (edits need a meta/instanceID).
  if (exported != null && submission?.instanceId != null) {
    final edit = workspace.newInstance(form, editOf: exported.instance);
    final editing = workspace.open(
      (await _load(tester, workspace, form))!,
      edit,
    );
    await _show(tester, workspace, editing, form);
    switch (editing.finalize()) {
      case FinalizeSuccess(submission: final s):
        expect(
          s.xml,
          contains('<deprecatedID>${submission?.instanceId}'),
          reason: 'the edit deprecates the original instance ID',
        );
        notes.add('edited');
      case FinalizeFailure(:final failure):
        notes.add('edit invalid: ${_describe(failure)}');
    }
  }

  final suffix = notes.isEmpty ? '' : ' (${notes.join(', ')})';
  if (invalid != null) {
    return '${blocked != null ? 'blocked' : 'invalid'}: ${_describe(invalid)}$suffix';
  }
  return 'finalized$suffix';
}
