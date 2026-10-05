// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (SelectChoiceUtils, ItemsetDao), Copyright 2018
//  Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'fast_external_itemsets_repository.dart';

/// The `itemsets.csv` of a form, attached to its extras when it is loaded
/// (see `FastExternalItemsetsPlugin`).
final class FastExternalItemsets {
  /// Creates the state of the CSV at [path]: whether the form has the file
  /// ([fileExists]) and the table imported from it (`null` when the import
  /// failed before creating it).
  const FastExternalItemsets(
    this.path, {
    required this.fileExists,
    required this.table,
  });

  /// The CSV's key in the repository.
  final String path;

  /// Whether the form's media has `itemsets.csv`.
  final bool fileExists;

  /// The imported table, if any.
  final ItemsetTable? table;
}

/// Thrown when a select uses a fast external itemset but the form has no
/// `itemsets.csv`.
///
/// Collect throws `FileNotFoundException` with the file's path.
final class ItemsetsFileNotFoundException implements Exception {
  /// Creates the exception for the CSV at [path].
  const ItemsetsFileNotFoundException(this.path);

  /// The missing CSV.
  final String path;

  @override
  String toString() => 'ItemsetsFileNotFoundException: $path';
}

/// Whether [prompt] is a select whose choices come from `itemsets.csv`: it
/// has a `query` attribute.
///
/// Port of `SelectChoiceUtils.isFastExternalItemsetUsed`.
bool isFastExternalItemsetUsed(FormEntryPrompt prompt) =>
    prompt.question.additionalAttribute(null, 'query') != null;

/// Reads the choices of a select with a `query` attribute from the form's
/// `itemsets.csv`.
///
/// The query looks like
/// `instance('cities')/root/item[state=/data/state and county=/data/county]`:
/// the rows whose `list_name` is `cities` and whose `state` and `county`
/// columns equal the values of the XPath expressions on the right. Each
/// row gives a choice valued by its `name` column and labelled by its
/// `label::<language>` column (in the form's current language) or else
/// its `label` column.
///
/// Port of Collect's `ItemsetDao`, querying an [ItemsetTable] in memory the
/// way Collect's SQL query over the imported table behaves.
final class ItemsetDao {
  /// Creates the DAO.
  const ItemsetDao();

  /// The choices of [prompt]. Throws [ItemsetsFileNotFoundException] when
  /// the form has no `itemsets.csv` and [XPathSyntaxException] for an
  /// invalid argument. (Collect returns `null` when an argument evaluates
  /// to Java `null`, which XPath evaluation never does.)
  List<SelectChoice> getItems(FormEntryPrompt prompt) {
    final nodesetString = _getNodesetString(prompt);
    final arguments = <String>[];
    final selection = _getSelectionAndPopulateArguments(
      _getQueryString(nodesetString),
      arguments,
    );
    final selectionArgs = _getSelectionArgs(arguments, nodesetString, prompt);
    return _getItemsFromTable(selection, selectionArgs, prompt.form);
  }

  /// The label of the item named [itemName] in [language] (or the `label`
  /// column), or `null` (no such item, or the form has no
  /// `itemsets.csv`).
  ///
  /// Port of `ItemsetDao.getItemLabel`, used to show answers in the
  /// hierarchy.
  String? getItemLabel(String itemName, FormDef form, String? language) {
    final itemsets = form.extras.get<FastExternalItemsets>();
    if (itemsets == null || !itemsets.fileExists) return null;
    final table = itemsets.table;
    // SQLiteException (no table, or no `name` column) -> null.
    if (table == null) return null;
    final nameColumn = table.columnIndex('name');
    if (nameColumn == -1) return null;
    String? itemLabel;
    for (final row in table.rows) {
      if (_valueAt(row, nameColumn) != itemName) continue;
      itemLabel = _valueAt(row, _labelColumn(table, language ?? ''));
    }
    return itemLabel;
  }

  String _getNodesetString(FormEntryPrompt prompt) =>
      // the format of the query should be something like this:
      // query="instance('cities')/root/item[state=/data/state and county=/data/county]"
      prompt.question.additionalAttribute(null, 'query')!;

  // isolate the string between the [ ] characters
  String _getQueryString(String nodesetStr) => nodesetStr.substring(
    nodesetStr.indexOf('[') + 1,
    nodesetStr.lastIndexOf(']'),
  );

  /// Parses the predicate like Collect, which builds the SQL selection
  /// `list_name=? and "col1"=? and "col2"=? or ...`.
  ///
  /// Can't just split on
  /// `and` or `or` because they have different behavior, so the loop
  /// breaks them off until there aren't any more (the spaces are included
  /// so that words like "land" don't match). Like Collect, an `and` is
  /// handled before an earlier `or`, and clauses that don't split into
  /// exactly two parts at `=` are dropped.
  _Selection _getSelectionAndPopulateArguments(
    String queryString,
    List<String> arguments,
  ) {
    final columns = <String>[];
    final connectors = <bool>[]; // true: and, false: or (after a column)
    final hasArguments = queryString.contains('=');
    var query = queryString;
    while (true) {
      final andIndex = query.indexOf(' and ');
      final orIndex = andIndex == -1 ? query.indexOf(' or ') : -1;
      if (andIndex == -1 && orIndex == -1) break;
      final isAnd = andIndex != -1;
      final index = isAnd ? andIndex : orIndex;
      final pair = _javaSplit(query.substring(0, index));
      if (pair.length == 2) {
        columns.add(pair[0].trim());
        connectors.add(isAnd);
        arguments.add(pair[1].trim());
      }
      // move string forward to after " and " / " or "
      query = query.substring(index + (isAnd ? 5 : 4));
    }
    // the last segment (or only segment if there are no 'and' or 'or'
    // clauses)
    final pair = _javaSplit(query);
    final lastIsValid = pair.length == 2;
    if (lastIsValid) {
      columns.add(pair[0].trim());
      arguments.add(pair[1].trim());
    }
    // A selection ending with " and " / " or " is an SQL syntax error.
    return _Selection(
      columns,
      connectors,
      isValid: !hasArguments || lastIsValid,
    );
  }

