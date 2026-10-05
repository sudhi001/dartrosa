import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart' show javaDoubleToString;

import 'audit_config.dart';
import 'audit_event.dart';

/// A device location, as reported to the audit logger.
///
/// The parts of Android's `Location` that Collect's audit uses.
final class AuditLocation {
  /// Creates a location fixed at [time] (milliseconds since the epoch)
  /// with [accuracy] in meters.
  const AuditLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.time,
  });

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Estimated horizontal accuracy in meters.
  final double accuracy;

  /// When the fix was taken, in milliseconds since the epoch.
  final int time;

  @override
  String toString() =>
      'AuditLocation($latitude, $longitude, ±$accuracy m @ $time)';
}

/// The clock the audit log reads: wall-clock time and a monotonic clock.
///
/// Collect uses `System.currentTimeMillis()` and
/// `SystemClock.elapsedRealtime()`.
abstract interface class AuditClock {
  /// Milliseconds since the epoch.
  int currentTimeMillis();

  /// Milliseconds on a monotonic clock (unaffected by wall-clock changes).
  int elapsedRealtime();
}

/// The system clock: `DateTime.now()` and a [Stopwatch].
final class SystemAuditClock implements AuditClock {
  /// Creates the clock.
  SystemAuditClock();

  final _stopwatch = Stopwatch()..start();

  @override
  int currentTimeMillis() => DateTime.now().millisecondsSinceEpoch;

  @override
  int elapsedRealtime() => _stopwatch.elapsedMilliseconds;
}

/// What the logger needs to know about the form being filled when interval
/// events end. See `FormSessionAuditState`.
///
/// The parts of Collect's `FormController` that `AuditEventLogger` uses.
abstract interface class AuditFormState {
  /// The display text of the answer at [index] (a question), or `null`.
  String? answerDisplayText(FormIndex? index);

  /// Whether [index] is in (or is) a `field-list` group.
  bool indexIsInFieldList(FormIndex? index);
}

/// Writes audit events (e.g. appends them to `audit.csv`).
///
/// Port of `AuditEventLogger.AuditEventWriter`.
abstract interface class AuditEventWriter {
  /// Writes [auditEvents]; may complete asynchronously.
  void writeEvents(List<AuditEvent> auditEvents);

  /// Whether a previous [writeEvents] is still in progress (events are
  /// then kept and written with the next batch).
  bool get isWriting;
}

/// Logs audit events: times them (with the clock of the moment the form
/// was opened), adds locations, old and new answers and the user, and
/// passes them to a writer.
///
/// Port of Collect's `AuditEventLogger`. Notes from Collect:
/// 1. If the user has saved the form, then resumes editing, then exits
///    without saving, the timing data of the second session is saved. If
///    the user exits without ever saving, the timing data is lost with the
///    form.
/// 2. The events of questions in a field-list group are not written (only
///    the group's), unless tracking changes is enabled and their answer
///    changed.
final class AuditEventLogger {
  /// Creates a logger for [auditConfig] (`null`: the form has no audit and
  /// nothing is logged) that passes events to the given writer; the form
  /// state gives the new answers of question events.
  AuditEventLogger(
    this.auditConfig,
    this._writer,
    this._formState, {
    AuditClock? clock,
  }) : _clock = clock ?? SystemAuditClock();

  /// The form's audit configuration, if it has an audit.
  final AuditConfig? auditConfig;

  final AuditEventWriter? _writer;
  final AuditFormState? _formState;
  final AuditClock _clock;

  var _locations = <AuditLocation>[];
  var _auditEvents = <AuditEvent>[];
  var _surveyOpenTime = 0;
  var _surveyOpenElapsedTime = 0;

  /// The identified user, added to every new event.
  String? user;

  /// Logs an event of [eventType] at [formIndex]. Interval events wait for
  /// [flush] (or a form exit); other events are written immediately when
  /// [writeImmediatelyToDisk]. [questionAnswer] is the answer when a
  /// question event starts; [currentTime] (milliseconds since the epoch)
  /// expires old locations.
  void logEvent(
    AuditEventType eventType, {
    required bool writeImmediatelyToDisk,
    required int currentTime,
    FormIndex? formIndex,
    String? questionAnswer,
    String? changeReason,
  }) {
    final config = auditConfig;
    if (config == null || _shouldBeIgnored(eventType)) return;

    final newAuditEvent = AuditEvent(
      _getEventTime(),
      eventType,
      formIndex: formIndex,
      oldValue: questionAnswer,
      user: user,
      changeReason: changeReason,
    );

    if (_isDuplicatedIntervalEvent(newAuditEvent)) return;

    if (config.isLocationEnabled) {
      _addLocationCoordinatesToAuditEvent(newAuditEvent, currentTime);
    }

    // Close any existing interval events if the view is being exited
    if (eventType == AuditEventType.formExit) _finalizeEvents();

    _auditEvents.add(newAuditEvent);

    // Write the event unless it is an interval event in which case we need
    // to wait for the end of that event
    if (writeImmediatelyToDisk && !newAuditEvent.isIntervalAuditEventType) {
      _writeEvents();
    }
  }

  /// Ends interval events and writes all events.
  void flush() {
    if (isAuditEnabled) {
      _finalizeEvents();
      _writeEvents();
    }
  }

