// DartRosa tests of FormAudit over a FormSession, including ports of the
// audit tests of Collect's FormSaveViewModelTest and
// IdentityPromptViewModelTest.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import 'support.dart';

String auditForm(String auditAttributes) =>
    '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms"
    xmlns:orx="http://openrosa.org/xforms">
  <h:head>
    <h:title>Audit</h:title>
    <model>
      <instance>
        <data id="audit">
          <q1/>
          <fl><q2/><q3/></fl>
          <rep jr:template=""><q4/></rep>
          <meta><instanceID/><audit/></meta>
        </data>
      </instance>
      <bind nodeset="/data/q1" type="string"/>
      <bind nodeset="/data/fl/q2" type="string"/>
      <bind nodeset="/data/fl/q3" type="int"/>
      <bind nodeset="/data/rep/q4" type="string"/>
      <bind nodeset="/data/meta/instanceID" type="string" jr:preload="uid"/>
      <bind nodeset="/data/meta/audit" type="binary" $auditAttributes/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/q1"><label>Q1</label></input>
    <group ref="/data/fl" appearance="field-list">
      <label>FL</label>
      <input ref="/data/fl/q2"><label>Q2</label></input>
      <input ref="/data/fl/q3"><label>Q3</label></input>
    </group>
    <repeat nodeset="/data/rep">
      <input ref="/data/rep/q4"><label>Q4</label></input>
    </repeat>
  </h:body>
