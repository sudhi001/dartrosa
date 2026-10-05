// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (AsyncTaskAuditEventWriterTest), Copyright 2019
//  Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of Collect's AsyncTaskAuditEventWriterTest.
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import 'support.dart';

const _lat = '54.4112062';
const _lon = '18.5896652';
const _acc = '30.716999053955078';

AuditEvent _event(
  int start,
  AuditEventType type, {
  String? path,
  String? old,
  int? end,
  bool located = false,
  bool emptyLocation = false,
  String? newValue,
}) {
  final event = AuditEvent(
    start,
    type,
    formIndex: path == null ? null : getTestFormIndex(path),
    oldValue: old,
  );
  if (located) event.setLocationCoordinates(_lat, _lon, _acc);
  if (emptyLocation) event.setLocationCoordinates('', '', '');
  if (newValue != null) event.recordValueChange(newValue);
  if (end != null) event.setEnd(end);
  return event;
}

List<AuditEvent> getSampleAuditEventsWithoutLocations() => [
  _event(1548106927319, AuditEventType.formStart),
  _event(
    1548106927323,
    AuditEventType.question,
    path: '/data/q1',
    old: '',
    end: 1548106930112,
  ),
  _event(
    1548106930118,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[1]',
    old: '',
    end: 1548106931611,
  ),
  _event(
    1548106931612,
    AuditEventType.question,
    path: '/data/g1[1]/q2',
    old: '',
    end: 1548106937122,
  ),
  _event(
    1548106937123,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[2]',
    old: '',
    end: 1548106938276,
  ),
  _event(
    1548106938277,
    AuditEventType.question,
    path: '/data/g1[2]/q2',
    old: '',
    end: 1548106948127,
  ),
  _event(
    1548106948128,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[3]',
    old: '',
    end: 1548106949446,
  ),
  _event(1548106949448, AuditEventType.endOfForm, end: 1548106953601),
  _event(1548106953600, AuditEventType.formSave),
  _event(1548106953601, AuditEventType.formExit),
  _event(1548106953601, AuditEventType.formFinalize),
];

List<AuditEvent> getSampleAuditEventsWithUser() => [
  for (final event in getSampleAuditEventsWithoutLocations())
    event..user = 'User1',
];

List<AuditEvent> getSampleAuditEventsWithLocations() => [
  _event(1548106927319, AuditEventType.formStart, emptyLocation: true),
  _event(
    548108908250,
    AuditEventType.locationTrackingEnabled,
    emptyLocation: true,
  ),
  _event(
    548108908255,
    AuditEventType.locationPermissionsGranted,
    emptyLocation: true,
  ),
  _event(
    548108908259,
    AuditEventType.locationProvidersEnabled,
    emptyLocation: true,
  ),
  _event(
    1548106927323,
    AuditEventType.question,
    path: '/data/q1',
    old: '',
    located: true,
    end: 1548106930112,
  ),
  _event(
    1548106930118,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[1]',
    old: '',
    located: true,
    end: 1548106931611,
  ),
  _event(
    1548106931612,
    AuditEventType.question,
    path: '/data/g1[1]/q2',
    old: '',
    located: true,
    end: 1548106937122,
  ),
  _event(
    1548106937123,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[2]',
    old: '',
    located: true,
    end: 1548106938276,
  ),
  _event(
    1548106938277,
    AuditEventType.question,
    path: '/data/g1[2]/q2',
    old: '',
    located: true,
    end: 1548106948127,
  ),
  _event(
    1548106948128,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[3]',
    old: '',
    located: true,
    end: 1548106949446,
  ),
  _event(
    1548106949448,
    AuditEventType.endOfForm,
    located: true,
    end: 1548106953601,
  ),
  _event(1548106953600, AuditEventType.formSave, located: true),
  _event(1548106953601, AuditEventType.formExit, located: true),
  _event(1548106953601, AuditEventType.formFinalize, located: true),
];

List<AuditEvent> getSampleAuditEventsWithLocationsAndTrackingChanges() => [
  _event(1548106927319, AuditEventType.formStart, emptyLocation: true),
  _event(
    548108908250,
    AuditEventType.locationTrackingEnabled,
    emptyLocation: true,
  ),
  _event(
    548108908255,
    AuditEventType.locationPermissionsGranted,
    emptyLocation: true,
  ),
  _event(
    548108908259,
    AuditEventType.locationProvidersEnabled,
    emptyLocation: true,
  ),
  _event(
    1548106927323,
    AuditEventType.question,
    path: '/data/q1',
    old: 'Old value',
    located: true,
    newValue: 'New Value',
    end: 1548106930112,
  ),
  _event(
    1548106930118,
    AuditEventType.promptNewRepeat,
    path: '/data/g1[1]',
    located: true,
    end: 1548106931611,
  ),
  _event(
    1548106949448,
    AuditEventType.endOfForm,
    located: true,
    end: 1548106953601,
  ),
  _event(1548106953600, AuditEventType.formSave, located: true),
  _event(1548106953601, AuditEventType.formExit, located: true),
  _event(1548106953601, AuditEventType.formFinalize, located: true),
];

