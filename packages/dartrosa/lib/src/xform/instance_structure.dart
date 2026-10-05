import 'package:logging/logging.dart';

import '../model/data_type.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../util/java_lang.dart';
import 'kdom.dart';
import 'type_mappings.dart';
import 'xform_answer_data_parser.dart';
import 'xform_parse_exception.dart';

/// The JavaRosa namespace.
const namespaceJavaRosa = 'http://openrosa.org/javarosa';

final _log = Logger('dartrosa.xform');

/// Builds the [TreeElement] structure of the instance XML [node] (names,
/// multiplicities, templates, namespaces, attributes; no values).
///
/// Port of `XFormParser.buildInstanceStructure`.
TreeElement buildInstanceStructure(
  KElement node,
  TreeElement? parent, {
  required String documentNamespace,
  required Map<String, String?> namespacePrefixesByUri,
  String? instanceName,
  int? multiplicityFromGroup,
}) {
  var hasText = false;
  var hasElements = false;
  for (final child in node.children) {
    if (child is KElement) {
      hasElements = true;
    } else if (child is KText &&
        child.type == KNodeType.text &&
        javaTrim(child.content).isNotEmpty) {
      hasText = true;
    }
  }
  if (hasElements && hasText) {
    _log.warning(
      "instance node '${node.name}' contains both elements and text as "
      'children; text ignored',
    );
  }
  final name = node.name;
  final int multiplicity;
  if (_isTemplate(node)) {
    multiplicity = TreeReference.indexTemplate;
    if (parent != null &&
        parent.getChild(name, TreeReference.indexTemplate) != null) {
      throw XFormParseException(
        'More than one node declared as the template for the same repeated '
        'set [$name]',
        node,
      );
    }
  } else {
    multiplicity =
        multiplicityFromGroup ?? (parent?.childMultiplicity(name) ?? 0);
  }
  final modelType = node.attribute(namespaceJavaRosa, 'modeltype');
  if (modelType != null && typeMappings[modelType] == null) {
    throw XFormParseException('ModelType $modelType is not recognized.', node);
  }
  final element = TreeElement(name, multiplicity);
  if (modelType == null) element.instanceName = instanceName;
  if (node.namespace.isNotEmpty) {
    if (node.namespace != documentNamespace) element.namespace = node.namespace;
    if (namespacePrefixesByUri.containsKey(node.namespace)) {
      element.namespacePrefix = namespacePrefixesByUri[node.namespace];
    }
  }
  if (hasElements) {
    var childMultiplicity = childOptimizationsOk(node) ? 0 : null;
    for (final child in node.childElements) {
      element.addChild(
        buildInstanceStructure(
          child,
          element,
          instanceName: instanceName,
          documentNamespace: documentNamespace,
          namespacePrefixesByUri: namespacePrefixesByUri,
          multiplicityFromGroup: childMultiplicity,
        ),
      );
      if (childMultiplicity != null) childMultiplicity++;
    }
  }
  for (final a in node.attributes) {
    if (a.namespace == namespaceJavaRosa &&
        (a.name == 'template' || a.name == 'recordset')) {
      continue;
    }
    element.setAttribute(a.namespace, a.name, a.value);
  }
  return element;
}

bool _isTemplate(KElement node) =>
    node.attribute(namespaceJavaRosa, 'template') != null;

/// Whether all children of [parent] are same-named, non-template elements
/// (so multiplicities can be assigned by position).
bool childOptimizationsOk(KElement parent) {
  if (parent.childCount == 0) return false;
  final first = parent.elementAt(0);
  if (first == null || _isTemplate(first)) return false;
  for (var i = 1; i < parent.childCount; i++) {
    final child = parent.elementAt(i);
    if (child == null || _isTemplate(child) || child.name != first.name) {
      return false;
    }
  }
  return true;
}

/// Fills in values from the instance XML [node] into [current] (built by
/// [buildInstanceStructure]); select values attach to [form]'s choices.
///
/// Port of `XFormParser.loadInstanceData`.
void loadInstanceData(KElement node, TreeElement current, FormDef? form) {
  final hasElements = node.children.any((c) => c is KElement);
  if (hasElements) {
    final multiplicities = <String, int>{};
    for (final child in node.childElements) {
      final name = child.name;
      final int index;
      if (_isTemplate(child)) {
        index = TreeReference.indexTemplate;
      } else {
        final previous = multiplicities[name];
        index = previous == null ? 0 : previous + 1;
        multiplicities[name] = index;
      }
      loadInstanceData(child, current.getChild(name, index)!, form);
    }
  } else {
    final text = xmlText(node, trim: true);
    if (text != null && javaTrim(text).isNotEmpty) {
      current.value = parseAnswerData(
        text,
        current.dataType,
        questionForData(current.dataType, form, current.ref),
      );
    }
  }
}

/// The select question bound to [ref], needed to attach choices.
///
/// Port of `XFormParser.ghettoGetQuestionDef`.
QuestionDef? questionForData(
  DataType dataType,
  FormDef? form,
  TreeReference ref,
) =>
    (dataType == DataType.choice || dataType == DataType.multipleItems) &&
        form != null
    ? FormDef.findQuestionByRef(ref, form)
    : null;

/// Copies the namespace declarations of [e] (with a prefix) into
/// [instance]. Port of `XFormParser.loadNamespaces`.
void loadNamespaces(KElement e, FormInstance instance) {
  for (final (prefix, uri) in e.namespaceDeclarations) {
    if (prefix != null) instance.namespaces[prefix] = uri;
  }
}

/// The namespace declarations of [e] as URI → prefix (`null` for the
/// default namespace). Port of `XFormParser.buildNamespacesMap`.
Map<String, String?> namespacesMap(KElement e) => {
  for (final (prefix, uri) in e.namespaceDeclarations) uri: prefix,
};

/// Builds an instance from saved instance XML (e.g. a draft), with values
/// as untyped text. Port of `XFormParser.restoreDataModel`.
FormInstance restoreDataModel(KElement root) {
  final element = buildInstanceStructure(
    root,
    null,
    documentNamespace: root.namespace,
    namespacePrefixesByUri: namespacesMap(root),
  );
  final instance = FormInstance(element);
  loadNamespaces(root, instance);
  loadInstanceData(root, element, null);
  return instance;
}
