// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalDataHandlerSearch), Copyright (C) 2014
//  University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:logging/logging.dart';

import 'external_data_exception.dart';
import 'external_data_handler.dart';
import 'external_data_search_type.dart';
import 'external_data_set.dart';
import 'external_data_util.dart';
import 'external_select_choice.dart';

final _log = Logger('dartrosa_external_data');

/// `search('csv-name' [, 'type', 'columns', value [, 'filter-column',
/// filter-value]])` in a select's appearance: the select's choices, one per
/// distinct value of the CSV's [valueColumn], labelled with
/// [displayColumns], in `sortby` order.
///
/// Port of Collect's `ExternalDataHandlerSearch`. One handler is created
/// per configuration choice (see `populateExternalChoices`); [eval]
/// returns a `List<SelectChoice>`.
final class ExternalDataHandlerSearch extends ExternalDataHandler {
  /// Creates the handler for one configuration choice.
  ExternalDataHandlerSearch(
    super.externalDataManager,
    this.displayColumns,
    this.valueColumn,
    this.imageColumn,
  );

  /// The function name.
  static const handlerName = 'search';

  /// The CSV columns making the label (the choice's label).
  final String? displayColumns;

  /// The CSV column holding the value (the choice's value).
  final String valueColumn;

  /// The CSV column naming an image (the choice's image text), if any.
  final String? imageColumn;

  @override
  String get name => handlerName;

  @override
  List<SelectChoice> eval(List<Object> args, EvaluationContext context) {
    if (args.length != 1 && args.length != 4 && args.length != 6) {
      throw ExternalDataException(
        'Syntax error in search() function: The function needs 1, 4 or 6 '
        'arguments.',
      );
    }
    String? searchType;
    String? queriedColumnsParam;
    List<String>? queriedColumns;
    String? queriedValue;
    if (args.length >= 4) {
      searchType = toXPathString(args[1]);
      queriedColumnsParam = toXPathString(args[2]);
      queriedValue = toXPathString(args[3]);
    }
    final externalDataSearchType = ExternalDataSearchType.getByKeyword(
      searchType,
      ExternalDataSearchType.contains,
    );
    var searchRows = false;
    var useFilter = false;
    if (queriedColumnsParam != null &&
        javaTrim(queriedColumnsParam).isNotEmpty) {
      searchRows = true;
      queriedColumns = ExternalDataUtil.createListOfColumns(
        queriedColumnsParam,
      );
    }
    String? filterColumn;
    String? filterValue;
    if (args.length == 6) {
      filterColumn = toXPathString(args[4]);
      filterValue = toXPathString(args[5]);
      useFilter = true;
    }
    final dataSetName = ExternalDataHandler.normalize(toXPathString(args[0]));

    final selectColumnMap = ExternalDataUtil.createMapWithDisplayingColumns(
      valueColumn,
      displayColumns,
    );
    final columnsToFetch = [...selectColumnMap.keys];
    String? safeImageColumn;
    final image = imageColumn;
    if (image != null && javaTrim(image).isNotEmpty) {
      safeImageColumn = ExternalDataUtil.toSafeColumnName(image);
      columnsToFetch.add(safeImageColumn);
    }

    ColumnsLike like() => ColumnsLike(
      queriedColumns!,
      externalDataSearchType.constructLikeArguments(
        queriedValue!,
        queriedColumns.length,
      ),
    );
    ColumnEquals filter() => ColumnEquals(
      ExternalDataUtil.toSafeColumnName(filterColumn!),
      filterValue!,
      trailingSpace: true,
    );
    final where = searchRows && useFilter
        ? LikeAndEquals(like(), filter())
        : searchRows
        ? like()
        : useFilter
        ? filter()
        : null;

    final query = ExternalDataQuery(
      columnsToFetch,
      where: where,
      orderBy: ExternalDataUtil.sortColumnName,
    );
    final db = externalDataManager.getDatabase(dataSetName);
    if (db == null) {
      throw ExternalDataQueryException(
        'no such table: ${ExternalDataUtil.externalDataTableName} (code 1 '
        'SQLITE_ERROR): , while compiling: ${query.sql}',
      );
    }
    List<List<String?>> rows;
    try {
      rows = db.query(query);
    } on ExternalDataQueryException {
      _log.severe(
        'External data for $dataSetName has not been imported. Perhaps you '
        'forgot to include the $dataSetName.csv file with your form?',
      );
      rows = db.query(ExternalDataQuery(columnsToFetch, where: where));
    }
    return createDynamicSelectChoices(
      rows,
      columnsToFetch,
      selectColumnMap,
      safeImageColumn,
    );
  }

  /// One choice per distinct value (the first column) of [rows], whose
  /// columns are [columnNames].
  List<SelectChoice> createDynamicSelectChoices(
    List<List<String?>> rows,
    List<String> columnNames,
    Map<String, String> selectColumnMap,
    String? safeImageColumn,
  ) {
    final columnsToExcludeFromLabels = [?safeImageColumn];
    final selectChoices = <SelectChoice>[];
    var index = 0;
    final uniqueValues = <String?>{};
    for (final row in rows) {
      // The value is always the first column.
      final value = row[0];
      if (!uniqueValues.add(value)) continue;
      final label = buildLabel(
        row,
        columnNames,
        selectColumnMap,
        columnsToExcludeFromLabels,
      );
      final v = value ?? 'null';
      final selectChoice = ExternalSelectChoice(
        javaTrim(label).isEmpty ? v : label,
        v,
      )..index = index;
      if (safeImageColumn != null && javaTrim(safeImageColumn).isNotEmpty) {
        final image = row[columnNames.indexOf(safeImageColumn)];
        if (image != null && javaTrim(image).isNotEmpty) {
          selectChoice.image = '${ExternalDataUtil.jrImagesPrefix}$image';
        }
      }
      selectChoices.add(selectChoice);
      index++;
    }
    return selectChoices;
  }

  /// The label from the display columns of [row]: `col1value`,
  /// `col1value (col2name: col2value)`, `col1value (col2name: col2value)
  /// (col3name: col3value)`.
  String buildLabel(
    List<String?> row,
    List<String> columnNames,
    Map<String, String> selectColumnMap,
    List<String> columnsToExcludeFromLabels,
  ) {
    final sb = StringBuffer();
    // Start at 1: 0 is the value column.
    for (var columnIndex = 1; columnIndex < columnNames.length; columnIndex++) {
      final columnName = columnNames[columnIndex];
      if (columnsToExcludeFromLabels.contains(columnName)) continue;
      final value = row[columnIndex];
      if (columnIndex == 1) {
        sb.write(value);
        continue;
      }
      if (columnNames.length - columnsToExcludeFromLabels.length == 2) break;
      sb.write(' (${selectColumnMap[columnName]}: $value)');
    }
    return sb.toString();
  }
}
