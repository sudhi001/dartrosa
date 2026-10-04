import 'package:dartrosa/dartrosa.dart' show TreeReference;
import 'package:dartrosa/javarosa.dart';

import '../../storage/entity.dart';
import '../parse/entity_form_extra.dart';
import '../parse/save_to.dart';
import '../spec/entity_action.dart';
import '../spec/entity_form_parser.dart';
import 'entities_extra.dart';
import 'form_entity.dart';

/// When an entity form is finalized, reads its entities (action, dataset,
/// id, label and the relevant `saveto` values) into an [EntitiesExtra]
/// stored in the model's `extras`.
///
/// Port of
/// `org.odk.collect.entities.javarosa.finalization.EntityFormFinalizationProcessor`.
/// Forms without an [EntityFormExtra] (not parsed with
/// `EntityFormParseProcessor`, or not using local entities) get no
/// [EntitiesExtra].
final class EntityFormFinalizationProcessor
    implements FormEntryFinalizationProcessor {
  /// Creates the processor.
  const EntityFormFinalizationProcessor();

  @override
  void processForm(FormEntryModel model) {
    final formDef = model.form;
    final mainInstance = formDef.mainInstance;

    final entityFormExtra = formDef.extras[EntityFormExtra];
    if (entityFormExtra is! EntityFormExtra) return;
    final saveTos = entityFormExtra.saveTos;

    final entityElements = EntityFormParser.getEntityElements(
      mainInstance.root,
    );
    var entitiesExtra = EntitiesExtra();
    for (final element in entityElements) {
      final action = EntityFormParser.parseAction(element);
      final dataset = EntityFormParser.parseDataset(element)!;
      final id = EntityFormParser.parseId(element);
      final label = EntityFormParser.parseLabel(element);

      if (action != null) {
        entitiesExtra = entitiesExtra.plus(
          _createEntity(
            dataset,
            id,
            label,
            element.ref,
            saveTos,
            action,
            mainInstance,
          ),
        );
      }
    }

    model.extras[EntitiesExtra] = entitiesExtra;
  }

  FormEntity _createEntity(
    String dataset,
    String? id,
    String label,
    TreeReference elementRef,
    List<SaveTo> saveTos,
    EntityAction action,
    FormInstance mainInstance,
  ) {
    final entityGroupRef = elementRef.parentRef!.parentRef!;
    final genericGroupRef = entityGroupRef.genericize();
    final fields = <EntityProperty>[];
    for (final saveTo in saveTos) {
      if (genericGroupRef != saveTo.entityGroupReference) continue;
      final entityFieldRef = saveTo.reference.contextualize(entityGroupRef);
      final element = entityFieldRef == null
          ? null
          : mainInstance.resolveReference(entityFieldRef);
      if (element != null && element.isRelevant) {
        fields.add((saveTo.value, element.value?.uncast().string ?? ''));
      }
    }

    return FormEntity(action, dataset, id, label, fields);
  }
}
