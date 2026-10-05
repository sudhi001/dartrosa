// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// Helpers for tests whose JavaRosa originals switch the JVM default time
/// zone. Dart can't change the local zone at runtime, so those tests run
/// when the suite is started with a matching `TZ` (see CI) and are skipped
/// otherwise.
library;

/// Local offset at the instant [d].
Duration offsetAt(DateTime d) => d.toLocal().timeZoneOffset;

/// `null` (run) if the local zone has a fixed [offset] around [around],
/// otherwise a skip reason.
String? skipUnlessFixedOffset(Duration offset, DateTime around) {
  final a = DateTime.fromMillisecondsSinceEpoch(
    around.millisecondsSinceEpoch - 180 * 86400000,
  ).timeZoneOffset;
  final b = DateTime.fromMillisecondsSinceEpoch(
    around.millisecondsSinceEpoch + 180 * 86400000,
  ).timeZoneOffset;
  return a == offset && b == offset && around.timeZoneOffset == offset
      ? null
      : 'needs a local zone fixed at UTC${_format(offset)} '
            '(e.g. TZ=<${_format(offset)}>${_posix(offset)})';
}

/// Whether the local zone follows America/New_York's 2021 DST rules.
bool get isNewYork =>
    DateTime.fromMillisecondsSinceEpoch(1615705199999).timeZoneOffset ==
        const Duration(hours: -5) &&
    DateTime.fromMillisecondsSinceEpoch(1615705200000).timeZoneOffset ==
        const Duration(hours: -4);

/// Whether the local zone follows Europe/London's 2021 DST rules.
bool get isLondon =>
    DateTime.fromMillisecondsSinceEpoch(1616893199999).timeZoneOffset ==
        Duration.zero &&
    DateTime.fromMillisecondsSinceEpoch(1616893200000).timeZoneOffset ==
        const Duration(hours: 1);

String _format(Duration d) {
  final minutes = d.inMinutes.abs();
  final sign = d.isNegative ? '-' : '+';
  return '$sign${'${minutes ~/ 60}'.padLeft(2, '0')}'
      '${'${minutes % 60}'.padLeft(2, '0')}';
}

String _posix(Duration d) {
  final minutes = d.inMinutes.abs();
  final sign = d.isNegative ? '' : '-';
  return '$sign${minutes ~/ 60}:${'${minutes % 60}'.padLeft(2, '0')}';
}
