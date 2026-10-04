/// External data could not be imported or queried.
///
/// Port of Collect's `org.odk.collect.android.exception.ExternalDataException`.
class ExternalDataException implements Exception {
  /// Creates the exception with [message] and the underlying [cause].
  ExternalDataException(this.message, [this.cause]);

  /// What went wrong (Collect's English message).
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() => message;
}

/// A query used a column or table the data set doesn't have.
///
/// Stands in for the `SQLiteException` Collect's SQLite queries throw; the
/// [message] follows SQLite's (`no such column: c_wat (code 1
/// SQLITE_ERROR): , while compiling: SELECT ...`).
final class ExternalDataQueryException extends ExternalDataException {
  /// Creates the exception with [message].
  ExternalDataQueryException(super.message);
}

/// The CSV file backing a `search()` appearance is missing.
///
/// Port of the `FileNotFoundException` Collect's
/// `ExternalDataUtil.populateExternalChoices` throws (Collect shows it as
/// `File: <path> is missing.`).
final class ExternalDataFileMissingException implements Exception {
  /// Creates the exception for the missing file [path].
  ExternalDataFileMissingException(this.path);

  /// The missing file's media URI (e.g. `jr://file/fruits.csv`).
  final String path;

  @override
  String toString() => 'File: $path is missing.';
}

/// Importing external data was cancelled (see `ExternalDataPlugin`'s
/// `isCancelled`); like Collect's `FormLoaderTask`, the form isn't loaded.
final class ExternalDataImportCancelledException implements Exception {
  /// Creates the exception.
  const ExternalDataImportCancelledException();

  @override
  String toString() => 'Reading data canceled!';
}
