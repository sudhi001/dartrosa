/// ODK Collect's external data ("dynamic preload") for DartRosa:
/// `pulldata()` and `search()` appearances over CSV form media.
///
/// Add an [ExternalDataPlugin] to `DartRosaConfig.plugins`, then get the
/// choices of selects with a `search()` appearance with
/// [loadSelectChoices]. A port of Collect's `dynamicpreload` package and
/// the entities module's `PullDataFunctionHandler`.
library;

export 'src/csv_reader.dart';
export 'src/dynamic_preload.dart';
export 'src/external_answer_resolver.dart';
export 'src/external_data_exception.dart';
export 'src/external_data_handler.dart';
export 'src/external_data_handler_pull.dart';
export 'src/external_data_handler_search.dart';
export 'src/external_data_manager.dart';
export 'src/external_data_plugin.dart';
export 'src/external_data_reader.dart';
export 'src/external_data_repository.dart';
export 'src/external_data_search_type.dart';
export 'src/external_data_set.dart';
export 'src/external_data_use_cases.dart';
export 'src/external_data_util.dart';
export 'src/external_select_choice.dart';
export 'src/pull_data_function_handler.dart';
export 'src/select_choice_utils.dart';
