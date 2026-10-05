import 'package:logging/logging.dart';

import '../model/condition/conditions.dart';
import '../model/condition/evaluation_context.dart';
import '../model/data_binding.dart';
import '../model/data_type.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/external_data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../model/itemset_binding.dart';
import 'instance_structure.dart';
import 'kdom.dart';
import 'xform_parse_exception.dart';

final _log = Logger('dartrosa.xform');

/// Builds instances from their XML and, for the main instance, checks and
/// applies everything the parser collected (repeats, binds, actions,
/// itemsets).
///
/// Port of `org.javarosa.xform.parse.FormInstanceParser`.
final class FormInstanceParser {
  /// Creates a parser for the form being built, with what the XForm parser
  /// collected.
  FormInstanceParser(
    this._formDef,
    this._defaultNamespace,
    this._bindings,
    this._repeats,
    this._itemsets,
    this._selectOnes,
    this._selectMultis,
    this._actionTargets, {
    this.verifyExternalItemsets = true,
  });

  /// Whether itemset label and value nodes in external secondary instances
  /// are verified (not when restoring a cached form).
  final bool verifyExternalItemsets;

  final FormDef _formDef;
  final String? _defaultNamespace;
  final List<DataBinding> _bindings;
  final List<TreeReference> _repeats;
  final List<ItemsetBinding> _itemsets;
  final List<TreeReference> _selectOnes;
  final List<TreeReference> _selectMultis;
  final List<TreeReference> _actionTargets;
  FormInstance? _repeatTree;

  /// Builds the instance in [e] (named [name] unless it's the main one).
  FormInstance parseInstance(
    KElement e, {
    required bool isMainInstance,
    required String? name,
    required Map<String, String?> namespacePrefixesByUri,
  }) {
    final root = buildInstanceStructure(
      e,
      null,
      instanceName: isMainInstance ? null : name,
      documentNamespace: e.namespace,
      namespacePrefixesByUri: namespacePrefixesByUri,
    );
    final instance = FormInstance(root)
      ..name = isMainInstance ? _formDef.title : name;
    final schema = e.namespace;
    if (schema.isNotEmpty && schema != _defaultNamespace) {
      instance.schema = schema;
    }
    instance
      ..formVersion = e.attribute(null, 'version')
      ..uiVersion = e.attribute(null, 'uiVersion');
    loadNamespaces(e, instance);
    if (isMainInstance) {
      FormDef.updateItemsetReferences(_formDef.children);
      _processRepeats(instance);
      _verifyBindings(instance, e.name);
      _verifyActions(instance);
    }
    _applyInstanceProperties(instance);
    return instance;
  }

  void _processRepeats(FormInstance instance) {
    _flagRepeatables(instance);
    _processTemplates(instance);
    _checkDuplicateNodesAreRepeatable(instance.root);
    _checkHomogeneity(instance);
  }

  void _flagRepeatables(FormInstance instance) {
    for (final ref in _repeatableRefs) {
      for (final nodeRef in EvaluationContext(
        instance,
      ).expandReference(ref, includeTemplates: true)!) {
        instance.resolveReference(nodeRef)?.isRepeatable = true;
      }
    }
  }

  void _processTemplates(FormInstance instance) {
    _repeatTree = _buildRepeatTree(_repeatableRefs, instance.root.name!);
    final missing = <TreeReference>[];
    final repeatTree = _repeatTree;
    if (repeatTree != null) {
      _checkRepeatsForTemplate(
        repeatTree.root,
        const TreeReference.root(),
        instance,
        missing,
      );
    }
    _removeInvalidTemplates(instance.root, repeatTree?.root, true);
    _createMissingTemplates(instance, missing);
  }

  void _verifyBindings(FormInstance instance, String mainInstanceNodeName) {
    for (var i = 0; i < _bindings.length; i++) {
      final ref = _bindings[i].reference;
      if (ref.size == 0) {
        _log.info("Cannot bind to '/'; ignoring bind...");
        _bindings.removeAt(i--);
      } else if (EvaluationContext(
        instance,
      ).expandReference(ref, includeTemplates: true)!.isEmpty) {
        _log.warning(
          "XForm Parse Warning: <bind> defined for a node that doesn't exist "
          "[$ref]. The node's name was probably changed and the bind should "
          'be updated.',
        );
      }
    }
    for (final ref in _repeatableRefs) {
      if (ref.size <= 1) {
        throw XFormParseException(
          "Cannot bind repeat to '/' or '/$mainInstanceNodeName'",
        );
      }
    }
    final errors = <String>[];
    _verifyControlBindings(_formDef, instance, errors);
    if (errors.isNotEmpty) {
      throw XFormParseException(errors.map((e) => '$e\n').join());
    }
    _verifyRepeatMemberBindings(_formDef, null);
    _verifyItemsetBindings(instance);
    _verifyItemsetSrcDstCompatibility(instance);
  }

