// Port of Collect's AuditEventLoggerTest.
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  // All values are set so location coordinates should be collected
  final testAuditConfig = AuditConfig(
    mode: 'high-priority',
    locationMinInterval: '10',
    locationMaxAge: '60',
  );
  // At least one value is not set so location coordinates shouldn't be
  // collected
  final testAuditConfigWithNullValues = AuditConfig(
    mode: 'high-priority',
    locationMinInterval: '10',
  );

  late TestWriter testWriter;
  final formState = FakeFormState();

  setUp(() => testWriter = TestWriter());

  AuditEventLogger logger(AuditConfig? config) =>
      AuditEventLogger(config, testWriter, formState, clock: FakeAuditClock());

  void log(
    AuditEventLogger logger,
    AuditEventType type, [
    int currentTime = 0,
  ]) => logger.logEvent(
    type,
    writeImmediatelyToDisk: false,
    currentTime: currentTime,
  );

  test('whenAuditConfigIsNull_doesntWriteEvents', () {
    final auditEventLogger = logger(null);
    log(auditEventLogger, AuditEventType.endOfForm);
    auditEventLogger.flush(); // Triggers event writing
    expect(testWriter.auditEvents, isEmpty);
  });

  test('usesMostAccurateLocationForEvents', () {
    final auditEventLogger = logger(testAuditConfig)
      ..addLocation(
        const AuditLocation(
          latitude: 54.380746599999995,
          longitude: 18.606523,
          accuracy: 5,
          time: 1548156641000,
        ),
      )
      ..addLocation(
        const AuditLocation(
          latitude: 54.37971080550665,
          longitude: 18.612874470947304,
          accuracy: 10,
          time: 1548156655000,
        ),
      )
      ..addLocation(
        const AuditLocation(
          latitude: 54.3819102504987,
          longitude: 18.62025591015629,
          accuracy: 12,
          time: 1548156665000,
        ),
      )
      ..addLocation(
        const AuditLocation(
          latitude: 54.38620882544086,
          longitude: 18.62523409008793,
          accuracy: 7,
          time: 1548156688000,
        ),
      )
      ..addLocation(
        const AuditLocation(
          latitude: 54.39070685202294,
          longitude: 18.617166005371132,
          accuracy: 20,
          time: 1548156710000,
        ),
      );

    log(auditEventLogger, AuditEventType.endOfForm, 1548156712000);
    auditEventLogger.flush();

    final auditEvent = testWriter.auditEvents[0];
    expect(auditEvent.latitude, '54.38620882544086');
    expect(auditEvent.longitude, '18.62523409008793');
    expect(auditEvent.accuracy, '7.0');
  });

  test('expiresLocationsOlderThan60Seconds', () {
    final auditEventLogger = logger(testAuditConfig)
      ..addLocation(
        const AuditLocation(
          latitude: 54.380746599999995,
          longitude: 18.606523,
          accuracy: 2,
          time: 0,
        ),
      )
      ..addLocation(
        const AuditLocation(
          latitude: 54.37971080550665,
          longitude: 18.612874470947304,
          accuracy: 1,
          time: 61 * 1000,
        ),
      );

    log(auditEventLogger, AuditEventType.endOfForm, 120 * 1000);
    auditEventLogger.flush();

    final auditEvent = testWriter.auditEvents[0];
    expect(auditEvent.latitude, '54.37971080550665');
    expect(auditEvent.longitude, '18.612874470947304');
    expect(auditEvent.accuracy, '1.0');
    expect(auditEventLogger.locations, hasLength(1));
  });

  test('whenNoLocationSet_doesntAddedLocationToEvents', () {
    final auditEventLogger = logger(testAuditConfigWithNullValues);
    log(auditEventLogger, AuditEventType.endOfForm);
    auditEventLogger.flush(); // Triggers event writing
    expect(testWriter.auditEvents[0].isLocationAlreadySet, isFalse);
  });

  test('isDuplicateOfLastAuditEventTest', () {
    final auditEventLogger = logger(testAuditConfig);
    log(auditEventLogger, AuditEventType.locationProvidersEnabled);
    expect(
      auditEventLogger.isDuplicateOfLastLocationEvent(
        AuditEventType.locationProvidersEnabled,
      ),
      isTrue,
    );
    log(auditEventLogger, AuditEventType.locationProvidersDisabled);
    expect(
      auditEventLogger.isDuplicateOfLastLocationEvent(
        AuditEventType.locationProvidersDisabled,
      ),
      isTrue,
    );
    expect(
      auditEventLogger.isDuplicateOfLastLocationEvent(
        AuditEventType.locationProvidersEnabled,
      ),
      isFalse,
    );

    auditEventLogger.flush(); // Triggers event writing
    expect(testWriter.auditEvents, hasLength(2));
  });

  test('withUserSet_addsUserToEvents', () {
    final auditEventLogger = logger(AuditConfig(isIdentifyUserEnabled: true))
      ..user = 'Riker';
    log(auditEventLogger, AuditEventType.endOfForm);
    auditEventLogger.flush(); // Triggers event writing
    expect(testWriter.auditEvents[0].user, 'Riker');
  });

  test('logEvent_WithChangeReason_addsChangeReasonToEvent', () {
    final auditEventLogger = logger(
      AuditConfig(isTrackChangesReasonEnabled: true),
    );
    auditEventLogger
      ..logEvent(
        AuditEventType.changeReason,
        writeImmediatelyToDisk: false,
        currentTime: 123,
        changeReason: 'Blah',
      )
      ..flush(); // Triggers event writing
    expect(testWriter.auditEvents[0].changeReason, 'Blah');
  });

  test('testEventTypes', () {
    final auditEventLogger = logger(testAuditConfig);
    for (final type in [
      AuditEventType.beginningOfForm, // shouldn't be logged
      AuditEventType.question,
      AuditEventType.group,
      AuditEventType.promptNewRepeat,
      AuditEventType.repeat, // shouldn't be logged
      AuditEventType.endOfForm,
      AuditEventType.formStart,
      AuditEventType.formResume,
      AuditEventType.formSave,
      AuditEventType.formFinalize,
      AuditEventType.hierarchy,
      AuditEventType.saveError,
      AuditEventType.finalizeError,
      AuditEventType.constraintError,
      AuditEventType.deleteRepeat,
      AuditEventType.googlePlayServicesNotAvailable,
      AuditEventType.locationPermissionsGranted,
      AuditEventType.locationPermissionsNotGranted,
      AuditEventType.locationTrackingEnabled,
      AuditEventType.locationTrackingDisabled,
      AuditEventType.locationProvidersEnabled,
      AuditEventType.locationProvidersDisabled,
      AuditEventType.unknownEventType,
    ]) {
      log(auditEventLogger, type);
    }
    auditEventLogger.flush(); // Triggers event writing
    expect(testWriter.auditEvents, hasLength(21));
  });

  test('location events are ignored when locations are not audited', () {
    final auditEventLogger = logger(AuditConfig());
    log(auditEventLogger, AuditEventType.locationTrackingEnabled);
    log(auditEventLogger, AuditEventType.formStart);
    auditEventLogger.flush();
    expect(
      testWriter.auditEvents.map((e) => e.auditEventType),
      [AuditEventType.formStart],
    );
  });

  test('interval events end with the new answer at flush', () {
    final clock = FakeAuditClock(5000);
    final auditEventLogger = AuditEventLogger(
      AuditConfig(isTrackingChangesEnabled: true),
      testWriter,
      formState,
      clock: clock,
    );
    auditEventLogger.logEvent(
      AuditEventType.question,
      formIndex: text1Index(),
      writeImmediatelyToDisk: true,
      questionAnswer: 'Old',
      currentTime: 0,
    );
    expect(testWriter.auditEvents, isEmpty);
    // A refresh of the same screen is not logged twice.
    auditEventLogger.logEvent(
      AuditEventType.question,
      formIndex: text1Index(),
      writeImmediatelyToDisk: true,
      currentTime: 0,
    );
    clock.advance(1500);
    auditEventLogger.flush();
    final event = testWriter.auditEvents.single;
    expect(event.start, 5000);
    expect(event.end, 6500);
    expect(event.oldValue, 'Old');
    expect(event.newValue, 'The answer');
  });
}
