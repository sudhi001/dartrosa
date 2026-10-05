// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests of ExternalDataTable: the SQLite semantics of Collect's
// externalData table (NOCASE text columns, LIKE, the REAL c_sortby column).
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

void main() {
  late ExternalDataTable table;

  setUp(() {
    table = ExternalDataTable(['c_name', 'c_label', 'c_sortby'])
      ..insert({'c_name': 'b', 'c_label': 'Bee', 'c_sortby': 2.0})
      ..insert({'c_name': 'a', 'c_label': 'Ant_1', 'c_sortby': 1.0})
      ..insert({'c_name': 'B', 'c_label': 'Été', 'c_sortby': 2.0})
      ..insert({'c_name': 'n', 'c_label': 'NaN', 'c_sortby': double.nan});
  });

  List<List<String?>> q(ExternalDataCondition? where, {String? orderBy}) =>
      table.query(
        ExternalDataQuery(['c_name'], where: where, orderBy: orderBy),
      );

  test('= is case-insensitive for ASCII letters only', () {
    expect(q(const ColumnEquals('c_name', 'b')), [
      ['b'],
      ['B'],
    ]);
    expect(q(const ColumnEquals('c_label', 'éTÉ')), isEmpty);
    expect(q(const ColumnEquals('c_label', 'ÉTÉ')), isEmpty);
    expect(q(const ColumnEquals('c_label', 'été')), isEmpty);
    expect(q(const ColumnEquals('c_label', 'Été')), [
      ['B'],
    ]);
  });

  test('= on the REAL column compares numbers', () {
    expect(q(const ColumnEquals('c_sortby', ' 1 ')), [
      ['a'],
    ]);
    expect(q(const ColumnEquals('c_sortby', '1.0e0')), [
      ['a'],
    ]);
    expect(q(const ColumnEquals('c_sortby', 'one')), isEmpty);
  });

  test('LIKE wildcards and case', () {
    expect(q(ColumnsLike(['c_label'], ['%E%'])), [
      ['b'],
    ]);
    expect(q(ColumnsLike(['c_label'], ['ant_1'])), [
      ['a'],
    ]);
    expect(q(ColumnsLike(['c_label'], ['an__1'])), [
      ['a'],
    ]);
    expect(q(ColumnsLike(['c_label'], ['_té'])), [
      ['B'],
    ]);
    expect(q(ColumnsLike(['c_sortby'], ['2.0'])), [
      ['b'],
      ['B'],
    ]);
    expect(q(ColumnsLike(['c_name', 'c_label'], ['n', 'b%'])), [
      ['b'],
      ['n'],
    ]);
  });

  test('ORDER BY sorts NULLs first and keeps ties in row order', () {
    expect(q(null, orderBy: 'c_sortby'), [
      ['n'],
      ['a'],
      ['b'],
      ['B'],
    ]);
  });

  test('REAL values read as SQLite text', () {
    expect(table.query(const ExternalDataQuery(['c_sortby', 'c_name'])), [
      ['2.0', 'b'],
      ['1.0', 'a'],
      ['2.0', 'B'],
      [null, 'n'],
    ]);
    expect(sqliteRealToText(2.5), '2.5');
    expect(sqliteRealToText(100), '100.0');
    expect(sqliteRealToText(1e20), '1.0e+20');
    expect(sqliteRealToText(1.5e-7), '1.5e-07');
    expect(sqliteRealToText(0.1), '0.1');
    expect(sqliteRealToText(123456789012345678.0), '1.23456789012346e+17');
  });

  test('unknown columns fail like SQLite', () {
    expect(
      () => table.query(
        ExternalDataQuery([
          'c_name',
          'c_label',
        ], where: ColumnsLike(['c_wat'], ['%x%'])),
      ),
      throwsA(
        isA<ExternalDataQueryException>().having(
          (e) => e.message,
          'message',
          'no such column: c_wat (code 1 SQLITE_ERROR): , while compiling: '
              'SELECT c_name, c_label FROM externalData WHERE c_wat LIKE ? ',
        ),
      ),
    );
  });

  test('queries render the SQL Collect builds', () {
    final query = ExternalDataQuery(
      ['c_name', 'c_label'],
      where: LikeAndEquals(
        ColumnsLike(['c_a', 'c_b'], ['%x%', '%x%']),
        const ColumnEquals('c_type', 'fruit', trailingSpace: true),
      ),
      orderBy: 'c_sortby',
    );
    expect(
      query.sql,
      'SELECT c_name, c_label FROM externalData WHERE ( c_a LIKE ?  OR '
      'c_b LIKE ?  ) AND c_type=?  ORDER BY c_sortby',
    );
    expect(query.selectionArgs, ['%x%', '%x%', 'fruit']);
  });
}
