import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'audit_event.dart';
import 'audit_event_logger.dart';

/// Thrown when a `field-list` group contains a repeat (Collect doesn't
/// support those).
///
/// Port of Collect's `RepeatsInFieldListException`.
final class RepeatsInFieldListException implements Exception {
  /// Creates the exception.
  const RepeatsInFieldListException(this.message);

  /// What's wrong.
  final String message;

  @override
  String toString() => 'RepeatsInFieldListException: $message';
}

/// The screen-level view of a [FormSession] that Collect's audit uses: the
/// questions of the current screen and whether an index is in a
/// `field-list` group.
///
/// Ports the parts of Collect's `JavaRosaFormController` used by the
/// audit (`indexIsInFieldList`, `getQuestionPrompts`,
/// `getIndicesForGroup`, `getQuestionPrompt`).
final class FormSessionAuditState implements AuditFormState {
  /// Creates the view of [session].
  FormSessionAuditState(this.session)
    : _model = FormEntryModel(session.definition.formDef);

  /// The session.
  final FormSession session;

  // A model over the same form, for index queries independent of the
  // session's cursor.
  final FormEntryModel _model;

  FormDef get _form => session.definition.formDef;

  @override
  String? answerDisplayText(FormIndex? index) => index == null
      ? null
      : _model.questionPrompt(index).answerValue?.displayText;

  @override
  bool indexIsInFieldList(FormIndex? index) {
    if (index == null) return false;
    switch (_model.event(index)) {
      case FormEntryEvent.question:
        final captions = _model.captionHierarchy(index);
        if (captions.length < 2) return false; // no group
        // If at least one of the groups you are inside is a field list,
        // your index is in a field list
        return captions.any((caption) => _groupIsFieldList(caption.index));
      case FormEntryEvent.group:
      case FormEntryEvent.repeat:
        return _groupIsFieldList(index);
      default:
        return false;
    }
  }

  bool _groupIsFieldList(FormIndex index) {
    final element = _form.elementAt(index);
    final appearance = element.appearance;
    return element is GroupDef &&
        appearance != null &&
        appearance.toLowerCase().contains('field-list');
  }

  /// The relevant questions of the screen at the session's current
  /// position: the question there, or those of the (field-list) group
  /// there. Throws [RepeatsInFieldListException] for a group containing a
  /// repeat.
  List<FormEntryPrompt> questionPrompts() {
    final current = session.navigator.position;
    final element = _form.elementAt(current);
    if (element is! GroupDef) return [_model.questionPrompt(current)];
    final questions = <FormEntryPrompt>[];
    for (final indexInGroup in _getIndicesForGroup(
      element,
      _model.incrementIndex(current),
    )) {
      if (_model.event(indexInGroup) != FormEntryEvent.question) {
        throw RepeatsInFieldListException(
          "Repeats in 'field-list' groups are not supported. Please update "
          'the form design to remove the following repeat from a field '
          'list: ${indexInGroup.reference!.toString(includePredicates: false)}',
        );
      }
      // we only display relevant questions
      if (_model.isIndexRelevant(indexInGroup)) {
        questions.add(_model.questionPrompt(indexInGroup));
      }
    }
    return questions;
  }

  List<FormIndex> _getIndicesForGroup(
    GroupDef gd,
    FormIndex currentChildIndex,
  ) {
    final indices = <FormIndex>[];
    var child = currentChildIndex;
    for (var i = 0; i < gd.children.length; i++) {
      if (_model.event(child) == FormEntryEvent.group) {
        final nestedElement = _form.elementAt(child);
        if (nestedElement is GroupDef) {
          indices.addAll(
            _getIndicesForGroup(nestedElement, _model.incrementIndex(child)),
          );
          child = _model.incrementIndex(child, descend: false);
        }
      } else {
        indices.add(child);
        child = _model.incrementIndex(child, descend: false);
      }
    }
    return indices;
  }

  /// Logs a question event for each question on the current screen (when
  /// it shows questions: a question, group or repeat).
  ///
  /// Port of Collect's `AuditUtils.logCurrentScreen`.
  void logCurrentScreen(AuditEventLogger auditEventLogger, int currentTime) {
    final event = session.navigator.event;
    if (event != FormEntryEvent.question &&
        event != FormEntryEvent.group &&
        event != FormEntryEvent.repeat) {
      return;
    }
    try {
      for (final question in questionPrompts()) {
        auditEventLogger.logEvent(
          AuditEventType.question,
          formIndex: question.index,
          writeImmediatelyToDisk: true,
          questionAnswer: question.answerValue?.displayText,
          currentTime: currentTime,
        );
      }
    } on RepeatsInFieldListException {
      // ignore
    }
  }
}
