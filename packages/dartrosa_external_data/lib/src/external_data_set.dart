import 'external_data_exception.dart';
import 'external_data_util.dart';

/// One imported CSV file, queried by `pulldata()` and `search()`.
///
/// Collect stores each CSV in an SQLite database (`<name>.db`, table
/// `externalData`); this interface is that table's query surface, so an
/// app can back it with SQLite (pass [ExternalDataQuery.sql] and
/// [ExternalDataQuery.selectionArgs] to the database) while
/// [ExternalDataTable] keeps it in memory. Queries are synchronous because
/// XPath functions are.
abstract interface class ExternalDataSet {
  /// The rows matching [query], each with the values of
  /// [ExternalDataQuery.columns] as text (`null` for SQL `NULL`). Throws
  /// [ExternalDataQueryException] for an unknown column.
  List<List<String?>> query(ExternalDataQuery query);
}

/// A `SELECT` on the `externalData` table, as Collect's function handlers
/// build it with `SQLiteDatabase.query`.
final class ExternalDataQuery {
  /// Selects [columns] (safe column names) of the rows matching [where],
  /// ordered by the column [orderBy] if given.
  const ExternalDataQuery(this.columns, {this.where, this.orderBy});

  /// The safe column names to return, in order (may repeat).
  final List<String> columns;

  /// The row filter, if any.
  final ExternalDataCondition? where;

  /// The column to sort by (ascending), if any.
  final String? orderBy;

  /// The SQL Android's `SQLiteQueryBuilder` builds for this query, with
  /// `?` placeholders for [selectionArgs].
  String get sql =>
      'SELECT ${columns.join(', ')} FROM ${ExternalDataUtil.externalDataTableName}'
      '${where == null ? '' : ' WHERE ${where!.selection}'}'
      '${orderBy == null ? '' : ' ORDER BY $orderBy'}';

  /// The values bound to the `?` placeholders of [sql].
  List<String> get selectionArgs => where?.args ?? const [];
}

/// A row filter: one of the `WHERE` clauses Collect's handlers build.
sealed class ExternalDataCondition {
  const ExternalDataCondition();

  /// The clause as Collect writes it, with `?` placeholders.
  String get selection;

  /// The values bound to the placeholders.
  List<String> get args;

  /// The columns the clause reads.
  Iterable<String> get columns;
}

/// `<column>=?`: the column equals [value] (case-insensitively for ASCII
/// letters, as Collect's columns are `COLLATE NOCASE`).
final class ColumnEquals extends ExternalDataCondition {
  /// Creates the condition. [trailingSpace] reproduces the `"=? "` spelling
  /// of `search()` filters (`pulldata()` writes `"=?"`).
  const ColumnEquals(this.column, this.value, {this.trailingSpace = false});

  /// The safe column name.
  final String column;

  /// The value to compare with.
  final String value;

  /// Whether [selection] ends with a space.
  final bool trailingSpace;

  @override
  String get selection => '$column=?${trailingSpace ? ' ' : ''}';

  @override
  List<String> get args => [value];

  @override
  Iterable<String> get columns => [column];
}

/// `<c1> LIKE ?  OR <c2> LIKE ? ...`: any of [likeColumns] matches its
/// SQL `LIKE` pattern in [patterns] (`%` and `_` wildcards, ASCII
/// case-insensitive).
final class ColumnsLike extends ExternalDataCondition {
  /// Creates the condition; [patterns] has one pattern per column.
  ColumnsLike(this.likeColumns, this.patterns)
    : assert(likeColumns.length == patterns.length, 'one pattern per column');

  /// The safe column names.
  final List<String> likeColumns;

  /// The `LIKE` patterns, one per column.
  final List<String> patterns;

  @override
  String get selection =>
      [for (final column in likeColumns) '$column LIKE ? '].join(' OR ');

  @override
  List<String> get args => patterns;

  @override
  Iterable<String> get columns => likeColumns;
}