  void _verifyActions(FormInstance instance) {
    for (final target in _actionTargets) {
      if (EvaluationContext(
        instance,
      ).expandReference(target, includeTemplates: true)!.isEmpty) {
        throw XFormParseException(
          'Invalid Action - Targets non-existent node: '
          '${target.toString(includePredicates: true)}',
        );
      }
    }
  }

  static void _checkDuplicateNodesAreRepeatable(TreeElement node) {
    if (node.multiplicity > 0 && !node.isRepeatable) {
      _log.warning(
        'repeated nodes [${node.name}] detected that have no repeat binding '
        'in the form; DO NOT bind questions to these nodes or their '
        'children!',
      );
    }
    node.children.forEach(_checkDuplicateNodesAreRepeatable);
  }

  void _checkHomogeneity(FormInstance instance) {
    for (final ref in _repeatableRefs) {
      TreeElement? template;
      for (final nodeRef in EvaluationContext(instance).expandReference(ref)!) {
        final node = instance.resolveReference(nodeRef);
        if (node == null) continue;
        template ??= instance.getTemplate(nodeRef);
        if (!FormInstance.isHomogeneous(template!, node)) {
          _log.warning(
            'XForm Parse Warning: Not all repeated nodes for a given repeat '
            'binding [$nodeRef] are homogeneous! This will cause serious '
            'problems!',
          );
        }
      }
    }
  }

  void _verifyControlBindings(
    FormElement element,
    FormInstance instance,
    List<String> errors,
  ) {
    for (final child in element.children) {
      final type = child is GroupDef
          ? (child.isRepeat ? 'Repeat' : 'Group')
          : 'Question';
      final ref = child.bind!;
      if (child is QuestionDef && ref.size == 0) {
        _log.warning("XForm Parse Warning: Cannot bind control to '/'");
      } else if (EvaluationContext(
        instance,
      ).expandReference(ref, includeTemplates: true)!.isEmpty) {
        errors.add('$type bound to non-existent node: [$ref]');
      }
      _verifyControlBindings(child, instance, errors);
    }
  }

  void _verifyRepeatMemberBindings(
    FormElement element,
    GroupDef? parentRepeat,
  ) {
    for (final child in element.children) {
      final isRepeat = child is GroupDef && child.isRepeat;
      final repeatBind = parentRepeat?.bind ?? const TreeReference.root();
      final childBind = child.bind!;
      if (!repeatBind.isAncestorOf(childBind)) {
        throw XFormParseException(
          "<repeat> member's binding [$childBind] is not a descendant of "
          '<repeat> binding [$repeatBind]!',
        );
      } else if (repeatBind == childBind && isRepeat) {
        throw XFormParseException(
          'child <repeat>s [$childBind] cannot bind to the same node as their '
          'parent <repeat>; only questions/groups can',
        );
      }
      final ancestry = <TreeElement>[];
      var repeatNode = _repeatTree?.root;
      if (repeatNode != null) {
        ancestry.add(repeatNode);
        for (var j = 1; j < childBind.size; j++) {
          repeatNode = repeatNode!.getChild(childBind.nameAt(j), 0);
          if (repeatNode == null) break;
          ancestry.add(repeatNode);
        }
      }
      for (var k = repeatBind.size; k < childBind.size; k++) {
        final repeatChild = k < ancestry.length ? ancestry[k] : null;
        final repeatable = repeatChild != null && repeatChild.isRepeatable;
        if (repeatable && !(k == childBind.size - 1 && isRepeat)) {
          throw XFormParseException(
            "<repeat> member's binding [$childBind] is within the scope of a "
            '<repeat> that is not its closest containing <repeat>!',
          );
        }
      }
      _verifyRepeatMemberBindings(child, isRepeat ? child : parentRepeat);
    }
  }

