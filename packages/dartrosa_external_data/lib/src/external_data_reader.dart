import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:logging/logging.dart';

import 'csv_reader.dart';
import 'external_data_exception.dart';
import 'external_data_repository.dart';
import 'external_data_set.dart';
import 'external_data_util.dart';

final _log = Logger('dartrosa_external_data');

/// Receives progress messages while CSVs are imported (Collect shows them
/// on the form loading dialog).
typedef ExternalDataProgress = void Function(String message);

/// A CSV media file to import.
final class ExternalDataFile {
  /// Creates the file [fileName] with content [bytes].
  const ExternalDataFile(this.fileName, this.bytes);

  /// The file name, e.g. `fruits.csv`.
  final String fileName;

  /// The file's bytes.
  final Uint8List bytes;

  /// The MD5 hash Collect records to detect changed files.
  String get md5Hash => md5.convert(bytes).toString();
}

/// Imports CSV files into an [ExternalDataRepository], skipping files that
/// haven't changed since their last import.
///
/// Port of Collect's `ExternalDataReaderImpl` and the import half of
/// `ExternalSQLiteOpenHelper` (`importFromCSV`, `onCreateNamed`,
/// `shouldUpdateDBforDataSet`).
final class ExternalDataReader {
  /// Creates a reader storing into [repository]; [isCancelled] is polled
  /// between rows and [onProgress] receives progress messages.
  ExternalDataReader(
    this.repository, {
    bool Function()? isCancelled,
    ExternalDataProgress? onProgress,
  }) : _isCancelled = isCancelled ?? _never,
       _onProgress = onProgress ?? _ignore;

  static bool _never() => false;
  static void _ignore(String message) {}

  /// Where imported data sets are stored.
  final ExternalDataRepository repository;
  final bool Function() _isCancelled;
  final ExternalDataProgress _onProgress;

  /// Imports [externalDataMap] (data set name → file; `null` for a missing
  /// file, which is skipped). Returns `false` if the import was cancelled:
  /// the partly imported data set is dropped and the remaining files are
  /// not processed. Throws [ExternalDataException] if a file can't be
  /// imported.
  Future<bool> doImport(Map<String, ExternalDataFile?> externalDataMap) async {
    for (final MapEntry(key: dataSetName, value: file)
        in externalDataMap.entries) {
      if (file == null) continue;
      if (!await _doImportDataSetAndContinue(dataSetName, file)) return false;
    }
    return true;
  }

  Future<bool> _doImportDataSetAndContinue(
    String dataSetName,
    ExternalDataFile file,
  ) async {
    final md5 = file.md5Hash;
    final priorMd5 = await repository.importedMd5(dataSetName, file.fileName);
    if (priorMd5 != null) {
      if (priorMd5 == md5) return true;
      await repository.delete(dataSetName);
    }
    final ExternalDataTable? table;
    try {
      table = importFromCsv(
        file,
        isCancelled: _isCancelled,
        onProgress: _onProgress,
      );
    } on Object catch (e) {
      final reason = e is ExternalDataException ? e.message : '$e';
      throw ExternalDataException(
        'Could not import data from ${file.fileName}. Reason: $reason',
        e,
      );
    }
    if (table == null) {
      _log.warning('The import was cancelled, so we need to rollback.');
      await repository.delete(dataSetName);
      return false;
    }
    await repository.save(
      dataSetName,
      table,
      fileName: file.fileName,
      md5: md5,
    );
    return true;
  }