/// `( <like> ) AND <equals>`: a `search()` with both a query and a filter.
final class LikeAndEquals extends ExternalDataCondition {
  /// Creates the condition.
  const LikeAndEquals(this.like, this.equals);

  /// The search part.
  final ColumnsLike like;

  /// The filter part.
  final ColumnEquals equals;

  @override
  String get selection => '( ${like.selection} ) AND ${equals.selection}';

  @override
  List<String> get args => [...like.args, ...equals.args];

  @override
  Iterable<String> get columns => [...like.columns, ...equals.columns];
}

/// An in-memory `externalData` table with SQLite's semantics for the
/// queries Collect makes.
///
/// Replaces Collect's per-CSV SQLite database. Every column is text
/// compared with `COLLATE NOCASE`, except [ExternalDataUtil.sortColumnName],
/// a `REAL` column. Rows keep insertion (rowid) order.
final class ExternalDataTable implements ExternalDataSet {
  /// Creates an empty table with the safe column names [columns].
  ExternalDataTable(Iterable<String> columns)
    : columns = List.unmodifiable(columns);

  /// The safe column names, in table order.
  final List<String> columns;

  final List<List<Object?>> _rows = [];

  /// The number of rows.
  int get rowCount => _rows.length;

  /// Inserts a row; [values] maps column names to a `String`, or for the
  /// `REAL` sort column a `double` (`NaN` is stored as `NULL`, as SQLite
  /// does). Missing columns are `NULL`.
  void insert(Map<String, Object?> values) {
    for (final column in values.keys) {
      if (!columns.contains(column)) {
        throw ExternalDataQueryException(
          'table ${ExternalDataUtil.externalDataTableName} has no column '
          'named $column',
        );
      }
    }
    _rows.add([
      for (final column in columns)
        switch (values[column]) {
          final double d when d.isNaN => null,
          final value => value,
        },
    ]);
  }

  /// Removes every row.
  void clear() => _rows.clear();

  @override
  List<List<String?>> query(ExternalDataQuery query) {
    int indexOf(String column) {
      final index = columns.indexOf(column);
      if (index == -1) {
        throw ExternalDataQueryException(
          'no such column: $column (code 1 SQLITE_ERROR): , while compiling: '
          '${query.sql}',
        );
      }
      return index;
    }

    final selected = [for (final c in query.columns) indexOf(c)];
    final where = query.where;
    if (where != null) where.columns.forEach(indexOf);
    final orderBy = query.orderBy == null ? null : indexOf(query.orderBy!);

    final matching = [
      for (final row in _rows)
        if (where == null || _matches(where, row, indexOf)) row,
    ];
    if (orderBy != null) {
      final positions = {
        for (var i = 0; i < matching.length; i++) matching[i]: i,
      };
      matching.sort((a, b) {
        final byValue = _compareValues(a[orderBy], b[orderBy]);
        return byValue != 0 ? byValue : positions[a]! - positions[b]!;
      });
    }
    return [
      for (final row in matching) [for (final i in selected) _asText(row[i])],
    ];
  }

  bool _matches(
    ExternalDataCondition condition,
    List<Object?> row,
    int Function(String) indexOf,
  ) => switch (condition) {
    ColumnEquals(:final column, :final value) => _equals(
      row[indexOf(column)],
      value,
    ),
    ColumnsLike(:final likeColumns, :final patterns) => _anyLike(
      likeColumns,
      patterns,
      row,
      indexOf,
    ),
    LikeAndEquals(:final like, :final equals) =>
      _matches(like, row, indexOf) && _matches(equals, row, indexOf),
  };

  /// Whether any of [likeColumns] of [row] matches its pattern in
  /// [patterns].
  static bool _anyLike(
    List<String> likeColumns,
    List<String> patterns,
    List<Object?> row,
    int Function(String) indexOf,
  ) {
    for (var i = 0; i < likeColumns.length; i++) {
      if (_like(patterns[i], _asText(row[indexOf(likeColumns[i])]))) {
        return true;
      }
    }
    return false;
  }