  void _verifyItemsetBindings(FormInstance instance) {
    for (final itemset in _itemsets) {
      final nodeset = itemset.nodesetRef!;
      final label = itemset.labelRef!;
      if (!nodeset.isAncestorOf(label)) {
        throw XFormParseException(
          'itemset nodeset ref is not a parent of label ref',
        );
      } else if (itemset.copyRef != null &&
          !nodeset.isAncestorOf(itemset.copyRef!)) {
        throw XFormParseException(
          'itemset nodeset ref is not a parent of copy ref',
        );
      } else if (itemset.valueRef != null &&
          !nodeset.isAncestorOf(itemset.valueRef!)) {
        throw XFormParseException(
          'itemset nodeset ref is not a parent of value ref',
        );
      }
      if (itemset.copyRef != null &&
          itemset.valueRef != null &&
          !itemset.copyRef!.isAncestorOf(itemset.valueRef!)) {
        throw XFormParseException('itemset <copy> is not a parent of <value>');
      }
      final DataInstance secondary;
      if (label.instanceName != null) {
        secondary =
            _formDef.nonMainInstance(label.instanceName!) ??
            (throw XFormParseException(
              'Instance: ${label.instanceName} Does not exists',
            ));
      } else {
        secondary = instance;
      }
      final usesPlaceholder =
          secondary is ExternalDataInstance &&
          (secondary.isUsingPlaceholder || !verifyExternalItemsets);
      if (!usesPlaceholder) {
        if (secondary.getTemplatePath(label) == null) {
          throw XFormParseException(
            "<label> node for itemset doesn't exist! [$label]",
          );
        } else if (itemset.valueRef != null &&
            secondary.getTemplatePath(itemset.valueRef!) == null) {
          throw XFormParseException(
            "<value> node for itemset doesn't exist! [${itemset.valueRef}]",
          );
        }
      }
    }
  }

  void _verifyItemsetSrcDstCompatibility(FormInstance instance) {
    for (final itemset in _itemsets) {
      final destRepeatable = instance.getTemplate(itemset.destRef!) != null;
      if (itemset.copyMode) {
        if (!destRepeatable) {
          throw XFormParseException(
            'itemset copies to node(s) which are not repeatable',
          );
        }
        final source = instance.getTemplatePath(itemset.copyRef!)!;
        final destination = instance.getTemplate(itemset.destRef!)!;
        if (!FormInstance.isHomogeneous(source, destination)) {
          _log.warning(
            'XForm Parse Warning: Your itemset source [${source.ref}] and dest '
            '[${destination.ref}] of appear to be incompatible!',
          );
        }
      } else if (destRepeatable) {
        throw XFormParseException('itemset sets value on repeatable nodes');
      }
    }
  }

  void _applyInstanceProperties(FormInstance instance) {
    for (final bind in _bindings) {
      final ref = bind.reference;
      final nodeRefs = EvaluationContext(
        instance,
      ).expandReference(ref, includeTemplates: true)!;
      bind.relevancyCondition?.addTarget(ref);
      bind.requiredCondition?.addTarget(ref);
      bind.readonlyCondition?.addTarget(ref);
      bind.calculate?.addTarget(ref);
      for (final nodeRef in nodeRefs) {
        final node = instance.resolveReference(nodeRef)!
          ..dataType = bind.dataType;
        if (bind.relevancyCondition == null) {
          node.isRelevant = bind.relevantAbsolute;
        }
        if (bind.requiredCondition == null) {
          node.isRequired = bind.requiredAbsolute;
        }
        if (bind.readonlyCondition == null) {
          node.setEnabled(!bind.readonlyAbsolute);
        }
        if (bind.constraint != null) {
          node.constraint = Constraint(
            bind.constraint!,
            bind.constraintMessage,
          );
        }
        node
          ..preloadHandler = bind.preload
          ..preloadParams = bind.preloadParams
          ..bindAttributes = bind.additionalAttributes;
      }
    }
    _applyControlProperties(instance);
  }

  static void _checkRepeatsForTemplate(
    TreeElement repeatTreeNode,
    TreeReference ref,
    FormInstance instance,
    List<TreeReference> missing,
  ) {
    final extended = ref.extend(
      repeatTreeNode.name!,
      repeatTreeNode.isRepeatable ? TreeReference.indexTemplate : 0,
    );
    if (repeatTreeNode.isRepeatable &&
        instance.resolveReference(extended) == null) {
      missing.add(extended);
    }
    for (final child in repeatTreeNode.children) {
      _checkRepeatsForTemplate(child, extended, instance, missing);
    }
  }