</h:html>
''';

/// A logger recording the calls made to it.
final class RecordingLogger implements AuditEventWriter {
  final calls = <String>[];

  @override
  void writeEvents(List<AuditEvent> auditEvents) {
    for (final e in auditEvents) {
      calls.add(e.auditEventType.value);
    }
  }

  @override
  bool get isWriting => false;
}

void main() {
  late FakeAuditClock clock;
  late InMemoryAuditLogStore store;

  setUp(() {
    clock = FakeAuditClock(1000000);
    store = InMemoryAuditLogStore();
  });

  Future<FormAudit> audit(
    String attributes, {
    bool isEditing = false,
    AuditLocationSource? locationSource,
  }) async {
    final definition = await FormDefinition.parse(auditForm(attributes));
    return FormAudit(
      definition.createSession(),
      store: store,
      clock: clock,
      isEditing: isEditing,
      locationSource: locationSource,
    );
  }

  test('reads the configuration and sets meta/audit to audit.csv', () async {
    final formAudit = await audit(
      'odk:location-priority="balanced" odk:location-min-interval="20" '
      'odk:location-max-age="30" odk:track-changes="true" '
      'odk:identify-user="true" odk:track-changes-reasons="on-form-edit"',
    );
    final config = formAudit.config!;
    expect(config.locationPriority, LocationPriority.balancedPowerAccuracy);
    expect(config.locationMinInterval, 20000);
    expect(config.locationMaxAge, 30000);
    expect(config.isLocationEnabled, isTrue);
    expect(config.isTrackingChangesEnabled, isTrue);
    expect(config.isIdentifyUserEnabled, isTrue);
    expect(config.isTrackChangesReasonEnabled, isTrue);
    final form = formAudit.session.definition.formDef;
    expect(
      form.mainInstance.root
          .firstChild('meta')!
          .firstChild('audit')!
          .value
          ?.displayText,
      'audit.csv',
    );
  });

  test('track-changes-reasons other than on-form-edit is off', () async {
    final formAudit = await audit('odk:track-changes-reasons="always"');
    expect(formAudit.config!.isTrackChangesReasonEnabled, isFalse);
    expect(formAudit.config!.isLocationEnabled, isFalse);
  });

  test('a form without meta/audit logs nothing', () async {
    final definition = await FormDefinition.parse(
      auditForm('').replaceAll('<audit/>', ''),
    );
    final formAudit = FormAudit(
      definition.createSession(),
      store: store,
      clock: clock,
    );
    expect(formAudit.isEnabled, isFalse);
    formAudit
      ..formStarted()
      ..saved(exiting: true, finalized: true);
    await formAudit.close();
    expect(store.contents, isNull);
  });

  test('logs a filling session like Collect', () async {
    final formAudit = await audit('odk:track-changes="true"');
    final session = formAudit.session;
    final nav = session.navigator;

    formAudit.formStarted();
    nav.next(); // q1
    formAudit.screenRefreshed();
    clock.advance(1000);
    session.answer(nav.position, const StringValue('hello'));
    nav.next(); // field-list group
    formAudit.screenChanged();
    clock.advance(2000);
    final q3 = (session.nodeAt(nav.position) as GroupNode).children[1].index;
    session.answer(q3, const IntegerValue(7));
    // Leave the field list (Collect steps over the group's questions).
    nav
      ..next()
      ..next()
      ..next(); // repeat prompt
    expect(nav.event, FormEntryEvent.promptNewRepeat);
    formAudit.screenChanged();
    clock.advance(500);
    nav.next(); // end
    formAudit.screenChanged();
    clock.advance(100);
    formAudit
      ..beforeSave()
      ..saved(exiting: true, finalized: true);
    await formAudit.close();

    expect(
      store.contents,
      'event,node,start,end,old-value,new-value\n'
      'form start,,1000000,,,\n'
      'question,/data/q1,1000000,1001000,,hello\n'
      'question,/data/fl/q3,1001000,1003000,,7\n'
      'group questions,/data/fl,1001000,1003000,,\n'
      'add repeat,/data/rep[1],1003000,1003500,,\n'
      'end screen,,1003500,1003600,,\n'
      'form save,,1003600,,,\n'
      'form exit,,1003600,,,\n'
      'form finalize,,1003600,,,\n',
    );
  });

  test(
    'without tracking changes, field-list questions are not logged',
    () async {
      final formAudit = await audit('');
      final session = formAudit.session;
      final nav = session.navigator;
      formAudit.formStarted();
      nav
        ..next()
        ..next(); // field-list group
      formAudit.screenRefreshed();
      final q2 = (session.nodeAt(nav.position) as GroupNode).children[0].index;
      session.answer(q2, const StringValue('x'));
      clock.advance(10);
      formAudit.answersUpdated();
      await formAudit.close();
      expect(
        store.contents,
        'event,node,start,end\n'
        'form start,,1000000,\n'
        'group questions,/data/fl,1000000,1000010\n',
      );
    },
  );

  test('locations from the source are added to events', () async {
    final formAudit = await audit(
      'odk:location-priority="high-accuracy" odk:location-min-interval="1" '
      'odk:location-max-age="60"',
      locationSource: (config) {
        expect(config.locationPriority, LocationPriority.highAccuracy);
        return Stream.value(
          const AuditLocation(
            latitude: 1.5,
            longitude: 2.25,
            accuracy: 3,
            time: 1000000,
          ),
        );
      },
    );
    formAudit.formStarted();
    await Future<void>.delayed(Duration.zero);
    formAudit
      ..logLocationEvent(AuditEventType.locationProvidersEnabled)
      ..logLocationEvent(AuditEventType.locationProvidersEnabled)
      ..exitedWithoutSaving();
    await formAudit.close();
    expect(
      store.contents,
      'event,node,start,end,latitude,longitude,accuracy\n'
      'form start,,1000000,,,,\n'
      'location providers enabled,,1000000,,1.5,2.25,3.0\n'
      'form exit,,1000000,,1.5,2.25,3.0\n',
    );
  });

  group('FormSaveViewModelTest (audit)', () {
    Future<List<String>> events(void Function(FormAudit) actions) async {
      final formAudit = await audit(
        'odk:track-changes-reasons="on-form-edit"',
        isEditing: true,
      );
      actions(formAudit);
      await formAudit.close();
      return [
        for (final line in (store.contents ?? '').split('\n').skip(1))
          if (line.isNotEmpty) line.split(',').first,
      ];
    }

    test(
      'whenFormSaverFinishes_whenViewExiting_logsFormSaveAndFormExit',
      () async {
        expect(
          await events(
            (a) => a
              ..beforeSave()
              ..saved(exiting: true, finalized: false),
          ),
          ['form save', 'form exit'],
        );
      },
    );

    test('whenFormComplete_andViewExiting_logsFormExitAndFinalize', () async {
      expect(
        await events(
          (a) => a
            ..beforeSave()
            ..saved(exiting: true, finalized: true),
        ),
        ['form save', 'form exit', 'form finalize'],
      );
    });

    test('saveError_logsSaveErrorAuditEvent', () async {
      expect(await events((a) => a.saveFailed()), ['save error']);
    });

    test('encryptionError_logsFinalizeErrorAuditEvent', () async {
      expect(await events((a) => a.finalizeFailed()), ['finalize error']);
    });

    test('answerConstraintViolated_logsConstraintErrorAuditEvent', () async {
      expect(await events((a) => a.constraintError()), ['constraint error']);
    });

    test(
      'whenReasonRequiredToSave_resumeSave_logsChangeReasonAuditEvent',
      () async {
        late bool required;
        late bool accepted;
        final logged = await events((a) {
          required = a.requiresChangeReason;
          accepted = a.changeReasonGiven('Blah');
        });
        expect(required, isTrue);
        expect(accepted, isTrue);
        expect(logged, ['change reason']);
        expect(store.contents, contains('change reason,,1000000,,Blah\n'));
      },
    );

    test('whenReasonIsNotValid_doesNotSave', () async {
      late bool accepted;
      final logged = await events((a) => accepted = a.changeReasonGiven('  '));
      expect(accepted, isFalse);
      expect(logged, isEmpty);
    });

    test('change reasons are not required for new instances', () async {
      final formAudit = await audit('odk:track-changes-reasons="on-form-edit"');
      expect(formAudit.requiresChangeReason, isFalse);
    });
  });

  group('IdentityPromptViewModelTest', () {
    test('done sets user on audit event logger', () async {
      final formAudit = await audit('odk:identify-user="true"');
      expect(formAudit.requiresIdentity, isTrue);
      expect(formAudit.identify('  '), isTrue);
      expect(formAudit.identify('Picard'), isFalse);
      expect(formAudit.logger.user, 'Picard');
      formAudit.formStarted();
      await formAudit.close();
      expect(
        store.contents,
        'event,node,start,end,user\nform start,,1000000,,Picard\n',
      );
    });

    test('identity is not required without identify-user', () async {
      final formAudit = await audit('');
      expect(formAudit.requiresIdentity, isFalse);
    });
  });

  test('a recording writer sees events in Collect order', () {
    final writer = RecordingLogger();
    AuditEventLogger(AuditConfig(), writer, null)
      ..logEvent(
        AuditEventType.formSave,
        writeImmediatelyToDisk: false,
        currentTime: 0,
      )
      ..logEvent(
        AuditEventType.formExit,
        writeImmediatelyToDisk: true,
        currentTime: 0,
      );
    expect(writer.calls, ['form save', 'form exit']);
  });
}
