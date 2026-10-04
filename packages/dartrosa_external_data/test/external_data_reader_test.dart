// Port of Collect's ExternalDataReaderTest (SQLite database files become an
// ExternalDataRepository), plus DartRosa tests of the CSV import rules of
// ExternalSQLiteOpenHelper.onCreateNamed.
import 'dart:convert';

import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

const _csvName = 'simple-search-external-csv-fruits';
const _csvFileName = 'simple-search-external-csv-fruits.csv';

ExternalDataFile _file(String text, [String name = _csvFileName]) =>
    ExternalDataFile(name, utf8.encode(text));

ExternalDataTable _import(String text) =>
    ExternalDataReader.importFromCsv(_file(text))!;

List<List<String?>> _all(ExternalDataTable table) =>
    table.query(ExternalDataQuery(table.columns));

Matcher _importError(String reason) => throwsA(
  isA<ExternalDataException>().having((e) => e.message, 'message', reason),
);

void main() {
  group('ExternalDataReaderTest', () {
    late InMemoryExternalDataRepository repository;
    late ExternalDataFile csvFile;

    Map<String, ExternalDataFile?> externalDataMap() => {_csvName: csvFile};

    setUp(() {
      repository = InMemoryExternalDataRepository();
      csvFile = _file(media[_csvFileName]!);
    });

    test('doImport_createsDataAndMetadataTables', () async {
      await ExternalDataReader(repository).doImport(externalDataMap());

      expect(repository.table(_csvName), isNotNull);
      expect(
        await repository.importedMd5(_csvName, _csvFileName),
        csvFile.md5Hash,
      );
    });

    // There are multiple features that ingest CSV files so the original
    // file should not be modified (https://github.com/getodk/collect/issues/3335).
    test('doImport_doesNotModifyOriginalCsv', () async {
      final before = List.of(csvFile.bytes);
      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(csvFile.bytes, before);
    });

    test(
      'createAndPopulateMetadataTable_createsMetadataTableWithExpectedMd5Hash',
      () async {
        await ExternalDataReader(repository).doImport(externalDataMap());
        expect(
          await repository.importedMd5(_csvName, _csvFileName),
          md5Of(media[_csvFileName]!),
        );
      },
    );

    test('doImport_reimportsCsvIfDatabaseFileIsDeleted', () async {
      await ExternalDataReader(repository).doImport(externalDataMap());
      await repository.delete(_csvName);
      expect(repository.table(_csvName), isNull);

      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(repository.table(_csvName), isNotNull);
    });

    test('doImport_reimportsCsvIfMetadataTableIsMissing', () async {
      // A data set stored without matching metadata (as by prior versions).
      await repository.save(
        _csvName,
        ExternalDataTable(['c_name']),
        fileName: 'other.csv',
        md5: '',
      );
      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(
        await repository.importedMd5(_csvName, _csvFileName),
        csvFile.md5Hash,
      );
      expect(repository.table(_csvName)!.rowCount, 3);
    });

    test('doImport_reimportsCsvIfFileIsUpdated', () async {
      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(repository.table(_csvName)!.rowCount, 3);
      final originalHash = csvFile.md5Hash;
      expect(
        await repository.importedMd5(_csvName, _csvFileName),
        originalHash,
      );

      csvFile = _file('${media[_csvFileName]!}\ncherimoya,Cherimoya');
      expect(csvFile.md5Hash, isNot(originalHash));

      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(repository.table(_csvName)!.rowCount, 4);
      expect(
        await repository.importedMd5(_csvName, _csvFileName),
        csvFile.md5Hash,
      );
    });

    test('doImport_skipsImportIfFileNotUpdated', () async {
      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(repository.table(_csvName)!.rowCount, 3);

      // Purge the contents of the data table before reimporting.
      repository.table(_csvName)!.clear();

      await ExternalDataReader(repository).doImport(externalDataMap());
      expect(
        repository.table(_csvName)!.rowCount,
        0,
        reason: 'expected zero rows of data after reimporting unchanged file',
      );
    });
  });

  group('doImport', () {
    test('skips missing files', () async {
      final repository = InMemoryExternalDataRepository();
      expect(await ExternalDataReader(repository).doImport({'x': null}), true);
      expect(repository.table('x'), isNull);
    });

    test('stops and drops the data set when cancelled', () async {
      final repository = InMemoryExternalDataRepository();
      final completed = await ExternalDataReader(
        repository,
        isCancelled: () => true,
      ).doImport({'a': _file('k\n1'), 'b': _file('k\n1')});
      expect(completed, isFalse);
      expect(repository.table('a'), isNull);
      expect(repository.table('b'), isNull);
    });

    test('wraps errors with the file name', () async {
      expect(
        ExternalDataReader(
          InMemoryExternalDataRepository(),
        ).doImport({'a': _file('', 'a.csv')}),
        throwsA(
          isA<ExternalDataException>().having(
            (e) => e.message,
            'message',
            'Could not import data from a.csv. Reason: null',
          ),
        ),
      );
    });

    test('reports progress', () async {
      final messages = <String>[];
      final rows = [for (var i = 0; i < 100; i++) 'k$i'].join('\n');
      await ExternalDataReader(
        InMemoryExternalDataRepository(),
        onProgress: messages.add,
      ).doImport({'a': _file('k\n$rows', 'a.csv')});
      expect(messages, [
        "Pre-loading data from 'a.csv', please wait… ",
        "Pre-loading data from 'a.csv', please wait…  (100 records so far)",
        'Finalizing pre-loaded data…',
        'Reading data completed!',
      ]);
    });
  });

  group('importFromCsv', () {
    test('adds a row-number sort column', () {
      final table = _import('name_key,name\nmango,Mango\noranges,Oranges');
      expect(table.columns, ['c_name_key', 'c_name', 'c_sortby']);
      expect(_all(table), [
        ['mango', 'Mango', '1.0'],
        ['oranges', 'Oranges', '2.0'],
      ]);
    });

    test('uses a numeric sortby column', () {
      final table = _import('name,SortBy\nb, 2 \na,1e0');
      expect(table.columns, ['c_name', 'c_sortby']);
      expect(
        table.query(const ExternalDataQuery(['c_name'], orderBy: 'c_sortby')),
        [
          ['a'],
          ['b'],
        ],
      );
    });

    test('rejects non-numeric sortby values', () {
      expect(
        () => _import('name,sortby\na,'),
        _importError(
          'Your sortby column should contain only numeric values. '
          "Conflicting value was ''.",
        ),
      );
    });

    test('removes a byte order mark and skips blank header columns', () {
      final table = _import('﻿name, ,label\na,x,A');
      expect(table.columns, ['c_name', 'c_label', 'c_sortby']);
      expect(_all(table), [
        ['a', 'A', '1.0'],
      ]);
    });

    test('a blank first header column fails (invalid CREATE TABLE)', () {
      expect(
        () => _import(',name\nx,a'),
        _importError('near ",": syntax error (code 1 SQLITE_ERROR)'),
      );
    });

    test('skips blank rows, pads short ones and ignores extra values', () {
      final table = _import('a,b\n\n , \n1\n1,2,3');
      expect(_all(table), [
        ['1', '', '1.0'],
        ['1', '2', '2.0'],
      ]);
    });

    test('rejects files without data', () {
      expect(() => _import(' , '), _importError('The file contains no data!'));
    });

    test('rejects columns that collide once made safe', () {
      expect(
        () => _import('a b,a_b\n1,2'),
        _importError('Columns [a b, a_b] match!'),
      );
    });

    test('_key columns must be SQL identifiers (Collect indexes them)', () {
      expect(_import(' name_key,x\na,b').rowCount, 1);
      expect(
        () => _import('my name_key,x\na,b'),
        throwsA(isA<ExternalDataException>()),
      );
      expect(
        () => _import('1_key,x\na,b'),
        throwsA(isA<ExternalDataException>()),
      );
    });

    test('returns null when cancelled', () {
      expect(
        ExternalDataReader.importFromCsv(
          _file('a\n1'),
          isCancelled: () => true,
        ),
        isNull,
      );
    });
  });
}

String md5Of(String text) => _file(text).md5Hash;
