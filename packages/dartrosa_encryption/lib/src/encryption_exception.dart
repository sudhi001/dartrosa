/// Thrown when a form asks for encryption but the submission can't be
/// encrypted (no instance ID, invalid public key, ...).
///
/// Port of `org.odk.collect.android.exception.EncryptionException`.
final class EncryptionException implements Exception {
  /// Creates an exception with [message] and the underlying [cause], if any.
  const EncryptionException(this.message, [this.cause]);

  /// The (Collect) error message.
  final String message;

  /// The error that caused this one, if any.
  final Object? cause;

  @override
  String toString() => 'EncryptionException: $message';
}
