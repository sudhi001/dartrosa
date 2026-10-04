import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:logging/logging.dart';

final _log = Logger('dartrosa_external_data');

/// Helpers shared by the external data import, `pulldata()` and
/// `search()`.
///
/// Port of Collect's `org.odk.collect.android.dynamicpreload.ExternalDataUtil`
/// (except `populateExternalChoices`, which is in `select_choice_utils.dart`).
/// Collect's toasts for malformed `search()` appearances become log
/// warnings.
abstract final class ExternalDataUtil {
  /// The table holding a CSV's rows.
  static const externalDataTableName = 'externalData';

  /// The table holding import metadata (file name and MD5 hash).
  static const externalMetadataTableName = 'externalMetadata';

  /// The `REAL` column rows are sorted by: the CSV's `sortby` column, or
  /// the row number.
  static const sortColumnName = 'c_sortby';

  /// Metadata column: the imported CSV's file name.
  static const columnDatasetFilename = 'dataSetFilename';

  /// Metadata column: the imported CSV's MD5 hash.
  static const columnMd5Hash = 'md5Hash';

  /// Finds a `search(...)` call in an appearance.
  static final searchFunctionRegex = RegExp(r'search\(.+\)');

  static const _columnSeparator = ',';
  static const _fallbackColumnSeparator = ' ';

  /// The prefix of image choice texts.
  static const jrImagesPrefix = 'jr://images/';

  /// [toSafeColumnName], memoized in [cache].
  static String toSafeColumnNameCached(
    String columnName,
    Map<String, String> cache,
  ) => cache.putIfAbsent(columnName, () => toSafeColumnName(columnName));

  /// The SQL column name for the CSV column [columnName]: `c_` followed by
  /// the trimmed name with characters other than `[A-Za-z0-9_]` replaced by
  /// `_`, lower-cased (SCTO-567).
  static String toSafeColumnName(String columnName) =>
      'c_${javaTrim(columnName).replaceAll(RegExp('[^A-Za-z0-9_]'), '_').toLowerCase()}';

  /// The first two non-blank [columnNames] that have the same safe name,
  /// or `null` if there are none.
  static List<String>? findMatchingColumnsAfterSafeningNames(
    List<String> columnNames,
  ) {
    final map = <String, String>{};
    for (final columnName in columnNames) {
      if (javaTrim(columnName).isNotEmpty) {
        final safeColumn = toSafeColumnName(columnName);
        final existing = map[safeColumn];
        if (existing == null) {
          map[safeColumn] = columnName;
        } else {
          return [existing, columnName];
        }
      }
    }
    return null;
  }

  /// The `search()` call in [appearance], or `null` if there is none or it
  /// is malformed (then a warning is logged): it must be a function called
  /// `search` with 1, 4 or 6 arguments.
  static XPathFuncExpr? getSearchXPathExpression(String? appearance) {
    final trimmed = javaTrim(appearance ?? '');
    final match = searchFunctionRegex.firstMatch(trimmed);
    if (match == null) return null;
    final function = match.group(0)!;
    final XPathExpression expression;
    try {
      expression = parseXPath(function);
    } on XPathSyntaxException {
      _log.info('Syntax error in search() function: $trimmed');
      return null;
    }
    if (expression is! XPathFuncExpr) {
      _log.info(
        "Syntax error in search() function: '$function' was not evaluated "
        'as a function.',
      );
      return null;
    }
    if (expression.id.name.toLowerCase() != 'search') {
      _log.info(
        'Syntax error in search() function : Unrecognised function '
        "'${expression.id.name}'.",
      );
      return null;
    }
    final n = expression.args.length;
    if (n == 1 || n == 4 || n == 6) return expression;
    _log.info(
      'Syntax error in search() function: The function needs 1, 4 or 6 '
      'arguments.',
    );
    return null;
  }

  /// SQL column → CSV column for a `search()` choice: [valueColumn] first,
  /// then the comma-separated (or, failing that, space-separated)
  /// [displayColumns]. Repeated columns keep their first position.
  static Map<String, String> createMapWithDisplayingColumns(
    String valueColumn,
    String? displayColumns,
  ) {
    final value = javaTrim(valueColumn);
    final columns = <String, String>{toSafeColumnName(value): value};
    if (displayColumns != null && javaTrim(displayColumns).isNotEmpty) {
      for (final part in _splitTrimmed(
        javaTrim(displayColumns),
        _columnSeparator,
        _fallbackColumnSeparator,
      )) {
        columns[toSafeColumnName(part)] = part;
      }
    }
    return columns;
  }

  /// The safe names of the comma- (or space-) separated [columnString].
  static List<String> createListOfColumns(String columnString) => [
    for (final part in _splitTrimmed(
      columnString,
      _columnSeparator,
      _fallbackColumnSeparator,
    ))
      toSafeColumnName(part),
  ];

  static List<String> _splitTrimmed(
    String text,
    String separator,
    String fallbackSeparator,
  ) {
    var parts = _tokenize(text, separator);
    // SCTO-584: fall back to a space-separated list.
    if (parts.length == 1 && text.contains(fallbackSeparator)) {
      parts = _tokenize(text, fallbackSeparator);
    }
    return parts;
  }

  /// `StringTokenizer` with trimmed, non-empty tokens.
  static List<String> _tokenize(String text, String separator) => [
    for (final token in text.split(separator))
      if (javaTrim(token).isNotEmpty) javaTrim(token),
  ];

  /// Whether [row] has a non-blank value.
  static bool containsAnyData(List<String?>? row) =>
      row != null && row.any((v) => v != null && javaTrim(v).isNotEmpty);

  /// [row] padded with `''` to the length of [headerRow] (SCTO-894).
  static List<String> fillUpNullValues(
    List<String?> row,
    List<String> headerRow,
  ) => [
    for (var i = 0; i < headerRow.length; i++)
      i < row.length ? row[i] ?? '' : '',
  ];

  /// [value], or `''` for `null`.
  static String nullSafe(String? value) => value ?? '';

  /// Whether the trimmed [value] parses as a Java `int`.
  static bool isAnInteger(String? value) =>
      value != null && javaParseInt(javaTrim(value)) != null;
}