  bool _removeInvalidTemplates(
    TreeElement instanceNode,
    TreeElement? repeatTreeNode,
    bool templateAllowed,
  ) {
    final multiplicity = instanceNode.multiplicity;
    final repeatable = repeatTreeNode != null && repeatTreeNode.isRepeatable;
    if (multiplicity == TreeReference.indexTemplate) {
      if (!templateAllowed) {
        _log.warning(
          'XForm Parse Warning: Template nodes for sub-repeats must be located '
          'within the template node of the parent repeat; ignoring '
          'template... [${instanceNode.name}]',
        );
        return true;
      } else if (!repeatable) {
        _log.warning(
          'XForm Parse Warning: Warning: template node found for ref that is '
          'not repeatable; ignoring... [${instanceNode.name}]',
        );
        return true;
      }
    }
    if (repeatable && multiplicity != TreeReference.indexTemplate) {
      templateAllowed = false;
    }
    for (var i = 0; i < instanceNode.numChildren; i++) {
      final child = instanceNode.childAt(i);
      final repeatChild = repeatTreeNode?.getChild(child.name!, 0);
      if (_removeInvalidTemplates(child, repeatChild, templateAllowed)) {
        instanceNode.removeChildAt(i--);
      }
    }
    return false;
  }

  void _createMissingTemplates(
    FormInstance instance,
    List<TreeReference> missing,
  ) {
    for (final templateRef in missing) {
      final ref = templateRef.genericize();
      final nodes = EvaluationContext(instance).expandReference(ref)!;
      if (nodes.isEmpty) continue;
      try {
        instance.copyNodeAt(nodes.first, templateRef);
      } on InvalidReferenceException {
        _log.warning(
          'XForm Parse Warning: Could not create a default repeat template; '
          'this is almost certainly a homogeneity error! Your form will not '
          'work! (Failed on $templateRef)',
        );
      }
      _trimRepeatChildren(instance.resolveReference(templateRef)!);
    }
  }

  static void _trimRepeatChildren(TreeElement node) {
    for (var i = 0; i < node.numChildren; i++) {
      final child = node.childAt(i);
      if (child.isRepeatable) {
        node.removeChildAt(i--);
      } else {
        _trimRepeatChildren(child);
      }
    }
  }

  void _applyControlProperties(FormInstance instance) {
    for (final (type, refs) in [
      (DataType.choice, _selectOnes),
      (DataType.multipleItems, _selectMultis),
    ]) {
      for (final ref in refs) {
        for (final nodeRef in EvaluationContext(
          instance,
        ).expandReference(ref, includeTemplates: true)!) {
          final node = instance.resolveReference(nodeRef)!;
          if (node.dataType == DataType.choice ||
              node.dataType == DataType.multipleItems) {
            // already a select type
          } else if (node.dataType == DataType.nullType ||
              node.dataType == DataType.text) {
            node.dataType = type;
          } else {
            _log.warning(
              'XForm Parse Warning: Select question $ref appears to have data '
              'type that is incompatible with selection',
            );
          }
        }
      }
    }
  }

  /// The repeat references plus itemset sources and copy destinations.
  /// Computed once, when the main instance is processed (after
  /// [FormDef.updateItemsetReferences]); the lists don't change afterwards.
  late final List<TreeReference> _repeatableRefs = _collectRepeatableRefs();

  List<TreeReference> _collectRepeatableRefs() {
    final refs = [..._repeats];
    for (final itemset in _itemsets) {
      final source = itemset.nodesetRef!;
      if (!refs.contains(source)) {
        var nonStatic = true;
        for (var j = 0; j < source.size; j++) {
          if (source.nameAt(j) == TreeReference.nameWildcard) nonStatic = false;
        }
        if (source.instanceName != null) nonStatic = false;
        if (nonStatic) refs.add(source);
      }
      if (itemset.copyMode) {
        final destination = itemset.destRef!;
        if (!refs.contains(destination)) refs.add(destination);
      }
    }
    return refs;
  }

  static FormInstance? _buildRepeatTree(
    List<TreeReference> repeatRefs,
    String topLevelName,
  ) {
    final root = TreeElement(null, 0);
    for (final repeatRef in repeatRefs) {
      if (repeatRef.instanceName != null || repeatRef.size <= 1) continue;
      var current = root;
      for (var j = 0; j < repeatRef.size; j++) {
        final name = repeatRef.nameAt(j);
        var child = current.getChild(name, 0);
        if (child == null) {
          child = TreeElement(name, 0);
          current.addChild(child);
        }
        current = child;
      }
      current.isRepeatable = true;
    }
    return root.numChildren == 0
        ? null
        : FormInstance(
            root.getChild(topLevelName, TreeReference.defaultMultiplicity),
          );
  }
}
