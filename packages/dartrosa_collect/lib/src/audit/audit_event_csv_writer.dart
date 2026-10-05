import 'dart:async';

import '../util/read_lines.dart';
import 'audit_event.dart';
import 'audit_event_csv_line.dart';
import 'audit_event_logger.dart';

/// Where an instance's audit log (`audit.csv`, next to the instance XML)
/// is kept. Apps implement it over files; [InMemoryAuditLogStore] serves
/// tests.
abstract interface class AuditLogStore {
  /// The whole log, or `null` when it doesn't exist yet.
  Future<String?> read();

  /// Replaces the whole log with [contents].
  Future<void> write(String contents);

  /// Appends [text] to the log, creating it if needed.
  Future<void> append(String text);
}

/// An [AuditLogStore] in memory.
final class InMemoryAuditLogStore implements AuditLogStore {
  /// Creates a store, empty or holding [contents].
  InMemoryAuditLogStore([this.contents]);

  /// The log, or `null` when it doesn't exist.
  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async => this.contents = contents;

  @override
  Future<void> append(String text) async => contents = '${contents ?? ''}$text';
}

/// Writes audit events as CSV lines to an [AuditLogStore], starting the
/// log with a header naming the enabled columns (and updating the header
/// of an existing log when the form now enables more columns).
///
/// Port of Collect's `AsyncTaskAuditEventWriter` and `AuditEventSaveTask`.
/// Each write runs asynchronously; while one runs, [isWriting] is `true`
/// and the logger keeps new events for the next batch. Unlike Collect
/// (whose save task is static), the in-progress state is per writer.
final class AuditEventCsvWriter implements AuditEventWriter {
  /// Creates a writer to [store] for the enabled columns. [onError]
  /// receives write failures (Collect only logs them).
  AuditEventCsvWriter(
    this.store, {
    required this.isLocationEnabled,
    required this.isTrackingChangesEnabled,
    required this.isUserRequired,
    required this.isTrackChangesReasonEnabled,
    this.onError,
  });

  static const _defaultColumns = 'event,node,start,end';
  static const _locationCoordinatesColumns = ',latitude,longitude,accuracy';
  static const _answerValuesColumns = ',old-value,new-value';
  static const _userColumns = ',user';
  static const _changeReasonColumns = ',change-reason';

  /// The log.
  final AuditLogStore store;

  /// Whether the location columns are written.
  final bool isLocationEnabled;

  /// Whether the old/new value columns are written.
  final bool isTrackingChangesEnabled;

  /// Whether the header has the user column.
  final bool isUserRequired;

  /// Whether the change reason column is written.
  final bool isTrackChangesReasonEnabled;

  /// Receives write failures.
  final void Function(Object error, StackTrace stackTrace)? onError;

  Future<void>? _saveTask;

  @override
  bool get isWriting => _saveTask != null;

  /// Completes when no write is in progress.
  Future<void> get idle async {
    while (_saveTask != null) {
      await _saveTask;
    }
  }

  @override
  void writeEvents(List<AuditEvent> auditEvents) {
    final events = List.of(auditEvents);
    final task = _save(events);
    _saveTask = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_saveTask, task)) _saveTask = null;
      }),
    );
  }

  Future<void> _save(List<AuditEvent> events) async {
    try {
      final existing = await store.read();
      if (existing == null) {
        await store.append('${_getHeader()}\n');
      } else {
        await _updateHeaderIfNeeded(existing);
      }
      final lines = StringBuffer();
      for (final aev in events) {
        lines
          ..write(
            auditEventToCsvLine(
              aev,
              isTrackingLocationsEnabled: isLocationEnabled,
              isTrackingChangesEnabled: isTrackingChangesEnabled,
              isTrackingChangesReasonEnabled: isTrackChangesReasonEnabled,
            ),
          )
          ..write('\n');
      }
      if (lines.isNotEmpty) await store.append(lines.toString());
    } on Object catch (e, s) {
      onError?.call(e, s);
    }
  }

  Future<void> _updateHeaderIfNeeded(String existing) async {
    final lines = readLines(existing);
    if (!_shouldHeaderBeUpdated(lines.isEmpty ? null : lines.first)) return;
    final updated = StringBuffer('${_getHeader()}\n');
    for (final line in lines.skip(1)) {
      updated.write('$line\n');
    }
    await store.write(updated.toString());
  }

  bool _shouldHeaderBeUpdated(String? header) =>
      header == null ||
      (isLocationEnabled && !header.contains(_locationCoordinatesColumns)) ||
      (isTrackingChangesEnabled && !header.contains(_answerValuesColumns)) ||
      (isUserRequired && !header.contains(_userColumns));

  String _getHeader() => [
    _defaultColumns,
    if (isLocationEnabled) _locationCoordinatesColumns,
    if (isTrackingChangesEnabled) _answerValuesColumns,
    if (isUserRequired) _userColumns,
    if (isTrackChangesReasonEnabled) _changeReasonColumns,
  ].join();
}
