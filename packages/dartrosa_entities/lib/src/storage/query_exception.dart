/// A [Query] can't be run, e.g. because it names a column the list
/// doesn't have.
///
/// Port of `org.odk.collect.entities.storage.QueryException`.
final class QueryException implements Exception {
  /// Creates the exception.
  const QueryException(this.message);

  /// What went wrong.
  final String? message;

  @override
  String toString() => 'QueryException: $message';
}