List<AuditEvent> getMoreSampleAuditEventsWithLocations() => [
  _event(1548108900606, AuditEventType.formResume, located: true),
  _event(
    1548108906276,
    AuditEventType.hierarchy,
    located: true,
    end: 1548108908206,
  ),
  _event(
    548108908250,
    AuditEventType.locationTrackingEnabled,
    emptyLocation: true,
  ),
  _event(
    548108908255,
    AuditEventType.locationPermissionsGranted,
    emptyLocation: true,
  ),
  _event(
    548108908259,
    AuditEventType.locationProvidersEnabled,
    emptyLocation: true,
  ),
  _event(
    1548108908285,
    AuditEventType.endOfForm,
    located: true,
    end: 1548108909730,
  ),
  _event(1548108909730, AuditEventType.formSave, located: true),
  _event(1548108909730, AuditEventType.formExit, located: true),
  _event(1548108909731, AuditEventType.formFinalize, located: true),
];

List<AuditEvent> getMoreSampleAuditEventsWithLocationsAndTrackingChanges() => [
  _event(1548108900606, AuditEventType.formResume, located: true),
  _event(
    1548108900700,
    AuditEventType.question,
    old: 'Old value',
    located: true,
    newValue: 'New value',
  ),
  _event(
    1548108903100,
    AuditEventType.question,
    old: 'Old value, with comma',
    located: true,
    newValue: 'New value',
  ),
  _event(
    1548108903101,
    AuditEventType.question,
    old: 'Old value \n with linebreak',
    located: true,
    newValue: 'New value \n with linebreak and "quotes"',
  ),
  _event(
    1548108904200,
    AuditEventType.question,
    old: 'Old value',
    located: true,
    newValue: 'New value, with comma',
  ),
  _event(1548108909730, AuditEventType.formSave, located: true),
  _event(1548108909730, AuditEventType.formExit, located: true),
  _event(1548108909731, AuditEventType.formFinalize, located: true),
];

List<AuditEvent>
getMoreSampleAuditEventsWithLocationsAndTrackingChangesAndUser() => [
  for (final event in getMoreSampleAuditEventsWithLocationsAndTrackingChanges())
    event..user = 'User1',
];

