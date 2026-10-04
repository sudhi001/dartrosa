import 'dart:async';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'dynamic_preload.dart';
import 'external_answer_resolver.dart';
import 'external_data_handler_pull.dart';
import 'external_data_manager.dart';
import 'external_data_reader.dart';
import 'external_data_repository.dart';
import 'external_data_use_cases.dart';
import 'pull_data_function_handler.dart';

/// Enables ODK Collect's external data ("dynamic preload") for forms
/// loaded with a [DartRosaConfig]: `pulldata()` over CSV media (and over
/// [instanceAdapter]'s instances) and `search()` appearances.
///
/// ```dart
/// final config = DartRosaConfig(
///   resolver: mediaResolver,
///   plugins: [ExternalDataPlugin(listMedia: (form) => mediaFileNames)],
/// );
/// final definition = await FormDefinition.parse(xml, config: config);
/// // Choices of a select with a search() appearance:
/// final choices = loadSelectChoices(prompt);
/// ```
///
/// Ports what Collect wires in `DynamicPreloadXFormParserFactory` (the
/// parse processor), `FormLoaderTask` (importing the CSVs after parsing,
/// and `ExternalAnswerResolver` for saved instances) and
/// `CollectFormEntryControllerFactory` (registering `pulldata`).
final class ExternalDataPlugin extends FormLoadPlugin {
  /// Creates the plugin.
  ///
  /// [repository] gives the store for a form's imported CSVs (default: a
  /// fresh in-memory one per form, so CSVs are imported on every load;
  /// return a persistent one per media folder to import only changed
  /// files). [listMedia] names the form's media files (Collect imports
  /// every CSV in the media folder); without it the data sets the form
  /// names literally are tried. [mediaUri] maps a media file name to the
  /// URI read through the config's resolver. [isCancelled] and
  /// [onProgress] follow the import.
  ExternalDataPlugin({
    ExternalDataRepository Function(FormDef form)? repository,
    FutureOr<Iterable<String>?> Function(FormDef form)? listMedia,
    this.mediaUri = ExternalDataManager.defaultMediaUri,
    this.instanceAdapter,
    this.isCancelled,
    this.onProgress,
  }) : _repository = repository ?? _inMemory,
       _listMedia = listMedia;

  static ExternalDataRepository _inMemory(FormDef form) =>
      InMemoryExternalDataRepository();

  final ExternalDataRepository Function(FormDef form) _repository;
  final FutureOr<Iterable<String>?> Function(FormDef form)? _listMedia;

  /// Maps a media file name to its URI.
  final String Function(String fileName) mediaUri;

  /// Serves `pulldata()` for non-CSV instances (e.g. entity lists).
  final PullDataInstanceAdapter? instanceAdapter;

  /// Polled while importing; when it returns `true` the form fails to load
  /// with an `ExternalDataImportCancelledException`.
  final bool Function()? isCancelled;

  /// Receives import progress messages.
  final ExternalDataProgress? onProgress;

  @override
  List<Object> createParseProcessors() => [DynamicPreloadParseProcessor()];

  @override
  Future<void> prepareForm(FormDef form, ResourceResolver resolver) async {
    final manager = await ExternalDataUseCases.create(
      form,
      resolver,
      repository: _repository(form),
      mediaFiles: await _listMedia?.call(form),
      mediaUri: mediaUri,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    form
      ..extras.put(manager)
      ..addFunctionHandler(
        PullDataFunctionHandler(
          instanceAdapter,
          fallback: ExternalDataHandlerPull(manager),
        ),
      );
  }

  @override
  AnswerResolver get answerResolver => externalAnswerResolver;
}
