import 'package:dartrosa/javarosa.dart';
import 'package:logging/logging.dart';

import 'external_data_exception.dart';
import 'external_data_handler.dart';
import 'external_data_set.dart';
import 'external_data_util.dart';

final _log = Logger('dartrosa_external_data');

/// `pulldata('csv-name', 'column', 'key-column', key)`: the value of
/// `column` in the first row of the CSV whose `key-column` equals `key`
/// (case-insensitively for ASCII letters), or `''`.
///
/// Port of Collect's `ExternalDataHandlerPull`.
final class ExternalDataHandlerPull extends ExternalDataHandler {
  /// Creates the handler.
  ExternalDataHandlerPull(super.externalDataManager);

  /// The function name.
  static const handlerName = 'pulldata';

  @override
  String get name => handlerName;

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    if (args.length != 4) {
      _log.severe(
        '4 arguments are needed to evaluate the $handlerName '
        'function',
      );
      return '';
    }
    final dataSetName = ExternalDataHandler.normalize(toXPathString(args[0]));
    final queriedColumn = toXPathString(args[1]);
    final referenceColumn = toXPathString(args[2]);
    final referenceValue = toXPathString(args[3]);

    final db = externalDataManager.getDatabase(dataSetName);
    if (db == null) return '';
    try {
      final rows = db.query(
        ExternalDataQuery(
          [ExternalDataUtil.toSafeColumnName(queriedColumn)],
          where: ColumnEquals(
            ExternalDataUtil.toSafeColumnName(referenceColumn),
            referenceValue,
          ),
        ),
      );
      if (rows.isNotEmpty) return ExternalDataUtil.nullSafe(rows.first[0]);
      _log.info(
        'Could not find a value in $queriedColumn where the column '
        '$referenceColumn has the value $referenceValue',
      );
      return '';
    } on ExternalDataQueryException catch (e) {
      _log.info(e.message);
      return '';
    }
  }
}
