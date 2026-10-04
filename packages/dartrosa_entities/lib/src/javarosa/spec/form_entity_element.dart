/// Element and attribute names of a form's `<entity>` element.
///
/// Port of `org.odk.collect.entities.javarosa.spec.FormEntityElement`.
abstract final class FormEntityElement {
  /// The `<entity>` element (in a `meta` group).
  static const elementEntity = 'entity';

  /// The `<label>` child.
  static const elementLabel = 'label';

  /// The list (dataset) name.
  static const attributeDataset = 'dataset';

  /// The entity id.
  static const attributeId = 'id';

  /// The entity version an update is based on.
  static const attributeBaseVersion = 'baseVersion';

  /// Whether to create the entity.
  static const attributeCreate = 'create';

  /// Whether to update the entity.
  static const attributeUpdate = 'update';
}
