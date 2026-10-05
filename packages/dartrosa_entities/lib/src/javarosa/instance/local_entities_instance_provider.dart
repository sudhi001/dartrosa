import 'package:dartrosa/javarosa.dart';

import '../../storage/entities_repository.dart';
import 'form_media_file_repository.dart';
import 'local_entities_instance_adapter.dart';

/// Supplies entity lists as secondary instances (`<instance id="people"
/// src="jr://file-csv/people.csv"/>` where `people` is a local list),
/// supporting partial parsing.
///
/// Port of
/// `org.odk.collect.entities.javarosa.intance.LocalEntitiesInstanceProvider`.
final class LocalEntitiesInstanceProvider implements InstanceProvider {
  /// Creates a provider reading the lists of the repository the given
  /// function provides; the media file repository tells whether the form
  /// has the instance's file attached.
  LocalEntitiesInstanceProvider(
    this._entitiesRepositoryProvider,
    this._mediaFileRepository,
  );

  final EntitiesRepository Function() _entitiesRepositoryProvider;
  final FormMediaFileRepository _mediaFileRepository;

  @override
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) {
    final root = TreeElement('root', 0);
    for (final item in _createDataAdapter().getAll(
      instanceId,
      partial: partial,
    )) {
      root.addChild(item);
    }
    return root;
  }

  @override
  bool isSupported(String instanceId, String instanceSrc) {
    // Entity lists are stored in the database, not as files on disk (their
    // seed CSV is deleted after import). So if a media file referenced by
    // the instance's src exists, it must be a plain attached CSV, which
    // should be used instead of any same-named entity list. Returning false
    // lets JavaRosa parse the file directly.
    if (_mediaFileRepository.exists(instanceSrc)) return false;
    return _createDataAdapter().supportsInstance(instanceId);
  }

  LocalEntitiesInstanceAdapter _createDataAdapter() =>
      LocalEntitiesInstanceAdapter(_entitiesRepositoryProvider());
}