  /// `column = ?` with a text argument: `NOCASE` for text, numeric
  /// affinity for the `REAL` column.
  static bool _equals(Object? stored, String value) => switch (stored) {
    null => false,
    final String s => _asciiLower(s) == _asciiLower(value),
    final double d => _sqliteNumber(value) == d,
    _ => false,
  };

  static final _numericText = RegExp(
    r'^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\s*$',
  );

  /// The number SQLite's numeric affinity makes of [text], if any.
  static double? _sqliteNumber(String text) =>
      _numericText.hasMatch(text) ? double.parse(text.trim()) : null;

  /// SQLite's sort order: `NULL`s, then numbers, then text (`NOCASE`).
  static int _compareValues(Object? a, Object? b) {
    int rank(Object? v) => v == null ? 0 : (v is double ? 1 : 2);
    final byRank = rank(a) - rank(b);
    if (byRank != 0) return byRank;
    return switch ((a, b)) {
      (final double x, final double y) => x.compareTo(y),
      (final String x, final String y) => _asciiLower(
        x,
      ).compareTo(_asciiLower(y)),
      _ => 0,
    };
  }

  static String? _asText(Object? value) => switch (value) {
    null => null,
    final double d => sqliteRealToText(d),
    _ => value as String,
  };

  /// SQLite's `NOCASE` folding: ASCII letters only.
  static String _asciiLower(String s) {
    final units = s.codeUnits;
    if (!units.any((c) => c >= 0x41 && c <= 0x5A)) return s;
    return String.fromCharCodes([
      for (final c in units) c >= 0x41 && c <= 0x5A ? c + 0x20 : c,
    ]);
  }

  static int _foldRune(int c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c;

  /// SQLite's `LIKE` (no `ESCAPE`, `case_sensitive_like` off): `%` matches
  /// any run of characters, `_` one character; ASCII letters match
  /// case-insensitively. `NULL` never matches.
  static bool _like(String pattern, String? value) {
    if (value == null) return false;
    final p = pattern.runes.toList();
    final v = value.runes.toList();
    // Classic wildcard matching with backtracking to the last '%'.
    var pi = 0, vi = 0, starP = -1, starV = 0;
    while (vi < v.length) {
      if (pi < p.length &&
          p[pi] != 0x25 &&
          (p[pi] == 0x5F || _foldRune(p[pi]) == _foldRune(v[vi]))) {
        pi++;
        vi++;
      } else if (pi < p.length && p[pi] == 0x25) {
        starP = pi++;
        starV = vi;
      } else if (starP != -1) {
        pi = starP + 1;
        vi = ++starV;
      } else {
        return false;
      }
    }
    while (pi < p.length && p[pi] == 0x25) {
      pi++;
    }
    return pi == p.length;
  }
}

/// SQLite's text for a `REAL` value (`printf("%!.15g")`): `1.0`, `2.5`,
/// `1.0e+20`.
String sqliteRealToText(double value) {
  if (value.isInfinite) return value < 0 ? '-Inf' : 'Inf';
  if (value == 0) return value.isNegative ? '-0.0' : '0.0';
  final exponential = value.toStringAsExponential(14);
  final ePos = exponential.indexOf('e');
  final exponent = int.parse(exponential.substring(ePos + 1));
  String stripZeros(String digits) {
    if (!digits.contains('.')) return '$digits.0';
    var s = digits.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = '${s}0';
    return s;
  }

  if (exponent < -4 || exponent >= 15) {
    final mantissa = stripZeros(exponential.substring(0, ePos));
    final sign = exponent < 0 ? '-' : '+';
    return '${mantissa}e$sign${exponent.abs().toString().padLeft(2, '0')}';
  }
  return stripZeros(value.toStringAsFixed(14 - exponent));
}
