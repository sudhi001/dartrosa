import 'package:dartrosa/dartrosa.dart' show TreeReference;
import 'package:meta/meta.dart';

/// An `entities:saveto` bind: the form field at [reference] is saved to
/// the entity property [value] of the entity declared in the group at
/// [entityGroupReference].
///
/// Port of `org.odk.collect.entities.javarosa.parse.SaveTo` (without
/// `Externalizable`: DartRosa's `FormDefCodec` re-parses forms, which
/// rebuilds it).
@immutable
final class SaveTo {
  /// Creates the binding.
  const SaveTo(this.reference, this.value, this.entityGroupReference);

  /// The (generic) reference of the saved field.
  final TreeReference reference;

  /// The entity property name.
  final String value;

  /// The generic reference of the group containing the `meta/entity`
  /// element the field belongs to.
  final TreeReference entityGroupReference;

  @override
  bool operator ==(Object other) =>
      other is SaveTo &&
      other.reference == reference &&
      other.value == value &&
      other.entityGroupReference == entityGroupReference;

  @override
  int get hashCode => Object.hash(reference, value, entityGroupReference);

  @override
  String toString() => 'SaveTo($reference -> $value in $entityGroupReference)';
}
