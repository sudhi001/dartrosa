import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'debug/debug_logger.dart';
import 'debug/entity_event.dart';
import 'javarosa/filter/local_entities_filter_strategy.dart';
import 'javarosa/filter/pull_data_function_handler.dart';
import 'javarosa/finalization/entities_extra.dart';
import 'javarosa/finalization/entity_form_finalization_processor.dart';
import 'javarosa/instance/form_media_file_repository.dart';
import 'javarosa/instance/local_entities_instance_provider.dart';
import 'javarosa/parse/entity_form_parse_processor.dart';
import 'local_entity_use_cases.dart';
import 'storage/entities_repository.dart';

/// [base] with ODK entities enabled, the way Collect wires them when it
/// loads a form:
///
/// * an [EntityFormParseProcessor] (entity forms, `entities:saveto`);
/// * a [LocalEntitiesInstanceProvider] so local entity lists are
///   secondary instances (`<instance id="people"
///   src="jr://file-csv/people.csv"/>`) unless the form has that file
///   attached ([mediaFiles]);
/// * a [LocalEntitiesFilterStrategy] answering supported predicates
///   (`[name = 'x']`, `[prop != /data/q]`, `and`/`or`) from the
///   repository;
/// * a [PullDataFunctionHandler] for `pulldata()` on entity lists (a
///   `pulldata` handler in [base] becomes its fallback);
/// * an [EntityFormFinalizationProcessor], so finalizing puts the form's
///   entities in the session's `extras` (see [formEntities] and
///   [saveFormEntities]).
///
/// Call it for every form load (as Collect does): the parse processor
/// collects per-parse state, and the filter strategy and `pulldata`
/// handler read the repository's list names when created. [base] must
/// not have an `externalInstanceParser` (a parser can't be copied); pass
/// [externalInstanceParserFactory] to customize the parser instead.
DartRosaConfig withEntities(
  DartRosaConfig base, {
  required EntitiesRepository Function() entitiesRepository,
  FormMediaFileRepository? mediaFiles,
  ExternalInstanceParser Function()? externalInstanceParserFactory,
}) {
  if (base.externalInstanceParser != null) {
    throw ArgumentError.value(
      base,
      'base',
      'has an externalInstanceParser; pass externalInstanceParserFactory',
    );
  }
  final repository = entitiesRepository();
  final externalInstanceParser =
      (externalInstanceParserFactory ?? ExternalInstanceParser.new)()
        ..addInstanceProvider(
          LocalEntitiesInstanceProvider(
            entitiesRepository,
            mediaFiles ?? InMemFormMediaFileRepository(),
          ),
        );
  final pullDataFallback = base.functions
      .where((f) => f.name == PullDataFunctionHandler.functionName)
      .lastOrNull;

  return DartRosaConfig(
    resolver: base.resolver,
    functions: [
      ...base.functions.where(
        (f) => f.name != PullDataFunctionHandler.functionName,
      ),
      PullDataFunctionHandler(repository, fallback: pullDataFallback),
    ],
    filterStrategies: [
      LocalEntitiesFilterStrategy(repository),
      ...base.filterStrategies,
    ],
    parseProcessors: [...base.parseProcessors, EntityFormParseProcessor()],
    finalizationProcessors: [
      ...base.finalizationProcessors,
      const EntityFormFinalizationProcessor(),
    ],
    preloadHandlers: base.preloadHandlers,
    externalInstanceParser: externalInstanceParser,
    setGeopointAction: base.setGeopointAction,
    properties: base.properties,
  );
}

/// The entities a finalized [session] creates or updates (`null` if the
/// form is not an entity form using local entities, or not finalized).
EntitiesExtra? formEntities(FormSession session) =>
    session.extras[EntitiesExtra] as EntitiesExtra?;

/// Saves the entities of the finalized [session] to [entitiesRepository]
/// (Collect does this when a finalized form is saved). See
/// [LocalEntityUseCases.updateLocalEntitiesFromForm].
void saveFormEntities(
  FormSession session,
  EntitiesRepository entitiesRepository, {
  DebugLogger<EntityEvent>? debugLogger,
}) => LocalEntityUseCases.updateLocalEntitiesFromForm(
  formEntities(session),
  entitiesRepository,
  debugLogger: debugLogger,
);
