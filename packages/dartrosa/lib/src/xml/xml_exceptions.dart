/// Exceptions of JavaRosa's XML parsing layer (`org.javarosa.xml.util`).
library;

/// The XML doesn't have the structure the parser expects.
///
/// Port of `org.javarosa.xml.util.InvalidStructureException`.
final class InvalidStructureException implements Exception {
  /// Creates the exception with [message] as is.
  const InvalidStructureException(this.message);

  /// `Invalid XML Structure(position): message`, as JavaRosa formats errors
  /// reported with the parser's position description.
  InvalidStructureException.atPosition(String message, String position)
    : message = 'Invalid XML Structure($position): $message';

  /// `Invalid XML Structure in document file(position): message`.
  InvalidStructureException.inDocument(
    String message,
    String file,
    String position,
  ) : message = 'Invalid XML Structure in document $file($position): $message';

  /// A message naming the offending tag, as JavaRosa's
  /// `readableInvalidStructureException`:
  /// `message. Source: <prefix:name> tag in namespace: uri` or
  /// `message. Source: <name>`.
  InvalidStructureException.readable(
    String message, {
    required String name,
    String? prefix,
    String? namespace,
  }) : message = prefix != null
           ? '$message. Source: <$prefix:$name> tag in namespace: $namespace'
           : '$message. Source: <$name>';

  /// Description of the problem.
  final String message;

  @override
  String toString() => message;
}

/// A document needs a capability or version this engine doesn't have.
///
/// Port of `org.javarosa.xml.util.UnfullfilledRequirementsException`.
final class UnfullfilledRequirementsException implements Exception {
  /// Creates the exception.
  const UnfullfilledRequirementsException(
    this.message,
    this.severity, {
    this.requirementCode = -1,
    this.requiredMajor = -1,
    this.requiredMinor = -1,
    this.availableMajor = -1,
    this.availableMinor = -1,
    this.isDuplicateException = false,
  });

  /// Description of the problem.
  final String message;

  /// How serious the problem is (application-defined code).
  final int severity;

  /// Which requirement failed (application-defined code), or -1.
  final int requirementCode;

  /// Required major version, or -1.
  final int requiredMajor;

  /// Required minor version, or -1.
  final int requiredMinor;

  /// Available major version, or -1.
  final int availableMajor;

  /// Available minor version, or -1.
  final int availableMinor;

  /// Whether this reports a duplicate.
  final bool isDuplicateException;

  /// `major.minor` of the required version.
  String get requiredVersionString => '$requiredMajor.$requiredMinor';

  /// `major.minor` of the available version.
  String get availableVersionString => '$availableMajor.$availableMinor';

  @override
  String toString() => message;
}
