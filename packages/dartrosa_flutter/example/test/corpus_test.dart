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
const _debugDrafts = bool.fromEnvironment('DEBUG_DRAFTS');

/// Forms whose walk fails because of an engine or renderer bug, with the
/// reason (each reproduced in test/known_issues/).
const _knownIssues = <String, String>{};

/// Forms ODK Collect can't load either, though plain JavaRosa parses them.
const _collectRejects = {
  'collect/one-question-entity-registration-broken.xml':
      'unknown entities version 2452.2.0',
  'collect/one-question-entity-registration-v2020.1.xml':
      'entities version 2020.1.0 predates the supported 2022.1.0',
};

/// Forms whose drafts can't be resumed, as in JavaRosa.
const _unresumable = {
  'javarosa/sms_form.xml':
      'the model repeats non-repeat elements (child_full_name) inside the '
      "repeat /data/children: JavaRosa's TreeElement.populate fails its "
      '"sanity check" loading any instance of it',
};

void main() {
  final corpus = Corpus.fromJson(
    File('$corpusRoot/index.json').readAsStringSync(),
  );
  final outcomes = <String, String>{};

  tearDownAll(() {
    final counts = <String, int>{};
    for (final outcome in outcomes.values) {
      final kind = outcome.split(RegExp(r'[:(\[]')).first.trim();
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
      // Report the renderer's known bugs (test/known_issues/) instead of
      // failing; errors after a duplicate key are its consequences.
      final known = <String>{};
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        final issue =
            _knownError(details) ??
            (known.contains(_duplicateKeys) ? _duplicateKeys : null);
        if (issue == null) {
          onError?.call(details);
        } else {
          known.add(issue);
        }
      };
      try {
        final outcome = await _fill(tester, Workspace(corpus), form);
        outcomes[form.path] = known.isEmpty
            ? outcome
            : '$outcome [known: ${known.join(', ')}]';
      } finally {
        FlutterError.onError = onError;
      }
    });
  }
}

const _duplicateKeys = 'duplicate group keys';

/// The known renderer bug [details] reports, if it is one.
String? _knownError(FlutterErrorDetails details) {
  final message = '${details.exception}';
  if (message.contains('called during build') &&
      '${details.stack}'.contains('FormEntryPrompt.selectChoices')) {
    return 'itemset setState during build';
  }
  if (message.contains('Duplicate keys found') && message.contains("'g:")) {
    return _duplicateKeys;
  }
  return null;
}

/// Loads [f], or returns why it can't be loaded.
Future<(FormDefinition?, Object?)> _try(
  WidgetTester tester,
  Workspace w,
  CorpusForm f,
) async => (await tester.runAsync(() async {
  try {
    return (await w.load(f), null);
  } on Object catch (e) {
    return (null, e);
  }
}))!;

Future<FormDefinition> _load(
  WidgetTester tester,
  Workspace w,
  CorpusForm f,
) async => switch (await _try(tester, w, f)) {
  (final definition?, _) => definition,
  (_, final error) => throw StateError('reload failed: $error'),
};

/// Shows [session] in a pager.
Future<void> _show(
  WidgetTester tester,
  Workspace workspace,
  FormSession session,
  CorpusForm form, {
  ValueChanged<Submission>? onFinalized,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: XFormView(
          key: UniqueKey(),
          session: session,
          delegates: AssetDelegates(
            AssetResolver(workspace.bundle, form.folder),
            workspace.corpus.mediaOf(form),
          ),
          widgetOverrides: externalChoiceOverrides,
          onFinalized: onFinalized,
        ),
      ),
    ),
  );
  await tester.pump();
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
  final (definition, error) = await _try(tester, workspace, form);
  if (definition == null) {
    if (_collectRejects[form.path] case final reason?) {
      return 'rejected (as by Collect: $reason)';
    }
    expect(form.javarosaParses, isFalse, reason: 'JavaRosa loads it: $error');
    return 'rejected (as by JavaRosa)';
  }
  expect(form.javarosaParses, isTrue, reason: 'JavaRosa rejects it');
  expect(_collectRejects[form.path], isNull, reason: 'Collect rejects it');

  // Walk the pager, answering every question.
  final instance = workspace.newInstance(form);
  final FormSession session;
  try {
    session = workspace.open(definition, instance);
  } on Object catch (e) {
    expect(form.javarosaInitializes, isFalse, reason: 'JavaRosa starts it: $e');
    return 'rejected (as by JavaRosa: new instance fails: $e)';
  }
  final rng = Rng(seedOf(form.path));
  Submission? submission;
  await _show(
    tester,
    workspace,
    session,
    form,
    onFinalized: (s) => submission = s,
  );
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
  final reloaded = await _load(tester, workspace, form);
  if (_unresumable[form.path] case final reason?) {
    expect(() => workspace.open(reloaded, resumedRecord), throwsStateError);
    notes.add('draft not resumable, as in JavaRosa: $reason');
    return _outcome(blocked, invalid, notes);
  }
  final resumed = workspace.open(reloaded, resumedRecord);
  // Calculations run again on load, as in JavaRosa: uuid() instance IDs
  // and entity IDs change, calculated answers are restored.
  String withoutIds(String xml) =>
      xml.replaceAll(RegExp('<instanceID>[^<]*</instanceID>'), '');
  if (withoutIds(resumed.saveDraft()) != withoutIds(draft)) {
    notes.add('recalculated on resume');
    if (_debugDrafts) {
      stdout.writeln('${form.path}\n$draft\n${resumed.saveDraft()}');
    }
  }
  await _show(tester, workspace, resumed, form);
  if ((resumed.finalize() is FinalizeSuccess) != (invalid == null)) {
    notes.add('resumed draft validates differently');
  }

  // Edit the finalized instance (edits need a meta/instanceID).
  if (exported != null && submission?.instanceId != null) {
    final edit = workspace.newInstance(form, editOf: exported.instance);
    final editing = workspace.open(await _load(tester, workspace, form), edit);
    await _show(tester, workspace, editing, form);
    switch (editing.finalize()) {
      case FinalizeSuccess(submission: final s):
        // The edit keeps the ID it was loaded with as meta/deprecatedID
        // (forms calculating it with uuid() get a new one on every load,
        // as in JavaRosa).
        final deprecated = RegExp(
          '<deprecatedID>([^<]*)<',
        ).firstMatch(s.xml)?.group(1);
        expect(deprecated, isNotNull, reason: 'the edit has a deprecatedID');
        expect(s.instanceId, isNot(deprecated));
        if (deprecated != submission?.instanceId) notes.add('new ID on load');
        notes.add('edited');
      case FinalizeFailure(:final failure):
        notes.add('edit invalid: ${_describe(failure)}');
    }
  }

  return _outcome(blocked, invalid, notes);
}

String _outcome(
  String? blocked,
  ValidationFailure? invalid,
  List<String> notes,
) {
  final suffix = notes.isEmpty ? '' : ' (${notes.join(', ')})';
  if (invalid != null) {
    return '${blocked != null ? 'blocked' : 'invalid'}: ${_describe(invalid)}$suffix';
  }
  return 'finalized$suffix';
}
