/// A secondary-instance file (CSV, GeoJSON) is malformed.
///
/// Port of the `IOException`s JavaRosa's file instance parsers throw for
/// bad content; the message is JavaRosa's.
final class InstanceFormatException implements Exception {
  /// Creates the exception.
  const InstanceFormatException(this.message);

  /// Description of the problem.
  final String message;

  @override
  String toString() => message;
}
