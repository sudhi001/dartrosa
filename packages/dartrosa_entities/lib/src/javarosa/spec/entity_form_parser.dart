import 'package:dartrosa/dartrosa.dart' show TreeReference;
import 'package:dartrosa/javarosa.dart';

import 'entity_action.dart';
import 'form_entity_element.dart';

/// Reads `<entity>` elements from a form's main instance.
///
/// Port of `org.odk.collect.entities.javarosa.spec.EntityFormParser`.
abstract final class EntityFormParser {
  /// The `dataset` attribute of [entity].
  static String? parseDataset(TreeElement entity) =>
      entity.getAttributeValue(null, FormEntityElement.attributeDataset);

  /// The value of [entity]'s `<label>` as a string (`''` if missing).
  static String parseLabel(TreeElement entity) {
    final labelElement = entity.firstChild(FormEntityElement.elementLabel);
    return labelElement?.value?.uncast().string ?? '';
  }

  /// The `id` attribute (in no namespace) of [entity].
  static String? parseId(TreeElement entity) =>
      entity.getAttributeValue('', FormEntityElement.attributeId);

  /// The `<entity>` elements under [treeElement]: those in a `meta`
  /// child, at any depth outside `meta` groups and repeat templates.
  static List<TreeElement> getEntityElements(TreeElement treeElement) {
    final entityElements = <TreeElement>[];

    for (var i = 0; i < treeElement.numChildren; i++) {
      final childTreeElement = treeElement.childAt(i);
      if (childTreeElement.name == 'meta') {
        final entity = childTreeElement.firstChild(
          FormEntityElement.elementEntity,
        );
        if (entity != null) entityElements.add(entity);
      } else if (childTreeElement.hasChildren &&
          childTreeElement.multiplicity != TreeReference.indexTemplate) {
        entityElements.addAll(getEntityElements(childTreeElement));
      }
    }

    return entityElements;
  }

  /// Whether [treeElement] has `<entity>` elements (see
  /// [getEntityElements]).
  static bool hasEntityElement(TreeElement treeElement) =>
      getEntityElements(treeElement).isNotEmpty;

  /// The action [entity]'s `create` and `update` attributes ask for
  /// (XPath `boolean-from-string` values), or `null` for none.
  static EntityAction? parseAction(TreeElement entity) {
    final create = entity.getAttributeValue(
      null,
      FormEntityElement.attributeCreate,
    );
    final update = entity.getAttributeValue(
      null,
      FormEntityElement.attributeUpdate,
    );

    final shouldCreate = create != null && boolStr(create);
    final shouldUpdate = update != null && boolStr(update);

    if (shouldCreate && shouldUpdate) return EntityAction.upsert;
    if (shouldCreate) return EntityAction.create;
    if (shouldUpdate) return EntityAction.update;
    return null;
  }
}
