import 'external_data_set.dart';

/// Where imported CSV data sets are kept between form loads.
///
/// Replaces the `<name>.db` SQLite files Collect writes next to the form's
/// media (`ExternalSQLiteOpenHelper`, its `externalMetadata` table and
/// `ExternalDataManagerImpl`). Implement it over SQLite to persist imports;
/// [InMemoryExternalDataRepository] keeps them in memory. Data set names
/// are compared case-insensitively (Collect's media folder is on Android's
/// case-insensitive shared storage).
abstract interface class ExternalDataRepository {
  /// The MD5 hash recorded when [dataSetName] was imported from the file
  /// [fileName], or `null` if it wasn't (no data or metadata table).
  /// Port of `ExternalSQLiteOpenHelper.getLastMd5Hash`.
  Future<String?> importedMd5(String dataSetName, String fileName);

  /// Stores [table] as [dataSetName], imported from [fileName] with hash
  /// [md5], replacing any previous import.
  Future<void> save(
    String dataSetName,
    ExternalDataTable table, {
    required String fileName,
    required String md5,
  });

  /// Deletes [dataSetName] (Collect deletes the `.db` file).
  Future<void> delete(String dataSetName);

  /// The data set [dataSetName] ready for synchronous queries, or `null`
  /// if it was never imported.
  Future<ExternalDataSet?> open(String dataSetName);
}

/// An [ExternalDataRepository] in memory.
final class InMemoryExternalDataRepository implements ExternalDataRepository {
  final Map<String, (ExternalDataTable, String, String)> _dataSets = {};

  @override
  Future<String?> importedMd5(String dataSetName, String fileName) async {
    final entry = _dataSets[dataSetName.toLowerCase()];
    return entry != null && entry.$2 == fileName ? entry.$3 : null;
  }

  @override
  Future<void> save(
    String dataSetName,
    ExternalDataTable table, {
    required String fileName,
    required String md5,
  }) async => _dataSets[dataSetName.toLowerCase()] = (table, fileName, md5);

  @override
  Future<void> delete(String dataSetName) async =>
      _dataSets.remove(dataSetName.toLowerCase());

  @override
  Future<ExternalDataSet?> open(String dataSetName) async =>
      _dataSets[dataSetName.toLowerCase()]?.$1;

  /// The stored table [dataSetName] (for tests), or `null`.
  ExternalDataTable? table(String dataSetName) =>
      _dataSets[dataSetName.toLowerCase()]?.$1;
}
