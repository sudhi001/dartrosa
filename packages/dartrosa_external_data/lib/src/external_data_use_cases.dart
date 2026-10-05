// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalDataUseCases), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'dynamic_preload.dart';
import 'external_data_exception.dart';
import 'external_data_manager.dart';
import 'external_data_reader.dart';
import 'external_data_repository.dart';
import 'external_data_set.dart';

/// Importing a form's CSV media when it loads.
///
/// Port of Collect's `ExternalDataUseCases`.
abstract final class ExternalDataUseCases {
  /// Imports the CSV media of [form] into [repository] if the form uses
  /// `pulldata()` or `search()` (has a [DynamicPreloadExtra]), and returns
  /// the [ExternalDataManager] serving them.
  ///
  /// As in Collect, every `.csv` in [mediaFiles] except `itemsets.csv` is
  /// imported, as a data set named after the file without its extension.
  /// Files are read through [resolver] at [mediaUri]. When [mediaFiles] is
  /// `null` (the app can't list the media), the data sets the form names
  /// literally are tried as `<name>.csv`. Missing files are skipped. Throws
  /// [ExternalDataException] if a file can't be imported and
  /// [ExternalDataImportCancelledException] if [isCancelled] became true.
  static Future<ExternalDataManager> create(
    FormDef form,
    ResourceResolver resolver, {
    required ExternalDataRepository repository,
    Iterable<String>? mediaFiles,
    String Function(String fileName) mediaUri =
        ExternalDataManager.defaultMediaUri,
    bool Function()? isCancelled,
    ExternalDataProgress? onProgress,
  }) async {
    final extra = form.extras.get<DynamicPreloadExtra>();
    if (extra == null) return ExternalDataManager(mediaUri: mediaUri);

    final csvFiles = [
      for (final name
          in mediaFiles ?? [for (final d in extra.referencedDataSets) '$d.csv'])
        if (name.toLowerCase().endsWith('.csv') &&
            name.toLowerCase() != 'itemsets.csv')
          name,
    ];
    final externalDataMap = <String, ExternalDataFile?>{};
    for (final csvFile in csvFiles) {
      final dataSetName = csvFile.substring(0, csvFile.lastIndexOf('.'));
      try {
        externalDataMap[dataSetName] = ExternalDataFile(
          csvFile,
          await resolver.read(mediaUri(csvFile)),
        );
      } on ResourceNotFoundException {
        externalDataMap[dataSetName] = null;
      }
    }
    if (externalDataMap.isNotEmpty) {
      onProgress?.call('Reading CSV files…');
      final completed = await ExternalDataReader(
        repository,
        isCancelled: isCancelled,
        onProgress: onProgress,
      ).doImport(externalDataMap);
      if (!completed) throw const ExternalDataImportCancelledException();
    }

    final dataSets = <String, ExternalDataSet>{};
    for (final name in {
      ...externalDataMap.keys.map((n) => n.toLowerCase()),
      ...extra.referencedDataSets,
    }) {
      final dataSet = await repository.open(name);
      if (dataSet != null) dataSets[name] = dataSet;
    }
    return ExternalDataManager(
      dataSets: dataSets,
      mediaFiles: [
        for (final MapEntry(:value) in externalDataMap.entries)
          if (value != null) value.fileName,
      ],
      mediaUri: mediaUri,
    );
  }
}
