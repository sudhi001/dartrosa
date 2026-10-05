/// ODK entities for DartRosa: a port of ODK Collect's entities module.
///
/// * Enable entities for a form load with [withEntities], then after
///   finalizing read [formEntities] or save them with [saveFormEntities].
/// * Store lists in an [EntitiesRepository] (implement it on your
///   storage, or use [InMemEntitiesRepository]) and update them from the
///   server with [LocalEntityUseCases].
/// * The JavaRosa-level pieces ([EntityFormParseProcessor],
///   [EntityFormFinalizationProcessor], [LocalEntitiesInstanceProvider],
///   [LocalEntitiesFilterStrategy], [PullDataFunctionHandler]) can also be
///   wired by hand.
///
/// @docImport 'src/entities_config.dart';
/// @docImport 'src/javarosa/filter/local_entities_filter_strategy.dart';
/// @docImport 'src/javarosa/filter/pull_data_function_handler.dart';
/// @docImport 'src/javarosa/finalization/entity_form_finalization_processor.dart';
/// @docImport 'src/javarosa/instance/local_entities_instance_provider.dart';
/// @docImport 'src/javarosa/parse/entity_form_parse_processor.dart';
/// @docImport 'src/local_entity_use_cases.dart';
/// @docImport 'src/storage/entities_repository.dart';
/// @docImport 'src/storage/in_mem_entities_repository.dart';
library;

export 'src/debug/debug_logger.dart';
export 'src/debug/entity_event.dart';
export 'src/entities_config.dart';
export 'src/javarosa/filter/local_entities_filter_strategy.dart';
export 'src/javarosa/filter/pull_data_function_handler.dart';
export 'src/javarosa/finalization/entities_extra.dart';
export 'src/javarosa/finalization/entity_form_finalization_processor.dart';
export 'src/javarosa/finalization/form_entity.dart';
export 'src/javarosa/instance/form_media_file_repository.dart';
export 'src/javarosa/instance/local_entities_external_instance_parser_factory.dart';
export 'src/javarosa/instance/local_entities_instance_adapter.dart';
export 'src/javarosa/instance/local_entities_instance_provider.dart';
export 'src/javarosa/parse/entity_form_extra.dart';
export 'src/javarosa/parse/entity_form_parse_processor.dart';
export 'src/javarosa/parse/entity_schema.dart';
export 'src/javarosa/parse/save_to.dart';
export 'src/javarosa/parse/string_ext.dart';
export 'src/javarosa/parse/xpath_expression_ext.dart';
export 'src/javarosa/spec/entity_action.dart';
export 'src/javarosa/spec/entity_form_parser.dart';
export 'src/javarosa/spec/entity_parse_exceptions.dart';
export 'src/javarosa/spec/form_entity_element.dart';
export 'src/local_entity_use_cases.dart';
export 'src/server/entity_source.dart';
export 'src/server/media_file.dart';
export 'src/storage/entities_repository.dart';
export 'src/storage/entity.dart';
export 'src/storage/entity_list.dart';
export 'src/storage/in_mem_entities_repository.dart';
export 'src/storage/query.dart';
export 'src/storage/query_exception.dart';
