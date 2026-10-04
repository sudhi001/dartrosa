import 'save_to.dart';

/// The entity information of a parsed form, stored in its
/// `FormDef.extras` under `EntityFormExtra`.
///
/// Port of `org.odk.collect.entities.javarosa.parse.EntityFormExtra`
/// (without `Externalizable`; see [SaveTo]).
final class EntityFormExtra {
  /// Creates the extra.
  EntityFormExtra([List<SaveTo> saveTos = const []])
    : saveTos = List.unmodifiable(saveTos);

  /// The form's `saveto` bindings.
  final List<SaveTo> saveTos;
}
