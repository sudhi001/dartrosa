import 'dart:async';

import 'package:dartrosa/dartrosa.dart';

import 'audit_config.dart';
import 'audit_event.dart';
import 'audit_event_csv_writer.dart';
import 'audit_event_logger.dart';
import 'form_session_audit_state.dart';

/// Provides device locations for an audit with [AuditConfig]
/// ([AuditConfig.locationPriority], [AuditConfig.locationMinInterval]).
/// Collect's `BackgroundLocationManager` requests them from the platform.
typedef AuditLocationSource =
    Stream<AuditLocation> Function(AuditConfig config);

/// The audit log of one [FormSession], logging what ODK Collect logs at the
/// same moments of form filling.
///
/// The app calls a method for each moment (navigation, saving, dialogs,
/// location and permission changes), as Collect's activities and view
/// models call its `AuditEventLogger`:
///
/// * [formStarted] or [formResumed] once the form is shown (after
///   [requiresIdentity] is satisfied with [identify]);
/// * [screenChanged] after moving to another screen (a question, a
///   field-list group, a repeat prompt or the end), [screenRefreshed] when
///   the same screen is shown again;
/// * [answersUpdated] after saving the answers of a screen without moving;
/// * [hierarchyOpened] / [hierarchyClosed], [repeatDeleted];
/// * [beforeSave], then [requiresChangeReason] / [changeReasonGiven], then
///   [saved], [saveFailed], [finalizeFailed] or [constraintError];
/// * [exitedWithoutSaving];
/// * [logLocationEvent], [addLocation], [backgroundAudioChanged].
///
/// Ports the audit calls of Collect's `FormFillingActivity`,
/// `FormEntryViewModel`, `FormSaveViewModel`, `IdentityPromptViewModel`,
/// `FormHierarchyFragment`, `DeleteRepeatDialogFragment`,
/// `BackgroundAudioViewModel` and `BackgroundLocationHelper`. Times come
/// from the injected [AuditClock].
final class FormAudit {
  FormAudit._(
    this.session,
    this.config,
    this.logger,
    this._state,
    this._writer,
    this._clock,
    this._locationSource, {
    required this.isEditing,
  });

  /// The audit of [session], writing to [store] (the instance's
  /// `audit.csv`). When the form has no `meta/audit`, nothing is logged
  /// ([isEnabled] is `false`).
  ///
  /// [isEditing] is whether a saved instance is being edited (Collect asks
  /// for change reasons only then). [locationSource] provides locations
  /// when the form audits them. Reading the configuration sets the value
  /// of `meta/audit` to `audit.csv`, as Collect does.
  factory FormAudit(
    FormSession session, {
    required AuditLogStore store,
    bool isEditing = false,
    AuditClock? clock,
    AuditLocationSource? locationSource,
    void Function(Object error, StackTrace stackTrace)? onWriteError,
  }) {
    final config = AuditConfig.fromForm(session.definition.formDef);
    final state = FormSessionAuditState(session);
    final writer = config == null
        ? null
        : AuditEventCsvWriter(
            store,
            isLocationEnabled: config.isLocationEnabled,
            isTrackingChangesEnabled: config.isTrackingChangesEnabled,
            isUserRequired: config.isIdentifyUserEnabled,
            isTrackChangesReasonEnabled: config.isTrackChangesReasonEnabled,
            onError: onWriteError,
          );
    final auditClock = clock ?? SystemAuditClock();
    return FormAudit._(
      session,
      config,
      AuditEventLogger(config, writer, state, clock: auditClock),
      state,
      writer,
      auditClock,
      locationSource,
      isEditing: isEditing,
    );
  }

  /// The session audited.
  final FormSession session;

  /// The form's audit configuration, or `null` without an audit.
  final AuditConfig? config;

  /// The logger (for events this class has no method for).
  final AuditEventLogger logger;

  /// Whether a saved instance is being edited.
  final bool isEditing;

  final FormSessionAuditState _state;
  final AuditEventCsvWriter? _writer;
  final AuditClock _clock;
  final AuditLocationSource? _locationSource;
  StreamSubscription<AuditLocation>? _locations;
  String _identity = '';

  int get _now => _clock.currentTimeMillis();

  /// Whether the form has an audit.
  bool get isEnabled => config != null;

  /// Whether the user must identify themselves before filling the form
  /// (`odk:identify-user` without a non-blank user yet).
  ///
  /// Port of `IdentityPromptViewModel.requiresIdentityToContinue`.
  bool get requiresIdentity =>
      logger.isUserRequired && !_userIsValid(logger.user);

  /// The identity entered so far.
  String get identity => _identity;

  /// Sets the user identity (the prompt's "done"); events logged from now
  /// on carry it. Returns whether the identity is still required (blank).
  ///
  /// Port of `IdentityPromptViewModel.setIdentity` and `done`.
  bool identify(String identity) {
    _identity = identity;
    logger.user = identity;
    return requiresIdentity;
  }

  /// Logs the start of filling a new instance and starts listening to
  /// locations.
  void formStarted() {
    _log(AuditEventType.formStart);
    _listenToLocations();
  }

  /// Logs resuming a saved instance and starts listening to locations.
  void formResumed() {
    _log(AuditEventType.formResume);
    _listenToLocations();
  }

