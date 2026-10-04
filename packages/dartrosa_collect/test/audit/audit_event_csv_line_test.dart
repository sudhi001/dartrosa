// Port of Collect's AuditEventCSVLineTest and CSVUtilsTest.
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import 'support.dart';

const startTime = 1545392727685;
const endTime = 1545392728527;

String line(AuditEvent e, bool locations, bool changes, bool reasons) =>
    auditEventToCsvLine(
      e,
      isTrackingLocationsEnabled: locations,
      isTrackingChangesEnabled: changes,
      isTrackingChangesReasonEnabled: reasons,
    );

AuditEvent question(String old, String? user, String? reason) => AuditEvent(
  1,
  AuditEventType.question,
  formIndex: text1Index(),
  oldValue: old,
  user: user,
  changeReason: reason,
);

void main() {
  group('CSV spec (RFC 4180)', () {
    test('commas should be surrounded by quotes', () {
      final auditEvent = question('a, b', 'c, d', 'e, f')
        ..recordValueChange('g, h')
        ..setEnd(2);
      expect(
        line(auditEvent, false, true, true),
        'question,/data/text1,1,2,"a, b","g, h","c, d","e, f"',
      );
    });

    test('newlines should be surrounded by quotes', () {
      final auditEvent = question('a\nb', 'c\nd', 'e\nf')
        ..recordValueChange('g\nh')
        ..setEnd(2);
      expect(
        line(auditEvent, false, true, true),
        'question,/data/text1,1,2,"a\nb","g\nh","c\nd","e\nf"',
      );
    });

    test('quotes should be escaped and surrounded by quotes', () {
      final auditEvent = question('a"b', 'c"d', 'e"f')
        ..recordValueChange('g"h')
        ..setEnd(2);
      expect(
        line(auditEvent, false, true, true),
        'question,/data/text1,1,2,"a""b","g""h","c""d","e""f"',
      );
    });
  });

  test('toString', () {
    final auditEvent = AuditEvent(
      startTime,
      AuditEventType.question,
      formIndex: text1Index(),
      oldValue: '',
    );
    expect(auditEvent.isIntervalAuditEventType, isTrue);
    expect(
      line(auditEvent, false, false, false),
      'question,/data/text1,1545392727685,',
    );
    expect(auditEvent.isEndTimeSet, isFalse);
    auditEvent.setEnd(endTime);
    expect(auditEvent.isEndTimeSet, isTrue);
    expect(auditEvent.isLocationAlreadySet, isFalse);
    expect(
      line(auditEvent, false, false, false),
      'question,/data/text1,1545392727685,1545392728527',
    );
  });

  test('toString with location coordinates', () {
    final auditEvent = AuditEvent(
      startTime,
      AuditEventType.question,
      formIndex: text1Index(),
      oldValue: '',
    )..setLocationCoordinates('54.35202520000001', '18.64663840000003', '10');
    expect(auditEvent.isIntervalAuditEventType, isTrue);
    expect(auditEvent.isEndTimeSet, isFalse);
    auditEvent.setEnd(endTime);
    expect(auditEvent.isEndTimeSet, isTrue);
    expect(auditEvent.isLocationAlreadySet, isTrue);
    expect(
      line(auditEvent, true, false, false),
      'question,/data/text1,1545392727685,1545392728527,54.35202520000001,'
      '18.64663840000003,10',
    );
  });

  test('toString with tracking changes', () {
    final auditEvent = AuditEvent(
      startTime,
      AuditEventType.question,
      formIndex: text1Index(),
      oldValue: 'First answer',
    );
    expect(auditEvent.isIntervalAuditEventType, isTrue);
    auditEvent.setEnd(endTime);
    expect(auditEvent.isLocationAlreadySet, isFalse);
    auditEvent.recordValueChange('Second answer');
    expect(
      line(auditEvent, false, true, false),
      'question,/data/text1,1545392727685,1545392728527,First answer,'
      'Second answer',
    );
  });

  test('toString with location coordinates and tracking changes', () {
    final auditEvent = AuditEvent(
      startTime,
      AuditEventType.question,
      formIndex: text1Index(),
      oldValue: 'First answer',
    )..setLocationCoordinates('54.35202520000001', '18.64663840000003', '10');
    auditEvent.setEnd(endTime);
    expect(auditEvent.isLocationAlreadySet, isTrue);
    auditEvent.recordValueChange('Second, answer');
    expect(
      line(auditEvent, true, true, false),
      'question,/data/text1,1545392727685,1545392728527,54.35202520000001,'
      '18.64663840000003,10,First answer,"Second, answer"',
    );
  });

  test('toString null values', () {
    final auditEvent = AuditEvent(
      startTime,
      AuditEventType.question,
      formIndex: text1Index(),
      oldValue: 'Old value',
    )..setLocationCoordinates('', '', '');
    auditEvent.setEnd(endTime);
    expect(auditEvent.isLocationAlreadySet, isFalse);
    auditEvent.recordValueChange('New value');
    expect(
      line(auditEvent, true, true, false),
      'question,/data/text1,1545392727685,1545392728527,,,,Old value,'
      'New value',
    );
  });

  test('unset coordinates are written as null, like Collect', () {
    final auditEvent = AuditEvent(startTime, AuditEventType.formStart);
    expect(
      line(auditEvent, true, false, false),
      'form start,,1545392727685,,null,null,null',
    );
  });

  test('testEventTypes', () {
    const expectations = <AuditEventType, (String, bool)>{
      AuditEventType.question: ('question', true),
      AuditEventType.formStart: ('form start', false),
      AuditEventType.endOfForm: ('end screen', true),
      AuditEventType.repeat: ('repeat', false),
      AuditEventType.promptNewRepeat: ('add repeat', true),
      AuditEventType.group: ('group questions', true),
      AuditEventType.beginningOfForm: ('beginning of form', false),
      AuditEventType.formExit: ('form exit', false),
      AuditEventType.formResume: ('form resume', false),
      AuditEventType.formSave: ('form save', false),
      AuditEventType.formFinalize: ('form finalize', false),
      AuditEventType.hierarchy: ('jump', true),
      AuditEventType.saveError: ('save error', false),
      AuditEventType.finalizeError: ('finalize error', false),
      AuditEventType.constraintError: ('constraint error', false),
      AuditEventType.deleteRepeat: ('delete repeat', false),
      AuditEventType.googlePlayServicesNotAvailable: (
        'google play services not available',
        false,
      ),
      AuditEventType.locationPermissionsGranted: (
        'location permissions granted',
        false,
      ),
      AuditEventType.locationPermissionsNotGranted: (
        'location permissions not granted',
        false,
      ),
      AuditEventType.locationTrackingEnabled: (
        'location tracking enabled',
        false,
      ),
      AuditEventType.locationTrackingDisabled: (
        'location tracking disabled',
        false,
      ),
      AuditEventType.locationProvidersEnabled: (
        'location providers enabled',
        false,
      ),
      AuditEventType.locationProvidersDisabled: (
        'location providers disabled',
        false,
      ),
      AuditEventType.unknownEventType: ('Unknown AuditEvent Type', false),
    };
    expectations.forEach((type, expected) {
      final (value, isInterval) = expected;
      final auditEvent = AuditEvent(startTime, type);
      expect(auditEvent.isIntervalAuditEventType, isInterval, reason: value);
      expect(line(auditEvent, false, false, false), '$value,,1545392727685,');
    });
  });

  group('CSVUtils', () {
    test('null should be passed through', () {
      expect(getEscapedValueForCsv(null), isNull);
    });

    test('strings without quotes, commas or newlines are passed through', () {
      expect(getEscapedValueForCsv('a b c d e'), 'a b c d e');
    });

    test('quotes should be escaped and surrounded by quotes', () {
      expect(getEscapedValueForCsv('a"b"'), '"a""b"""');
    });

    test('commas should be surrounded by quotes', () {
      expect(getEscapedValueForCsv('a,b'), '"a,b"');
    });

    test('newlines should be surrounded by quotes', () {
      expect(getEscapedValueForCsv('a\nb'), '"a\nb"');
    });
  });

  test('getXPathPath only has positions for repeats', () {
    expect(getXPathPath(getTestFormIndex('/data/g1[2]/q2')), '/data/g1[2]/q2');
    expect(getXPathPath(getTestFormIndex('/data/q1')), '/data/q1');
  });
}
