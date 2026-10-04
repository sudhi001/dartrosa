/// Port of `org.odk.collect.shared.Query`.
library;

import 'package:meta/meta.dart';

/// A filter on the entities of a list, built from an XPath predicate by
/// `XPathExpressionExt.toQuery` and run by an [EntitiesRepository]
/// implementation.
///
/// Port of `org.odk.collect.shared.Query`. Columns are entity fields:
/// `name` (the id), `label`, `__version` or a property name.
@immutable
sealed class Query {
  const Query();

  /// This query with every column renamed by [columnMapper]. Port of
  /// `Query.mapColumns`.
  Query mapColumns(String Function(String column) columnMapper) =>
      switch (this) {
        StringEqQuery(:final column, :final value) => StringEqQuery(
          columnMapper(column),
          value,
        ),
        StringNotEqQuery(:final column, :final value) => StringNotEqQuery(
          columnMapper(column),
          value,
        ),
        NumericEqQuery(:final column, :final value) => NumericEqQuery(
          columnMapper(column),
          value,
        ),
        NumericNotEqQuery(:final column, :final value) => NumericNotEqQuery(
          columnMapper(column),
          value,
        ),
        AndQuery(:final queryA, :final queryB) => AndQuery(
          queryA.mapColumns(columnMapper),
          queryB.mapColumns(columnMapper),
        ),
        OrQuery(:final queryA, :final queryB) => OrQuery(
          queryA.mapColumns(columnMapper),
          queryB.mapColumns(columnMapper),
        ),
      };
}

/// `column = value`, compared as strings. Port of `Query.StringEq`.
final class StringEqQuery extends Query {
  /// Creates the query.
  const StringEqQuery(this.column, this.value);

  /// The column.
  final String column;

  /// The value.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is StringEqQuery && other.column == column && other.value == value;

  @override
  int get hashCode => Object.hash(StringEqQuery, column, value);

  @override
  String toString() => 'StringEq(column=$column, value=$value)';
}

/// `column != value`, compared as strings. Port of `Query.StringNotEq`.
final class StringNotEqQuery extends Query {
  /// Creates the query.
  const StringNotEqQuery(this.column, this.value);

  /// The column.
  final String column;

  /// The value.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is StringNotEqQuery &&
      other.column == column &&
      other.value == value;

  @override
  int get hashCode => Object.hash(StringNotEqQuery, column, value);

  @override
  String toString() => 'StringNotEq(column=$column, value=$value)';
}

/// `column = value`, compared as numbers. Port of `Query.NumericEq`.
final class NumericEqQuery extends Query {
  /// Creates the query.
  const NumericEqQuery(this.column, this.value);

  /// The column.
  final String column;

  /// The value.
  final double value;

  @override
  bool operator ==(Object other) =>
      other is NumericEqQuery && other.column == column && other.value == value;

  @override
  int get hashCode => Object.hash(NumericEqQuery, column, value);

  @override
  String toString() => 'NumericEq(column=$column, value=$value)';
}

/// `column != value`, compared as numbers. Port of `Query.NumericNotEq`.
final class NumericNotEqQuery extends Query {
  /// Creates the query.
  const NumericNotEqQuery(this.column, this.value);

  /// The column.
  final String column;

  /// The value.
  final double value;

  @override
  bool operator ==(Object other) =>
      other is NumericNotEqQuery &&
      other.column == column &&
      other.value == value;

  @override
  int get hashCode => Object.hash(NumericNotEqQuery, column, value);

  @override
  String toString() => 'NumericNotEq(column=$column, value=$value)';
}

/// Both queries. Port of `Query.And`.
final class AndQuery extends Query {
  /// Creates the query.
  const AndQuery(this.queryA, this.queryB);

  /// The first query.
  final Query queryA;

  /// The second query.
  final Query queryB;

  @override
  bool operator ==(Object other) =>
      other is AndQuery && other.queryA == queryA && other.queryB == queryB;

  @override
  int get hashCode => Object.hash(AndQuery, queryA, queryB);

  @override
  String toString() => 'And(queryA=$queryA, queryB=$queryB)';
}

/// Either query. Port of `Query.Or`.
final class OrQuery extends Query {
  /// Creates the query.
  const OrQuery(this.queryA, this.queryB);

  /// The first query.
  final Query queryA;

  /// The second query.
  final Query queryB;

  @override
  bool operator ==(Object other) =>
      other is OrQuery && other.queryA == queryA && other.queryB == queryB;

  @override
  int get hashCode => Object.hash(OrQuery, queryA, queryB);

  @override
  String toString() => 'Or(queryA=$queryA, queryB=$queryB)';
}