  /// Parses the CSV [file] into a table, or returns `null` if
  /// [isCancelled] became true. Throws [ExternalDataException] (with
  /// Collect's message) for invalid files.
  ///
  /// Port of `ExternalSQLiteOpenHelper.onCreateNamed`: the header row names
  /// the columns (BOM removed, blank names skipped, names made safe with
  /// [ExternalDataUtil.toSafeColumnName], which must not collide); blank
  /// rows are skipped and short rows padded; a `sortby` column must be
  /// numeric and otherwise the row number is the sort key; columns whose
  /// header ends with `_key` are indexed by Collect, which fails for
  /// headers that aren't SQL identifiers.
  static ExternalDataTable? importFromCsv(
    ExternalDataFile file, {
    bool Function() isCancelled = _never,
    ExternalDataProgress onProgress = _ignore,
  }) {
    final name = file.fileName;
    onProgress("Pre-loading data from '$name', please wait… ");
    final reader = CollectCsvReader(
      utf8.decode(file.bytes, allowMalformed: true),
    );
    final headerRow = reader.readNext();
    if (headerRow == null) {
      // Java: NullPointerException on headerRow[0].
      throw ExternalDataException('null');
    }
    if (headerRow[0].startsWith('﻿')) {
      headerRow[0] = headerRow[0].substring(1);
    }
    if (!ExternalDataUtil.containsAnyData(headerRow)) {
      throw ExternalDataException('The file contains no data!');
    }
    final conflicting = ExternalDataUtil.findMatchingColumnsAfterSafeningNames(
      headerRow,
    );
    if (conflicting != null && conflicting.isNotEmpty) {
      throw ExternalDataException('Columns [${conflicting.join(', ')}] match!');
    }

    final cache = <String, String>{};
    final columns = <String>[];
    var sortColumnAlreadyPresent = false;
    for (var i = 0; i < headerRow.length; i++) {
      final columnName = javaTrim(headerRow[i]);
      if (columnName.isEmpty) {
        if (i == 0) {
          // Collect's CREATE TABLE then starts with "( , c_..." and fails.
          throw ExternalDataException(
            'near ",": syntax error (code 1 SQLITE_ERROR)',
          );
        }
        continue;
      }
      final safe = ExternalDataUtil.toSafeColumnNameCached(columnName, cache);
      if (safe == ExternalDataUtil.sortColumnName) {
        sortColumnAlreadyPresent = true;
      }
      columns.add(safe);
    }
    if (!sortColumnAlreadyPresent) columns.add(ExternalDataUtil.sortColumnName);
    final table = ExternalDataTable(columns);

    final indexedHeaders = [
      for (final header in headerRow)
        if (header.endsWith('_key')) header,
    ];

    var rowCount = 0;
    for (
      var row = reader.readNext();
      row != null && !isCancelled();
      row = reader.readNext()
    ) {
      // SCTO-894: skip empty lines, pad short rows.
      if (!ExternalDataUtil.containsAnyData(row)) continue;
      final List<String> fullRow = row.length < headerRow.length
          ? ExternalDataUtil.fillUpNullValues(row, headerRow)
          : row;
      final values = <String, Object?>{
        if (!sortColumnAlreadyPresent)
          ExternalDataUtil.sortColumnName: (rowCount + 1).toDouble(),
      };
      for (var i = 0; i < fullRow.length && i < headerRow.length; i++) {
        final columnName = javaTrim(headerRow[i]);
        final columnValue = fullRow[i];
        if (columnName.isEmpty) continue;
        final safe = ExternalDataUtil.toSafeColumnNameCached(columnName, cache);
        if (safe == ExternalDataUtil.sortColumnName) {
          final number = javaParseDouble(columnValue);
          if (number == null) {
            throw ExternalDataException(
              'Your sortby column should contain only numeric values. '
              "Conflicting value was '$columnValue'.",
            );
          }
          values[safe] = number;
        } else {
          values[safe] = columnValue;
        }
      }
      table.insert(values);
      rowCount++;
      if (rowCount % 100 == 0) {
        onProgress(
          "Pre-loading data from '$name', please wait… "
          ' ($rowCount records so far)',
        );
      }
    }

    if (isCancelled()) {
      onProgress('Reading data canceled!');
      return null;
    }
    onProgress('Finalizing pre-loaded data…');
    for (final header in indexedHeaders) {
      _checkIndexName(header);
    }
    onProgress('Reading data completed!');
    return table;
  }

  static final _sqlIdentifier = RegExp(
    r'^[A-Za-z_\u0080-￿][A-Za-z0-9_$\u0080-￿]*$',
  );

  /// Collect runs `CREATE INDEX <header>_idx ON ...` with the raw header,
  /// which SQLite rejects unless it is a plain identifier.
  static void _checkIndexName(String header) {
    final indexName = '${header.replaceFirst(RegExp(r'^[ \t\n\f\r]+'), '')}_idx';
    if (!_sqlIdentifier.hasMatch(indexName)) {
      throw ExternalDataException(
        'syntax error (code 1 SQLITE_ERROR): , while compiling: CREATE INDEX '
        '${header}_idx ON ${ExternalDataUtil.externalDataTableName} '
        '(${ExternalDataUtil.toSafeColumnName(header)});',
      );
    }
  }
}
