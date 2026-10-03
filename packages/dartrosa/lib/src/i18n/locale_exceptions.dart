/// Exceptions of the localization layer.
///
/// Ports of `UnregisteredLocaleException`, `NoLocalizedTextException`
/// (from `org.javarosa.core.util`) and `LocaleTextException`.
library;

/// A locale that isn't defined was used (or none was set).
final class UnregisteredLocaleException implements Exception {
  /// Creates the exception with [message].
  const UnregisteredLocaleException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// No text exists for a text id, or keys are missing from the default
/// locale.
final class NoLocalizedTextException implements Exception {
  /// Creates the exception for [missingKeyNames] in [localeMissingKey].
  const NoLocalizedTextException(
    this.message,
    this.missingKeyNames,
    this.localeMissingKey,
  );

  /// What went wrong.
  final String message;

  /// The text id(s) that were not found (comma-separated).
  final String missingKeyNames;

  /// The locale in which they were missing.
  final String? localeMissingKey;

  @override
  String toString() => message;
}

/// Localized application text could not be produced.
final class LocaleTextException implements Exception {
  /// Creates the exception with [message].
  const LocaleTextException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}
