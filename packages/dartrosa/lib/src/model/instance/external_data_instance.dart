import '../../reference/resource_resolver.dart';
import 'data_instance.dart';
import 'external/external_instance_parser.dart';
import 'tree_element.dart';
import 'tree_reference.dart';

/// A secondary instance loaded from a `src` URI (`jr://file/…`,
/// `jr://file-csv/…`, GeoJSON, or an [InstanceProvider]).
///
/// Port of `org.javarosa.core.model.instance.ExternalDataInstance`. A
/// missing or empty file is replaced by a placeholder top-level element
/// named `missing file`, so forms still load.
final class ExternalDataInstance extends DataInstance {
  ExternalDataInstance._(
    TreeElement topLevel,
    String instanceId,
    this.path, {
    required this.isUsingPlaceholder,
    TreeElement Function()? reload,
  }) : _reload = reload,
       super(instanceId) {
    name = instanceId;
    _setRoot(topLevel);
  }

  /// Name of the placeholder top-level element.
  static const placeholderName = 'missing file';

  /// Loads the instance [instanceId] from [instanceSrc] with [parser]
  /// (default: [ExternalInstanceParser] with its CSV and GeoJSON parsers),
  /// reading files through [resolver].
  ///
  /// Instance providers are asked for a partial instance first; it's
  /// completed when evaluation reaches a partial element.
  static Future<ExternalDataInstance> build(
    ResourceResolver resolver,
    String instanceSrc,
    String instanceId, {
    ExternalInstanceParser? parser,
  }) async {
    final instanceParser = parser ?? ExternalInstanceParser();
    TreeElement? root;
    TreeElement Function()? reload;
    try {
      (root, reload) = await instanceParser.parseWithReload(
        resolver,
        instanceId,
        instanceSrc,
        partial: true,
      );
    } on ResourceNotFoundException {
      root = null;
    }
    final usePlaceholder = root == null || !root.hasChildren;
    return ExternalDataInstance._(
      usePlaceholder ? TreeElement(placeholderName, 0) : root,
      instanceId,
      instanceSrc,
      isUsingPlaceholder: usePlaceholder,
      reload: usePlaceholder ? null : reload,
    );
  }

  /// The `src` the instance was loaded from.
  final String path;

  /// Whether the file was missing or empty and a placeholder is used.
  final bool isUsingPlaceholder;

  final TreeElement Function()? _reload;
  late TreeElement _base;

  void _setRoot(TreeElement topLevel) {
    _base = TreeElement()
      ..instanceName = name
      ..addChild(topLevel);
  }

  @override
  TreeElement get base => _base;

  /// The top-level element.
  @override
  TreeElement get root {
    if (_base.numChildren == 0) throw StateError('root node has no children');
    return _base.childAt(0);
  }

  /// Resolves [ref]; when the resolved element is partial, the full
  /// instance is loaded and [ref] resolved again. (As in JavaRosa, only
  /// the resolved element itself is checked, not its ancestors.)
  @override
  TreeElement? resolveReference(TreeReference ref) {
    try {
      return super.resolveReference(ref);
    } on PartialElementEncounteredException {
      final reload = _reload;
      if (reload == null) rethrow;
      _setRoot(reload());
      return resolveReference(ref);
    }
  }
}
