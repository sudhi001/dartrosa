import 'package:dartrosa/dartrosa.dart' show TreeReference;
import 'package:dartrosa/javarosa.dart';

import '../spec/entity_form_parser.dart';
import '../spec/entity_parse_exceptions.dart';
import 'entity_form_extra.dart';
import 'save_to.dart';

/// The entities spec namespace.
const entitiesNamespace = 'http://www.opendatakit.org/xforms/entities';

/// Parser plugin for entity forms: checks the `entities-version` model
/// attribute and collects `entities:saveto` binds into an
/// [EntityFormExtra] stored in `FormDef.extras`.
///
/// Port of
/// `org.odk.collect.entities.javarosa.parse.EntityFormParseProcessor`.
/// Add a new instance to each parser (as Collect's
/// `EntityXFormParserFactory` does): it collects state while a form is
/// parsed. The state is also cleared when a parse completes, so reusing
/// an instance after a successful parse is safe.
final class EntityFormParseProcessor
    implements
        BindAttributeProcessor,
        FormDefProcessor,
        ModelAttributeProcessor {
  /// Creates the processor.
  EntityFormParseProcessor();

  static const _v2022_1 = '2022.1';
  static const _v2023_1 = '2023.1';
  static const _v2024_1 = '2024.1';
  static const _v2025_1 = '2025.1';

  /// The `entities-version` prefixes Collect supports.
  static const supportedVersions = [_v2022_1, _v2023_1, _v2024_1, _v2025_1];

  /// The versions whose entities are saved locally (offline entities).
  static const localEntityVersions = [_v2024_1, _v2025_1];

  final List<(TreeReference, String)> _bindAttributes = [];
  String? _version;

  @override
  Set<(String, String)> get modelAttributes => const {
    (entitiesNamespace, 'entities-version'),
  };

  /// Throws [UnrecognizedEntityVersionException] for an unsupported
  /// version.
  @override
  void processModelAttribute(String name, String value) {
    _version = value;

    if (!supportedVersions.any(value.startsWith)) {
      throw UnrecognizedEntityVersionException(value);
    }
  }

  @override
  Set<(String, String)> get bindAttributes => const {
    (entitiesNamespace, 'saveto'),
  };

  @override
  void processBindAttribute(String name, String value, DataBinding binding) {
    _bindAttributes.add((binding.reference, value));
  }

  /// Throws [MissingModelAttributeException] for an entity form without
  /// `entities-version`.
  @override
  void processFormDef(FormDef form) {
    final version = _version;
    final bindAttributes = List.of(_bindAttributes);
    _version = null;
    _bindAttributes.clear();

    if (!_isEntityForm(form)) return;
    if (version == null) {
      throw const MissingModelAttributeException(
        entitiesNamespace,
        'entities-version',
      );
    }
    if (localEntityVersions.any(version.startsWith)) {
      final saveTos = <SaveTo>[];
      for (final (ref, value) in bindAttributes) {
        // Collect casts the parent to TreeElement (failing for a bind to
        // a node that doesn't exist); such binds are skipped here.
        final parentElement = form.mainInstance.resolveReference(ref)?.parent;
        final entityGroup = _findNearestEntityGroupElement(parentElement);
        if (entityGroup != null) {
          saveTos.add(SaveTo(ref, value, entityGroup.ref.genericize()));
        }
      }
      form.extras.put(EntityFormExtra(saveTos));
    }
  }

  static TreeElement? _findNearestEntityGroupElement(TreeElement? element) {
    if (element == null) return null;
    if (EntityFormParser.hasEntityElement(element)) return element;
    return _findNearestEntityGroupElement(element.parent);
  }

  static bool _isEntityForm(FormDef form) =>
      EntityFormParser.hasEntityElement(form.mainInstance.root);
}