  /// After moving to another screen: ends the previous screen's events and
  /// logs the new screen's.
  ///
  /// Port of `FormEntryViewModel.moveForward`/`moveBackward` (flush, then
  /// `updateIndex`) and `FormFillingActivity.createView`.
  void screenChanged() {
    logger.flush(); // Close events waiting for an end time
    screenRefreshed();
  }

  /// Logs the current screen (without ending the events of the screen
  /// shown before; events of a screen already logged aren't repeated).
  /// The question events come first, then the event of a field-list group,
  /// repeat prompt or end screen.
  void screenRefreshed() {
    _state.logCurrentScreen(logger, _now);
    final event = session.navigator.event;
    if (event != FormEntryEvent.question) {
      logger.logEvent(
        AuditEventType.fromFormEntryEvent(event),
        formIndex: session.navigator.position,
        writeImmediatelyToDisk: true,
        currentTime: _now,
      );
    }
  }

  /// After saving a screen's answers without moving: ends the open events.
  ///
  /// Port of `FormEntryViewModel.updateAnswersForScreen`.
  void answersUpdated() => logger.flush();

  /// The hierarchy (jump) view is opened.
  void hierarchyOpened() => _log(AuditEventType.hierarchy);

  /// The hierarchy view is closed or jumped from: ends the jump event.
  /// Call [screenChanged] once the new screen is shown.
  ///
  /// Port of `FormHierarchyFragment`'s flushes.
  void hierarchyClosed() => logger.flush();

  /// A repeat instance was deleted.
  void repeatDeleted() => _log(AuditEventType.deleteRepeat);

  /// Saving starts: ends the open events.
  void beforeSave() => logger.flush();

  /// Whether saving needs a change reason first: the form tracks change
  /// reasons and a saved instance is being edited.
  ///
  /// Port of `FormSaveViewModel.requiresReasonToSave`.
  bool get requiresChangeReason => isEditing && logger.isChangeReasonRequired;

  /// Logs the change [reason]; returns `false` (logging nothing) when it is
  /// blank, in which case saving must not continue.
  ///
  /// Port of `FormSaveViewModel.saveReason`.
  bool changeReasonGiven(String? reason) {
    if (reason == null || reason.trim().isEmpty) return false;
    logger.logEvent(
      AuditEventType.changeReason,
      writeImmediatelyToDisk: true,
      currentTime: _now,
      changeReason: reason,
    );
    return true;
  }

  /// The form was saved; [exiting] when the form is closed afterwards,
  /// [finalized] when it was finalized.
  ///
  /// Port of `FormSaveViewModel.handleTaskResult` (`SAVED`).
  void saved({required bool exiting, required bool finalized}) {
    _log(AuditEventType.formSave, writeImmediatelyToDisk: false);
    if (exiting) {
      if (finalized) {
        _log(AuditEventType.formExit, writeImmediatelyToDisk: false);
        _log(AuditEventType.formFinalize);
      } else {
        _log(AuditEventType.formExit);
      }
    } else {
      _state.logCurrentScreen(logger, _now);
    }
  }

  /// Saving failed.
  void saveFailed() => _log(AuditEventType.saveError);

  /// Finalizing failed (e.g. encryption).
  void finalizeFailed() => _log(AuditEventType.finalizeError);

  /// Saving stopped on a constraint or required question.
  void constraintError() => _log(AuditEventType.constraintError);

  /// The form was exited without saving.
  ///
  /// Port of `FormSaveViewModel.ignoreChanges`.
  void exitedWithoutSaving() => _log(AuditEventType.formExit);

  /// Background audio recording was enabled or disabled.
  void backgroundAudioChanged({required bool enabled}) => _log(
    enabled
        ? AuditEventType.backgroundAudioEnabled
        : AuditEventType.backgroundAudioDisabled,
  );

  /// Logs a location-related [eventType] (permissions, providers, tracking
  /// on/off, Play Services); ignored unless the form audits locations.
  ///
  /// Port of `BackgroundLocationHelper.logAuditEvent`.
  void logLocationEvent(AuditEventType eventType) =>
      _log(eventType, writeImmediatelyToDisk: false);

  /// Adds a location fix.
  void addLocation(AuditLocation location) => logger.addLocation(location);

  /// Stops listening to locations and writes the events still waiting
  /// because a write was in progress. A DartRosa addition.
  Future<void> close() async {
    await _locations?.cancel();
    _locations = null;
    final writer = _writer;
    if (writer == null) return;
    await writer.idle;
    logger.writeQueuedEvents();
    await writer.idle;
  }

  void _log(AuditEventType type, {bool writeImmediatelyToDisk = true}) =>
      logger.logEvent(
        type,
        writeImmediatelyToDisk: writeImmediatelyToDisk,
        currentTime: _now,
      );

  void _listenToLocations() {
    final config = this.config;
    final source = _locationSource;
    if (config == null ||
        !config.isLocationEnabled ||
        source == null ||
        _locations != null) {
      return;
    }
    _locations = source(config).listen(addLocation);
  }

  static bool _userIsValid(String? user) =>
      user != null && user.trim().isNotEmpty;
}
