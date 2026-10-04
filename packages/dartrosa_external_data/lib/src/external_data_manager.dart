import 'external_data_set.dart';

/// The data sets available to one form's `pulldata()` and `search()`.
///
/// Port of Collect's `ExternalDataManager` / `ExternalDataManagerImpl`
/// (which opens `<name>.db` files from the form's media folder on demand).
/// Here the data sets are opened while the form loads, because XPath
/// functions are synchronous.
final class ExternalDataManager {
  /// Creates a manager for [dataSets] (by data set name) whose CSV media
  /// files [mediaFiles] (file names) exist.
  ExternalDataManager({
    Map<String, ExternalDataSet> dataSets = const {},
    Iterable<String> mediaFiles = const [],
  }) : _dataSets = {
         for (final MapEntry(:key, :value) in dataSets.entries)
           key.toLowerCase(): value,
       },
       _mediaFiles = {for (final f in mediaFiles) f.toLowerCase()};

  final Map<String, ExternalDataSet> _dataSets;
  final Set<String> _mediaFiles;

  /// The data set [dataSetName] (compared case-insensitively), or `null`
  /// if it wasn't imported.
  ExternalDataSet? getDatabase(String dataSetName) =>
      _dataSets[dataSetName.toLowerCase()];

  /// Whether the media file [fileName] exists (case-insensitively).
  bool hasMediaFile(String fileName) =>
      _mediaFiles.contains(fileName.toLowerCase());
}
