// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart' show FormInstance, TreeElement;
import 'package:flutter/foundation.dart';

import 'localizations.dart';

/// Owns a [FormSession] for widgets: answers questions, remembers the
/// last answer error per question, and notifies only the widgets whose
/// nodes changed.
///
/// The session stays the single source of truth; widgets read node state
/// from it when notified. Listeners of the controller itself hear only
/// structural changes (repeat instances added or removed, the language).
/// The widgets of a node listen to [listenableFor] its reference, which
/// also hears changes of the node's own state (value, answer error,
/// relevance, read-only, required), of state its ancestors pass down to
/// it, and of the relevance of its children.
class XFormController extends ChangeNotifier {
  /// Creates a controller for [session].
  XFormController(this.session) {
    _subscription = session.changes.listen(_onChange);
    _learnRelevance();
  }

  /// The form being filled.
  final FormSession session;

  late final StreamSubscription<FormChange> _subscription;
  final Map<String, _RefNotifier> _byRef = {};
  final Map<String, Listenable> _merged = {};
  final Map<String, AnswerResult> _errors = {};

  /// The last known relevance of each instance node, by reference.
  final Map<String, bool> _relevance = {};

  /// The key of the form's root, whose children are the top-level nodes.
  static const _rootKey = 'null';

  /// Notified on changes of the node at [ref] (of the form's root, whose
  /// children are the top-level nodes, for a `null` [ref]) and on
  /// structural changes (repeats, language). Use with
  /// `ListenableBuilder`; the same listenable is returned for a ref, so
  /// rebuilds don't resubscribe.
  Listenable listenableFor(TreeReference? ref) {
    final key = ref == null ? _rootKey : '$ref';
    return _merged.putIfAbsent(key, () {
      final notifier = _byRef.putIfAbsent(key, _RefNotifier.new);
      return Listenable.merge([this, notifier]);
    });
  }

  FormInstance get _instance => session.definition.formDef.mainInstance;

  void _bump(String key) => _byRef[key]?.bump();

  /// Notifies the listeners of [ref] and of its generic form (all repeat
  /// instances).
  void _bumpRef(TreeReference ref) {
    _bump('${ref.genericize()}');
    _bump('$ref');
  }

  void _onChange(FormChange change) {
    switch (change.kind) {
      case 'repeat' || 'language':
        _learnRelevance();
        _prune();
        notifyListeners();
      case 'condition':
        _onCondition(change.refs);
      default:
        change.refs.forEach(_bumpRef);
    }
  }

  /// Relevance, read-only or required recomputed, or a constraint
  /// checked: the nodes and the descendants inheriting their state are
  /// notified, and when a node's relevance flipped, so is its parent,
  /// which lists it.
  void _onCondition(List<TreeReference> refs) {
    final root = _instance.root;
    final parents = <String>{};
    for (final ref in refs) {
      final element = _instance.resolveReference(ref);
      if (element == null) {
        _bumpRef(ref);
        continue;
      }
      _forSubtree(element, (e) => _bumpRef(e.ref));
      if (_relevance['${element.ref}'] == element.isRelevant) continue;
      _forSubtree(element, (e) => _relevance['${e.ref}'] = e.isRelevant);
      final parent = element.parent;
      parents
        ..add(
          parent == null || identical(parent, root)
              ? _rootKey
              : '${parent.ref}',
        )
        // A repeat lists its instances.
        ..add('${element.ref.genericize()}');
    }
    parents.forEach(_bump);
  }

  /// Records the relevance of every node of the instance.
  void _learnRelevance() {
    _relevance.clear();
    _forSubtree(_instance.root, (e) => _relevance['${e.ref}'] = e.isRelevant);
  }

  static void _forSubtree(
    TreeElement element,
    void Function(TreeElement element) visit,
  ) {
    visit(element);
    for (var i = 0; i < element.numChildren; i++) {
      _forSubtree(element.childAt(i), visit);
    }
  }

  /// Forgets the notifiers no widget listens to (e.g. those of removed
  /// repeat instances).
  void _prune() {
    _byRef.removeWhere((key, notifier) {
      if (notifier.listening) return false;
      _merged.remove(key);
      notifier.dispose();
      return true;
    });
  }

  /// The rejected result of the last answer to the question at
  /// [index], or of the last finalize, if any.
  AnswerResult? failureFor(FormIndex index) => _errors['${index.reference}'];

  /// The error shown under the question at [index], if its last answer
  /// was rejected; default messages come from [strings].
  String? errorFor(
    FormIndex index, [
    XFormLocalizations strings = const XFormLocalizations(),
  ]) => switch (failureFor(index)) {
    AnswerRequired(:final message) => message ?? strings.requiredDefault,
    AnswerConstraintViolated(:final message) =>
      message ?? strings.constraintDefault,
    AnswerRejected() => strings.constraintDefault,
    AnswerAccepted() || null => null,
  };

  void _setResult(FormIndex index, AnswerResult result) {
    final key = '${index.reference}';
    final previous = _errors[key];
    if (result is AnswerAccepted) {
      _errors.remove(key);
    } else {
      _errors[key] = result;
    }
    if (previous != _errors[key]) _bump(key);
  }

  /// Answers the question at [index] with [value]; rejected answers are
  /// not saved and leave an error for the question.
  AnswerResult answer(FormIndex index, AnswerValue? value) {
    final result = session.answer(index, value);
    _setResult(index, result);
    return result;
  }

  /// Validates and finalizes the form; on failure the first failing
  /// question gets its error.
  FinalizeResult finalize() {
    final result = session.finalize();
    if (result case FinalizeFailure(:final failure)) {
      _setResult(failure.index, failure.result);
    }
    return result;
  }

  /// Adds a repeat instance to [repeat].
  void addRepeatInstance(RepeatNode repeat) =>
      session.addRepeatInstance(repeat.index);

  /// Removes [instance].
  void removeRepeatInstance(RepeatInstanceNode instance) =>
      session.removeRepeatInstance(instance.index);

  /// Changes the form's language.
  set language(String? language) => session.language = language;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    for (final notifier in _byRef.values) {
      notifier.dispose();
    }
    _byRef.clear();
    _merged.clear();
    super.dispose();
  }
}

class _RefNotifier extends ChangeNotifier {
  bool get listening => hasListeners;

  void bump() => notifyListeners();
}