  /// Writes the events kept while the writer was busy, if it no longer is.
  /// A DartRosa addition (Collect writes them with the next batch only).
  void writeQueuedEvents() {
    if (isAuditEnabled && _auditEvents.isNotEmpty) _writeEvents();
  }

  /// Adds a location fix to choose event locations from.
  void addLocation(AuditLocation location) => _locations.add(location);

  /// The location fixes kept (unexpired as of the last event).
  List<AuditLocation> get locations => List.unmodifiable(_locations);

  /// The events not written yet.
  List<AuditEvent> get pendingEvents => List.unmodifiable(_auditEvents);

  /// Whether the form has an audit.
  bool get isAuditEnabled => auditConfig != null;

  /// Whether the form asks the user to identify themselves.
  bool get isUserRequired => auditConfig?.isIdentifyUserEnabled ?? false;

  /// Whether the form asks for a reason when saving an edited form.
  bool get isChangeReasonRequired =>
      auditConfig?.isTrackChangesReasonEnabled ?? false;

  /// Whether [eventType] repeats the last event, a location provider
  /// change (Android may report those several times).
  bool isDuplicateOfLastLocationEvent(AuditEventType eventType) =>
      (eventType == AuditEventType.locationProvidersEnabled ||
          eventType == AuditEventType.locationProvidersDisabled) &&
      _auditEvents.isNotEmpty &&
      eventType == _auditEvents.last.auditEventType;

  void _addLocationCoordinatesToAuditEvent(
    AuditEvent auditEvent,
    int currentTime,
  ) {
    final location = _getMostAccurateLocation(currentTime);
    auditEvent.setLocationCoordinates(
      location != null ? javaDoubleToString(location.latitude) : '',
      location != null ? javaDoubleToString(location.longitude) : '',
      location != null ? javaDoubleToString(location.accuracy) : '',
    );
  }

  // Ignore the event if we are already in an interval view event or have
  // jumped. This can happen if the user is on a question page and the page
  // gets refreshed. The exception is hierarchy events since they interrupt
  // an existing interval event.
  bool _isDuplicatedIntervalEvent(AuditEvent newAuditEvent) {
    if (!newAuditEvent.isIntervalAuditEventType) return false;
    return _auditEvents.any(
      (aev) =>
          aev.isIntervalAuditEventType &&
          newAuditEvent.auditEventType == aev.auditEventType &&
          newAuditEvent.formIndex == aev.formIndex,
    );
  }

  // Filter all events and set final parameters of interval events
  void _finalizeEvents() {
    final end = _getEventTime();
    final filteredAuditEvents = <AuditEvent>[];
    for (final aev in _auditEvents) {
      if (aev.isIntervalAuditEventType) {
        _setIntervalEventFinalParameters(aev, end);
      }
      if (_shouldEventBeLogged(aev)) filteredAuditEvents.add(aev);
    }
    _auditEvents
      ..clear()
      ..addAll(filteredAuditEvents);
  }

  void _setIntervalEventFinalParameters(AuditEvent aev, int end) {
    // We try to add the location again (the first attempt takes place when
    // the event is created) because coordinates might not have been
    // available then.
    if (auditConfig!.isLocationEnabled && !aev.isLocationAlreadySet) {
      _addLocationCoordinatesToAuditEvent(aev, _clock.currentTimeMillis());
    }
    final formState = _formState;
    if (aev.auditEventType == AuditEventType.question && formState != null) {
      aev.recordValueChange(formState.answerDisplayText(aev.formIndex));
    }
    if (!aev.isEndTimeSet) aev.setEnd(end);
  }

  bool _shouldBeIgnored(AuditEventType eventType) =>
      !eventType.isLogged ||
      eventType.isLocationRelated && !auditConfig!.isLocationEnabled ||
      isDuplicateOfLastLocationEvent(eventType);

  // A question in a field-list group is logged only if tracking changes is
  // enabled and its answer has changed.
  bool _shouldEventBeLogged(AuditEvent aev) {
    final formState = _formState;
    if (aev.auditEventType == AuditEventType.question && formState != null) {
      return !formState.indexIsInFieldList(aev.formIndex) ||
          (aev.hasNewAnswer && auditConfig!.isTrackingChangesEnabled);
    }
    return true;
  }

  void _writeEvents() {
    final writer = _writer;
    if (writer == null || writer.isWriting) return; // Queueing AuditEvent
    writer.writeEvents(_auditEvents);
    _auditEvents = [];
  }

  // Use the time the survey was opened as a consistent value for wall
  // clock time.
  int _getEventTime() {
    if (_surveyOpenTime == 0) {
      _surveyOpenTime = _clock.currentTimeMillis();
      _surveyOpenElapsedTime = _clock.elapsedRealtime();
    }
    return _surveyOpenTime +
        (_clock.elapsedRealtime() - _surveyOpenElapsedTime);
  }

  AuditLocation? _getMostAccurateLocation(int currentTime) {
    _removeExpiredLocations(currentTime);
    AuditLocation? bestLocation;
    for (final location in _locations) {
      if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
        bestLocation = location;
      }
    }
    return bestLocation;
  }

  void _removeExpiredLocations(int currentTime) {
    if (_locations.isEmpty) return;
    final maxAge = auditConfig!.locationMaxAge!;
    _locations = [
      for (final location in _locations)
        if (currentTime <= location.time + maxAge) location,
    ];
  }
}
