// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (FastExternalItemsetsRepository), Copyright
//  University of Washington, Nafundi and contributors; modified: translated to
//  Dart.
// SPDX-License-Identifier: Apache-2.0

/// An imported `itemsets.csv`: its column names (from the header) and
/// rows.
///
/// Stands for the per-CSV table Collect's `ItemsetDbAdapter.createTable`
/// creates (`addRow` fills it).
final class ItemsetTable {
  /// Creates a table. Rows may be shorter than [columns] (missing values
  /// are `null`, like SQL `NULL`).
  ItemsetTable(List<String> columns, List<List<String?>> rows)
    : columns = List.unmodifiable(columns),
      rows = List.unmodifiable([for (final row in rows) List.of(row)]);

  /// The column names, in header order (empty names were skipped).
  final List<String> columns;

  /// The rows, values in [columns] order.
  final List<List<String?>> rows;

  /// The position of [name] in [columns], ignoring case like SQLite
  /// identifiers and Android's `Cursor.getColumnIndex`; -1 when absent.
  int columnIndex(String name) {
    final lower = name.toLowerCase();
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].toLowerCase() == lower) return i;
    }
    return -1;
  }
}

/// Stores the imported `itemsets.csv` of forms, keyed by the CSV's path,
/// with the hash of the content they were imported from (so unchanged
/// files aren't imported again).
///
/// Port of Collect's `FastExternalItemsetsRepository` (whose only
/// operation is [deleteAllByCsvPath]) extended with the storage
/// operations Collect performs directly on `ItemsetDbAdapter` (the
/// `itemsets` bookkeeping table and the per-CSV tables). Apps may
/// persist it; [InMemoryFastExternalItemsetsRepository] serves tests and
/// apps that import on every load.
abstract interface class FastExternalItemsetsRepository {
  /// The hash of the content the CSV at [path] was imported from, or
  /// `null` if it wasn't (`ItemsetDbAdapter.getItemsets(path)`).
  Future<String?> getHash(String path);

  /// The table imported from the CSV at [path], if any.
  Future<ItemsetTable?> getTable(String path);

  /// Stores [table] imported from the CSV at [path] with content [hash],
  /// replacing any previous import.
  Future<void> save(String path, String hash, ItemsetTable table);

  /// Deletes the import of the CSV at [path] (e.g. when the form is
  /// deleted).
  Future<void> deleteAllByCsvPath(String path);
}

/// A [FastExternalItemsetsRepository] in memory.
final class InMemoryFastExternalItemsetsRepository
    implements FastExternalItemsetsRepository {
  /// Creates an empty repository.
  InMemoryFastExternalItemsetsRepository();

  final _entries = <String, (String, ItemsetTable)>{};

  /// The paths of the imported CSVs.
  Iterable<String> get paths => _entries.keys;

  @override
  Future<String?> getHash(String path) async => _entries[path]?.$1;

  @override
  Future<ItemsetTable?> getTable(String path) async => _entries[path]?.$2;

  @override
  Future<void> save(String path, String hash, ItemsetTable table) async =>
      _entries[path] = (hash, table);

  @override
  Future<void> deleteAllByCsvPath(String path) async => _entries.remove(path);
}
