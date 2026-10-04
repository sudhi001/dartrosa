// Port of Collect's AuditEventTest.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

void main() {
  test('getAuditEventTypeFromFecTypeTest', () {
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.beginningOfForm),
        AuditEventType.beginningOfForm);
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.group),
        AuditEventType.group);
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.repeat),
        AuditEventType.repeat);
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.promptNewRepeat),
        AuditEventType.promptNewRepeat);
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.endOfForm),
        AuditEventType.endOfForm);
    // Collect: an unknown event code (100).
    expect(AuditEventType.fromFormEntryEvent(null),
        AuditEventType.unknownEventType);
    expect(AuditEventType.fromFormEntryEvent(FormEntryEvent.question),
        AuditEventType.unknownEventType);
  });
}
