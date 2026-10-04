import 'package:dartrosa/dartrosa.dart';

import 'audit_event.dart';

/// Escapes [value] for a CSV field (RFC 4180): doubles quotes and quotes
/// the field when it contains a comma, newline or quote. `null` stays
/// `null`.
///
/// Port of Collect's `CSVUtils.getEscapedValueForCsv`.
String? getEscapedValueForCsv(String? value) {
  if (value == null) return null;
  final escaped = value.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('\n') ||
      escaped.contains('"')) {
    return '"$escaped"';
  }
  return escaped;
}

/// Formats [auditEvent] as a line of the audit CSV (without the line
/// break). The location, old/new value and change reason columns are
/// present when enabled; the user column when the event has a user.
///
/// Port of Collect's `AuditEventCSVLine.toCSVLine`. Like Collect, unset
/// location coordinates are written as `null` and an unset end time as an
/// empty field.
String auditEventToCsvLine(
  AuditEvent auditEvent, {
  required bool isTrackingLocationsEnabled,
  required bool isTrackingChangesEnabled,
  required bool isTrackingChangesReasonEnabled,
}) {
  final formIndex = auditEvent.formIndex;
  final end = auditEvent.end;
  final node = formIndex == null || formIndex.reference == null
      ? ''
      : getXPathPath(formIndex);

  final line = StringBuffer(
    '${auditEvent.auditEventType.value},$node,${auditEvent.start},'
    '${end != 0 ? end : ''}',
  );
  if (isTrackingLocationsEnabled) {
    line.write(
      ',${auditEvent.latitude},${auditEvent.longitude},'
      '${auditEvent.accuracy}',
    );
  }
  if (isTrackingChangesEnabled) {
    line.write(
      ',${getEscapedValueForCsv(auditEvent.oldValue)},'
      '${getEscapedValueForCsv(auditEvent.newValue)}',
    );
  }
  final user = auditEvent.user;
  if (user != null) line.write(',${getEscapedValueForCsv(user)}');
  if (isTrackingChangesReasonEnabled) {
    final changeReason = auditEvent.changeReason;
    line.write(
      changeReason != null ? ',${getEscapedValueForCsv(changeReason)}' : ',',
    );
  }
  return line.toString();
}

/// The XPath path of the node at [formIndex], with position predicates
/// only for repeats: `/my-group/my-repeat[3]/my-question` rather than
/// `/my-group[1]/my-repeat[3]/my-question[1]`.
///
/// Port of `AuditEventCSVLine.getXPathPath`.
String getXPathPath(FormIndex formIndex) {
  final reference = formIndex.reference!;
  final nodeNames = <String>[reference.nameAt(0)];
  FormIndex? walker = formIndex;
  var i = 1;
  while (walker != null) {
    if (i < reference.size) {
      var currentNodeName = reference.nameAt(i);
      if (walker.instanceIndex != -1) {
        currentNodeName = '$currentNodeName[${walker.instanceIndex + 1}]';
      }
      nodeNames.add(currentNodeName);
    }
    walker = walker.nextLevel;
    i++;
  }
  return '/${nodeNames.join('/')}';
}
