import 'dart:async';

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/foundation.dart';

/// Owns a [FormSession] for widgets: answers questions, remembers the
/// last answer error per question, and notifies only the widgets whose
/// nodes changed.
///
/// The session stays the single source of truth; widgets read node state
/// from it when notified.
class XFormController extends ChangeNotifier {
  /// Creates a controller for [session].
  XFormController(this.session) {
    _subscription = session.changes.listen(_onChange);
  }

  /// The form being filled.
  final FormSession session;

  late final StreamSubscription<FormChange> _subscription;
  final Map<String, _RefNotifier> _byRef = {};
  final Map<String, String?> _errors = {};

  /// Notified on changes of the node at [ref] (or anything structural:
  /// repeats, language). Use with `ListenableBuilder`.
  Listenable listenableFor(TreeReference? ref) =>
      Listenable.merge([this, _notifierFor(ref)]);

  _RefNotifier _notifierFor(TreeReference? ref) =>
      _byRef.putIfAbsent('$ref', _RefNotifier.new);

  void _onChange(FormChange change) {
    switch (change.kind) {
      case 'repeat' || 'language':
        notifyListeners();
      default:
        for (final ref in change.refs) {
          _byRef['${ref.genericize()}']?.bump();
          _byRef['$ref']?.bump();
        }
        // Relevance of containers decides which children are shown.
        if (change.kind == 'condition') notifyListeners();
    }
  }

  /// The error shown under the question at [index], if its last answer
  /// was rejected.
  String? errorFor(FormIndex index) => _errors['${index.reference}'];

  /// Answers the question at [index] with [value]; rejected answers are
  /// not saved and leave an error for the question.
  AnswerResult answer(FormIndex index, AnswerValue? value) {
    final result = session.answer(index, value);
    final key = '${index.reference}';
    final previous = _errors[key];
    _errors[key] = switch (result) {
      AnswerAccepted() => null,
      AnswerRequired(:final message) => message ?? _requiredDefault,
      AnswerConstraintViolated(:final message) => message ?? _constraintDefault,
    };
    if (previous != _errors[key]) _byRef[key]?.bump();
    return result;
  }

  /// Validates and finalizes the form; on failure the first failing
  /// question gets its error.
  FinalizeResult finalize() {
    final result = session.finalize();
    if (result case FinalizeFailure(:final failure)) {
      _errors['${failure.index.reference}'] = switch (failure.result) {
        AnswerRequired(:final message) => message ?? _requiredDefault,
        AnswerConstraintViolated(:final message) =>
          message ?? _constraintDefault,
        AnswerAccepted() => null,
      };
      _byRef['${failure.index.reference}']?.bump();
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

  static const _requiredDefault = 'Sorry, this response is required!';
  static const _constraintDefault = 'Sorry, this response is not valid.';

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    for (final notifier in _byRef.values) {
      notifier.dispose();
    }
    super.dispose();
  }
}

class _RefNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