  /// Java's `String.split("=")` (trailing empty strings removed).
  static List<String> _javaSplit(String s) {
    final parts = s.split('=');
    while (parts.length > 1 && parts.last.isEmpty) {
      parts.removeLast();
    }
    if (parts.length == 1 && parts.single.isEmpty && s.isNotEmpty) {
      return const [];
    }
    return parts;
  }

  List<String> _getSelectionArgs(
    List<String> arguments,
    String nodesetStr,
    FormEntryPrompt prompt,
  ) {
    // parse out the list name, between the ''
    final listName = nodesetStr.substring(
      nodesetStr.indexOf("'") + 1,
      nodesetStr.lastIndexOf("'"),
    );
    final selectionArgs = <String>[listName];
    final form = prompt.form;
    // loop through the arguments, evaluate any expressions and build the
    // query arguments
    for (final argument in arguments) {
      final XPathExpression xpr;
      try {
        xpr = parseXPath(argument);
      } on XPathSyntaxException {
        throw XPathSyntaxException(argument);
      }
      final treeElement = form.mainInstance.resolveReference(
        prompt.index.reference!,
      )!;
      final ec = EvaluationContext.withContext(
        form.evaluationContext,
        treeElement.ref,
      );
      var value = xpr.eval(form.mainInstance, ec);
      if (value is XPathNodeset) value = value.valueAt(0);
      selectionArgs.add(_javaToString(value));
    }
    return selectionArgs;
  }

  /// Java's `Object.toString` of an XPath value.
  static String _javaToString(Object value) => switch (value) {
    final double d => javaDoubleToString(d),
    _ => '$value',
  };

  List<SelectChoice> _getItemsFromTable(
    _Selection selection,
    List<String> selectionArgs,
    FormDef form,
  ) {
    final itemsets = form.extras.get<FastExternalItemsets>();
    if (itemsets == null || !itemsets.fileExists) {
      throw ItemsetsFileNotFoundException(
        itemsets?.path ?? FastExternalItemsetsDefaults.mediaUri,
      );
    }
    final items = <SelectChoice>[];
    final table = itemsets.table;
    // An SQL error (no table, syntax error, no list_name column) leaves no
    // items (Collect catches the SQLiteException).
    if (table == null || !selection.isValid) return items;
    final listNameColumn = table.columnIndex('list_name');
    if (listNameColumn == -1) return items;
    final columnIndexes = [
      for (final column in selection.columns) table.columnIndex(column),
    ];
    // try to get the value associated with the label:lang string; if that
    // doesn't exist, then just use label
    final languages = form.localizer?.availableLocales ?? const [];
    final lang = languages.isNotEmpty ? form.localizer!.locale ?? '' : '';
    final labelColumn = _labelColumn(table, lang);
    final nameColumn = table.columnIndex('name');
    if (nameColumn == -1) {
      throw StateError("itemsets.csv has no 'name' column");
    }
    for (final row in table.rows) {
      if (!_matches(
        row,
        listNameColumn,
        selection,
        columnIndexes,
        selectionArgs,
      )) {
        continue;
      }
      final value = _valueAt(row, nameColumn);
      if (value == null) {
        throw StateError(
          'SelectChoice{id,innerText}:{null,${_valueAt(row, labelColumn)}}, '
          'has null Value!',
        );
      }
      items.add(
        SelectChoice(
          null,
          _valueAt(row, labelColumn),
          value,
          isLocalizable: false,
        )..index = items.length,
      );
    }
    return items;
  }

  /// SQL `list_name=? and c1=? <op> c2=? ...`, AND binding tighter than OR.
  /// `NULL = ?` is false. A quoted identifier naming no column is a string
  /// literal in SQLite (its legacy double-quoted string behavior), so the
  /// clause compares the column name itself with the argument.
  static bool _matches(
    List<String?> row,
    int listNameColumn,
    _Selection selection,
    List<int> columnIndexes,
    List<String> args,
  ) {
    bool clause(int i) {
      final column = columnIndexes[i];
      final value = column == -1 ? selection.columns[i] : _valueAt(row, column);
      return value != null && value == args[i + 1];
    }

    // list_name=? and <clause 0> ...
    var group = _valueAt(row, listNameColumn) == args[0];
    for (var i = 0; i < selection.columns.length; i++) {
      final joinedByAnd = i == 0 || selection.connectors[i - 1];
      if (joinedByAnd) {
        group = group && clause(i);
      } else {
        if (group) return true;
        group = clause(i);
      }
    }
    return group;
  }

  static int _labelColumn(ItemsetTable table, String language) {
    final langCol = table.columnIndex('label::$language');
    final column = langCol != -1 ? langCol : table.columnIndex('label');
    if (column == -1) {
      throw StateError("itemsets.csv has no 'label' column");
    }
    return column;
  }

  static String? _valueAt(List<String?> row, int column) =>
      column < row.length ? row[column] : null;
}

/// Defaults of fast external itemsets.
abstract final class FastExternalItemsetsDefaults {
  /// The URI the form's `itemsets.csv` is read from.
  static const mediaUri = 'jr://file/itemsets.csv';
}

final class _Selection {
  const _Selection(this.columns, this.connectors, {required this.isValid});

  final List<String> columns;
  final List<bool> connectors;
  final bool isValid;
}
