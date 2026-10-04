/// An entity form can't be parsed. Port of JavaRosa's
/// `XFormParser.ParseException` (which DartRosa's parser doesn't
/// otherwise need), thrown by `EntityFormParseProcessor`.
sealed class EntityFormParseException implements Exception {
  const EntityFormParseException();

  /// What went wrong.
  String get message;

  @override
  String toString() => message;
}

/// A required model attribute is missing (an entity form without
/// `entities-version`). Port of `XFormParser.MissingModelAttributeException`.
final class MissingModelAttributeException extends EntityFormParseException {
  /// Creates the exception for attribute [name] in [namespace].
  const MissingModelAttributeException(this.namespace, this.name);

  /// The attribute's namespace URI.
  final String namespace;

  /// The attribute name.
  final String name;

  @override
  String get message => 'Missing model attribute $namespace:$name';
}

/// The form's `entities-version` is not one Collect supports.
///
/// Port of
/// `org.odk.collect.entities.javarosa.spec.UnrecognizedEntityVersionException`.
final class UnrecognizedEntityVersionException
    extends EntityFormParseException {
  /// Creates the exception for [entityVersion].
  const UnrecognizedEntityVersionException(this.entityVersion);

  /// The unsupported version.
  final String entityVersion;

  @override
  String get message => 'Unrecognized entities version: $entityVersion';
}