void main() {
  late InMemoryAuditLogStore auditFile;

  setUp(() => auditFile = InMemoryAuditLogStore());

  Future<String?> write(
    List<AuditEvent> events, {
    bool location = false,
    bool changes = false,
    bool user = false,
    bool reason = false,
  }) async {
    final writer = AuditEventCsvWriter(
      auditFile,
      isLocationEnabled: location,
      isTrackingChangesEnabled: changes,
      isUserRequired: user,
      isTrackChangesReasonEnabled: reason,
    )..writeEvents(events);
    expect(writer.isWriting, isTrue);
    await writer.idle;
    expect(writer.isWriting, isFalse);
    return auditFile.contents;
  }

  test('saveAuditWithLocation', () async {
    expect(
      await write(getSampleAuditEventsWithLocations(), location: true),
      'event,node,start,end,latitude,longitude,accuracy\n'
      'form start,,1548106927319,,,,\n'
      'location tracking enabled,,548108908250,,,,\n'
      'location permissions granted,,548108908255,,,,\n'
      'location providers enabled,,548108908259,,,,\n'
      'question,/data/q1,1548106927323,1548106930112,54.4112062,18.5896652,30.716999053955078\n'
      'add repeat,/data/g1[1],1548106930118,1548106931611,54.4112062,18.5896652,30.716999053955078\n'
      'question,/data/g1[1]/q2,1548106931612,1548106937122,54.4112062,18.5896652,30.716999053955078\n'
      'add repeat,/data/g1[2],1548106937123,1548106938276,54.4112062,18.5896652,30.716999053955078\n'
      'question,/data/g1[2]/q2,1548106938277,1548106948127,54.4112062,18.5896652,30.716999053955078\n'
      'add repeat,/data/g1[3],1548106948128,1548106949446,54.4112062,18.5896652,30.716999053955078\n'
      'end screen,,1548106949448,1548106953601,54.4112062,18.5896652,30.716999053955078\n'
      'form save,,1548106953600,,54.4112062,18.5896652,30.716999053955078\n'
      'form exit,,1548106953601,,54.4112062,18.5896652,30.716999053955078\n'
      'form finalize,,1548106953601,,54.4112062,18.5896652,30.716999053955078\n',
    );
  });

  test('saveAuditWithLocationAndTrackingChanges', () async {
    expect(
      await write(
        getSampleAuditEventsWithLocationsAndTrackingChanges(),
        location: true,
        changes: true,
      ),
      'event,node,start,end,latitude,longitude,accuracy,old-value,new-value\n'
      'form start,,1548106927319,,,,,,\n'
      'location tracking enabled,,548108908250,,,,,,\n'
      'location permissions granted,,548108908255,,,,,,\n'
      'location providers enabled,,548108908259,,,,,,\n'
      'question,/data/q1,1548106927323,1548106930112,54.4112062,18.5896652,30.716999053955078,Old value,New Value\n'
      'add repeat,/data/g1[1],1548106930118,1548106931611,54.4112062,18.5896652,30.716999053955078,,\n'
      'end screen,,1548106949448,1548106953601,54.4112062,18.5896652,30.716999053955078,,\n'
      'form save,,1548106953600,,54.4112062,18.5896652,30.716999053955078,,\n'
      'form exit,,1548106953601,,54.4112062,18.5896652,30.716999053955078,,\n'
      'form finalize,,1548106953601,,54.4112062,18.5896652,30.716999053955078,,\n',
    );
  });

  const withUser =
      'event,node,start,end,user\n'
      'form start,,1548106927319,,User1\n'
      'question,/data/q1,1548106927323,1548106930112,User1\n'
      'add repeat,/data/g1[1],1548106930118,1548106931611,User1\n'
      'question,/data/g1[1]/q2,1548106931612,1548106937122,User1\n'
      'add repeat,/data/g1[2],1548106937123,1548106938276,User1\n'
      'question,/data/g1[2]/q2,1548106938277,1548106948127,User1\n'
      'add repeat,/data/g1[3],1548106948128,1548106949446,User1\n'
      'end screen,,1548106949448,1548106953601,User1\n'
      'form save,,1548106953600,,User1\n'
      'form exit,,1548106953601,,User1\n'
      'form finalize,,1548106953601,,User1\n';

  test('saveAuditWithUser', () async {
    expect(await write(getSampleAuditEventsWithUser(), user: true), withUser);
  });

  test('saveAuditWithChangeReason', () async {
    expect(
      await write([
        AuditEvent(1548108900606, AuditEventType.formResume),
        AuditEvent(
          1548108900606,
          AuditEventType.changeReason,
          changeReason: 'A good reason',
        ),
      ], reason: true),
      'event,node,start,end,change-reason\n'
      'form resume,,1548108900606,,\n'
      'change reason,,1548108900606,,A good reason\n',
    );
  });

  test('whenChangeReasonHasCommaOrQuotes_escapesThem', () async {
    expect(
      await write([
        AuditEvent(1548108900606, AuditEventType.formResume),
        AuditEvent(
          1548108900606,
          AuditEventType.changeReason,
          changeReason: 'A "good", reason',
        ),
      ], reason: true),
      'event,node,start,end,change-reason\n'
      'form resume,,1548108900606,,\n'
      'change reason,,1548108900606,,"A ""good"", reason"\n',
    );
  });

  test('whenUserHasCommaOrQuotes_escapesThem', () async {
    final auditEvents = getSampleAuditEventsWithUser().sublist(0, 1);
    auditEvents[0].user = 'User,"1"';
    expect(
      await write(auditEvents, user: true),
      'event,node,start,end,user\n'
      'form start,,1548106927319,,"User,""1"""\n',
    );
  });

  // A user could update the app and then resume form entry. In this case
  // it would be possible for the form to have an audit config that wasn't
  // supported by the old app. In this case the writer should update the
  // header to account for the new data.
  test('whenAppUpdatedBetweenInstances_updatesHeader', () async {
    // Use a form with enabled audit but without location
    const body1 =
        'form start,,1548106927319,\n'
        'question,/data/q1,1548106927323,1548106930112\n'
        'add repeat,/data/g1[1],1548106930118,1548106931611\n'
        'question,/data/g1[1]/q2,1548106931612,1548106937122\n'
        'add repeat,/data/g1[2],1548106937123,1548106938276\n'
        'question,/data/g1[2]/q2,1548106938277,1548106948127\n'
        'add repeat,/data/g1[3],1548106948128,1548106949446\n'
        'end screen,,1548106949448,1548106953601\n'
        'form save,,1548106953600,\n'
        'form exit,,1548106953601,\n'
        'form finalize,,1548106953601,\n';
    expect(
      await write(getSampleAuditEventsWithoutLocations()),
      'event,node,start,end\n$body1',
    );

    // Upgrade a form to use location
    const body2 =
        'form resume,,1548108900606,,54.4112062,18.5896652,30.716999053955078\n'
        'jump,,1548108906276,1548108908206,54.4112062,18.5896652,30.716999053955078\n'
        'location tracking enabled,,548108908250,,,,\n'
        'location permissions granted,,548108908255,,,,\n'
        'location providers enabled,,548108908259,,,,\n'
        'end screen,,1548108908285,1548108909730,54.4112062,18.5896652,30.716999053955078\n'
        'form save,,1548108909730,,54.4112062,18.5896652,30.716999053955078\n'
        'form exit,,1548108909730,,54.4112062,18.5896652,30.716999053955078\n'
        'form finalize,,1548108909731,,54.4112062,18.5896652,30.716999053955078\n';
    expect(
      await write(getMoreSampleAuditEventsWithLocations(), location: true),
      'event,node,start,end,latitude,longitude,accuracy\n$body1$body2',
    );

    // Upgrade a form to use location and tracking changes
    const body3 =
        'form resume,,1548108900606,,54.4112062,18.5896652,30.716999053955078,,\n'
        'question,,1548108900700,,54.4112062,18.5896652,30.716999053955078,Old value,New value\n'
        'question,,1548108903100,,54.4112062,18.5896652,30.716999053955078,"Old value, with comma",New value\n'
        'question,,1548108903101,,54.4112062,18.5896652,30.716999053955078,"Old value \n with linebreak","New value \n with linebreak and ""quotes"""\n'
        'question,,1548108904200,,54.4112062,18.5896652,30.716999053955078,Old value,"New value, with comma"\n'
        'form save,,1548108909730,,54.4112062,18.5896652,30.716999053955078,,\n'
        'form exit,,1548108909730,,54.4112062,18.5896652,30.716999053955078,,\n'
        'form finalize,,1548108909731,,54.4112062,18.5896652,30.716999053955078,,\n';
    expect(
      await write(
        getMoreSampleAuditEventsWithLocationsAndTrackingChanges(),
        location: true,
        changes: true,
      ),
      'event,node,start,end,latitude,longitude,accuracy,old-value,new-value\n'
      '$body1$body2$body3',
    );

    // Upgrade a form to use location and tracking changes and user
    const body4 =
        'form resume,,1548108900606,,54.4112062,18.5896652,30.716999053955078,,,User1\n'
        'question,,1548108900700,,54.4112062,18.5896652,30.716999053955078,Old value,New value,User1\n'
        'question,,1548108903100,,54.4112062,18.5896652,30.716999053955078,"Old value, with comma",New value,User1\n'
        'question,,1548108903101,,54.4112062,18.5896652,30.716999053955078,"Old value \n with linebreak","New value \n with linebreak and ""quotes""",User1\n'
        'question,,1548108904200,,54.4112062,18.5896652,30.716999053955078,Old value,"New value, with comma",User1\n'
        'form save,,1548108909730,,54.4112062,18.5896652,30.716999053955078,,,User1\n'
        'form exit,,1548108909730,,54.4112062,18.5896652,30.716999053955078,,,User1\n'
        'form finalize,,1548108909731,,54.4112062,18.5896652,30.716999053955078,,,User1\n';
    expect(
      await write(
        getMoreSampleAuditEventsWithLocationsAndTrackingChangesAndUser(),
        location: true,
        changes: true,
        user: true,
      ),
      'event,node,start,end,latitude,longitude,accuracy,old-value,new-value,'
      'user\n$body1$body2$body3$body4',
    );
  });

  test('write failures go to onError', () async {
    final errors = <Object>[];
    final writer = AuditEventCsvWriter(
      _FailingStore(),
      isLocationEnabled: false,
      isTrackingChangesEnabled: false,
      isUserRequired: false,
      isTrackChangesReasonEnabled: false,
      onError: (e, _) => errors.add(e),
    )..writeEvents([AuditEvent(1, AuditEventType.formStart)]);
    await writer.idle;
    expect(errors, hasLength(1));
  });
}

final class _FailingStore implements AuditLogStore {
  @override
  Future<void> append(String text) async => throw StateError('disk full');

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String contents) async => throw StateError('disk full');
}
