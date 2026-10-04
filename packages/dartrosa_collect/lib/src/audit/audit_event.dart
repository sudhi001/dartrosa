import 'package:dartrosa/dartrosa.dart';

/// The kinds of events in an audit log, with the text Collect writes for
/// each.
///
/// Port of Collect's `AuditEvent.AuditEventType`.
enum AuditEventType {
  /// Beginning of the form (not logged).
  beginningOfForm('beginning of form', isLogged: false),

  /// A question shown.
  question('question', isInterval: true),

  /// A field-list group shown.
  group('group questions', isInterval: true),

  /// The prompt to add a new repeat shown.
  promptNewRepeat('add repeat', isInterval: true),

  /// A repeat (not logged).
  repeat('repeat', isLogged: false),

  /// The end screen shown.
  endOfForm('end screen', isInterval: true),

  /// Started filling in the form.
  formStart('form start'),

  /// Exited the form.
  formExit('form exit'),

  /// Resumed filling in the form after previously exiting.
  formResume('form resume'),

  /// Saved the form.
  formSave('form save'),

  /// Finalized the form.
  formFinalize('form finalize'),

  /// Jumped to a question (the hierarchy view).
  hierarchy('jump', isInterval: true),

  /// Saving failed.
  saveError('save error'),

  /// Finalizing failed (e.g. encryption).
  finalizeError('finalize error'),

  /// Constraint or missing answer error on save.
  constraintError('constraint error'),

  /// A repeat instance deleted.
  deleteRepeat('delete repeat'),

  /// The reason given for changing an edited form.
  changeReason('change reason'),

  /// Background audio recording disabled.
  backgroundAudioDisabled('background audio disabled'),

  /// Background audio recording enabled.
  backgroundAudioEnabled('background audio enabled'),

  /// Google Play Services are not available.
  googlePlayServicesNotAvailable(
    'google play services not available',
    isLocationRelated: true,
  ),

  /// Location permissions are granted.
  locationPermissionsGranted(
    'location permissions granted',
    isLocationRelated: true,
  ),

  /// Location permissions are not granted.
  locationPermissionsNotGranted(
    'location permissions not granted',
    isLocationRelated: true,
  ),

  /// The location tracking option is enabled.
  locationTrackingEnabled('location tracking enabled', isLocationRelated: true),

  /// The location tracking option is disabled.
  locationTrackingDisabled(
    'location tracking disabled',
    isLocationRelated: true,
  ),

  /// Location providers are enabled.
  locationProvidersEnabled(
    'location providers enabled',
    isLocationRelated: true,
  ),

  /// Location providers are disabled.
  locationProvidersDisabled(
    'location providers disabled',
    isLocationRelated: true,
  ),

  /// Unknown event type.
  unknownEventType('Unknown AuditEvent Type');

  const AuditEventType(
    this.value, {
    this.isLogged = true,
    this.isInterval = false,
    this.isLocationRelated = false,
  });

  /// The text written in the `event` column.
  final String value;

  /// Whether events of this type are written at all.
  final bool isLogged;

  /// Whether events of this type have both a start and an end time.
  final bool isInterval;

  /// Whether events of this type are only logged when locations are.
  final bool isLocationRelated;

  /// The event type for a navigation [event].
  ///
  /// Port of `AuditEvent.getAuditEventTypeFromFecType`.
  static AuditEventType fromFormEntryEvent(FormEntryEvent? event) =>
      switch (event) {
        FormEntryEvent.beginningOfForm => beginningOfForm,
        FormEntryEvent.group => group,
        FormEntryEvent.repeat => repeat,
        FormEntryEvent.promptNewRepeat => promptNewRepeat,
        FormEntryEvent.endOfForm => endOfForm,
        _ => unknownEventType,
      };
}

/// One audit log entry.
///
/// Port of Collect's `AuditEvent`.
final class AuditEvent {
  /// Creates an event starting at [start] (milliseconds since the epoch)
  /// at [formIndex], with the answer [oldValue] when it started, the
  /// [user] and the [changeReason].
  AuditEvent(
    this.start,
    this.auditEventType, {
    this.formIndex,
    String? oldValue,
    this.user,
    this.changeReason,
  }) : _oldValue = oldValue ?? '';

  /// When the event started, in milliseconds since the epoch.
  final int start;

  /// The kind of event.
  final AuditEventType auditEventType;

  /// Where in the form it happened, if anywhere.
  final FormIndex? formIndex;

  /// The reason given for a change, if any.
  final String? changeReason;

  /// The user, if identified.
  String? user;

  String? _latitude;
  String? _longitude;
  String? _accuracy;
  String _oldValue;
  String _newValue = '';
  int _end = 0;
  bool _endTimeSet = false;

  /// Whether this event's type is an interval type.
  bool get isIntervalAuditEventType => auditEventType.isInterval;

  /// Marks the end of an interval event.
  void setEnd(int endTime) {
    _end = endTime;
    _endTimeSet = true;
  }

  /// Whether [setEnd] was called.
  bool get isEndTimeSet => _endTimeSet;

  /// Whether the answer changed during the event.
  bool get hasNewAnswer => _oldValue != _newValue;

  /// Whether non-empty coordinates are set.
  bool get isLocationAlreadySet =>
      (_latitude?.isNotEmpty ?? false) &&
      (_longitude?.isNotEmpty ?? false) &&
      (_accuracy?.isNotEmpty ?? false);

  /// Sets the location columns.
  void setLocationCoordinates(
    String? latitude,
    String? longitude,
    String? accuracy,
  ) {
    _latitude = latitude;
    _longitude = longitude;
    _accuracy = accuracy;
  }

  /// Records the answer at the end of the event; returns whether it
  /// differs from the old one (when it doesn't, both are cleared).
  bool recordValueChange(String? newValue) {
    _newValue = newValue ?? '';
    // Clear values if they are equal
    if (_oldValue == _newValue) {
      _oldValue = '';
      _newValue = '';
      return false;
    }
    return true;
  }

  /// The latitude column.
  String? get latitude => _latitude;

  /// The longitude column.
  String? get longitude => _longitude;

  /// The accuracy column.
  String? get accuracy => _accuracy;

  /// The answer when the event started (or `''`).
  String get oldValue => _oldValue;

  /// The answer when the event ended (or `''`).
  String get newValue => _newValue;

  /// When the event ended, or 0.
  int get end => _end;
}
