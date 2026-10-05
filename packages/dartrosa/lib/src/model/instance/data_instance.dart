// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (PartialElementEncounteredException, DataInstance,
//  FormInstance, InvalidReferenceException), Copyright (C) 2009 JavaRosa;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// @docImport '../condition/evaluation_context.dart';
library;

import 'tree_element.dart';
import 'tree_reference.dart';

/// Thrown when resolving a reference reaches an element whose content has
/// not been loaded yet. Port of `PartialElementEncounteredException`.
final class PartialElementEncounteredException implements Exception {
  /// Creates the exception.
  PartialElementEncounteredException();
}

/// An instance: a tree of [TreeElement]s under a hidden [base] node.
///
/// Port of `org.javarosa.core.model.instance.DataInstance` (without
/// JavaRosa's storage fields).
abstract class DataInstance {
  /// Creates an instance with optional [instanceId].
  DataInstance([this.instanceId]);

  /// The instance id (`instance('id')`), `null` for the main instance.
  String? instanceId;

  /// The instance name used by [EvaluationContext.instanceNamed] lookups.
  String? name;

  /// The hidden node above the top-level element.
  TreeElement get base;

  /// The top-level element, or `null` if the instance isn't loaded.
  TreeElement? get root;

  /// Whether the instance's content is computed at evaluation time.
  bool get isRuntimeEvaluated => false;

  /// The element [ref] points to, or `null` if it doesn't exist or is
  /// ambiguous. Never returns the hidden base node.
  TreeElement? resolveReference(TreeReference ref) {
    if (!ref.isAbsolute) return null;
    TreeElement? node = base;
    TreeElement? result;
    for (var i = 0; i < ref.size; i++) {
      final name = ref.nameAt(i);
      var multiplicity = ref.multiplicityAt(i);
      if (multiplicity == TreeReference.indexAttribute) {
        node = result = node!.getAttribute(null, name);
        continue;
      }
      if (multiplicity == TreeReference.indexUnbound) {
        if (node!.childMultiplicity(name) == 1) {
          multiplicity = 0;
        } else {
          node = result = null;
          break;
        }
      }
      node = result = node!.getChild(name, multiplicity);
      if (node == null) break;
    }
    if (identical(node, base) || result == null) return null;
    if (result.isPartial) throw PartialElementEncounteredException();
    return result;
  }

  /// The elements along [ref], excluding the base and the final node;
  /// `null` if any step can't be resolved.
  List<TreeElement>? explodeReference(TreeReference ref) {
    if (!ref.isAbsolute) return null;
    final nodes = <TreeElement>[];
    var current = base;
    for (var i = 0; i < ref.size; i++) {
      final name = ref.nameAt(i);
      var multiplicity = ref.multiplicityAt(i);
      if (!identical(current, base)) nodes.add(current);
      if (multiplicity == TreeReference.indexAttribute) {
        final attribute = current.getAttribute(null, name);
        if (attribute == null) return nodes;
        current = attribute;
        continue;
      }
      if (multiplicity == TreeReference.indexUnbound) {
        if (current.childMultiplicity(name) != 1) return null;
        multiplicity = 0;
      }
      final child = current.getChild(name, multiplicity);
      if (child == null) return null;
      current = child;
    }
    return nodes;
  }

  /// The repeat template (or attribute) at [ref], if any.
  TreeElement? getTemplate(TreeReference ref) {
    final node = getTemplatePath(ref);
    return node != null && (node.isRepeatable || node.isAttribute)
        ? node
        : null;
  }

  /// The node at [ref] following templates where present, otherwise the
  /// first instance of each step.
  TreeElement? getTemplatePath(TreeReference ref) {
    if (!ref.isAbsolute) return null;
    TreeElement? walker;
    var node = base;
    for (var i = 0; i < ref.size; i++) {
      final name = ref.nameAt(i);
      if (ref.multiplicityAt(i) == TreeReference.indexAttribute) {
        final attribute = node.getAttribute(null, name);
        if (attribute == null) return null;
        node = walker = attribute;
      } else {
        final next =
            node.getChild(name, TreeReference.indexTemplate) ??
            node.getChild(name, 0);
        if (next == null) return null;
        node = walker = next;
      }
    }
    return walker;
  }

  /// Whether some template or instance path matches [ref].
  bool hasTemplatePath(TreeReference ref) =>
      ref.isAbsolute && _hasTemplatePath(ref, base, 0);

  bool _hasTemplatePath(TreeReference ref, TreeElement? node, int depth) {
    if (depth == ref.size) return true;
    if (node == null) return false;
    final name = ref.nameAt(depth);
    if (ref.multiplicityAt(depth) == TreeReference.indexAttribute) {
      return _hasTemplatePath(ref, node.getAttribute(null, name), depth + 1);
    }
    final template = node.getChild(name, TreeReference.indexTemplate);
    if (template != null) return _hasTemplatePath(ref, template, depth + 1);
    return node
        .childrenWithName(name)
        .any((child) => _hasTemplatePath(ref, child, depth + 1));
  }

  /// Fills partial top-level elements with [elements]' content.
  void replacePartialElements(List<TreeElement> elements) {
    for (final element in elements) {
      root
          ?.getChild(element.name!, element.multiplicity)
          ?.populatePartial(element);
    }
  }

  @override
  String toString() => name ?? 'NULL';
}

/// The main instance of a form (also used for inline secondary
/// instances).
///
/// Port of `org.javarosa.core.model.instance.FormInstance` (without
/// storage and metadata plumbing).
class FormInstance extends DataInstance {
  /// Creates an instance whose top-level element is [root].
  FormInstance([TreeElement? root, String? instanceId]) : super(instanceId) {
    setRoot(root);
  }

  TreeElement _base = TreeElement();

  /// A deep copy (templates included) with the same schema, versions and
  /// namespaces. Port of `FormInstance.clone` (storage fields aren't
  /// ported).
  FormInstance clone() => FormInstance(root.deepCopy(includeTemplates: true))
    ..schema = schema
    ..formVersion = formVersion
    ..uiVersion = uiVersion
    ..namespaces.addAll(namespaces);

  /// Names this secondary instance [instanceId] when the form starts.
  /// Port of `FormInstance.initialize`.
  void initialize(String instanceId) {
    this.instanceId = instanceId;
    root.instanceName = instanceId;
  }

  /// Form schema (the `xmlns` of the top-level element).
  String? schema;

  /// Form version (`version` attribute).
  String? formVersion;

  /// UI version (`uiVersion` attribute).
  String? uiVersion;

  /// Namespace prefixes declared on the instance, prefix → URI.
  final Map<String, String> namespaces = {};

  @override
  TreeElement get base => _base;

  /// The top-level element. Throws if there is none, as JavaRosa does.
  @override
  TreeElement get root {
    if (_base.numChildren == 0) throw StateError('root node has no children');
    return _base.childAt(0);
  }

  /// Replaces the top-level element with [topLevel].
  void setRoot(TreeElement? topLevel) {
    _base = TreeElement();
    if (topLevel != null) {
      _base
        ..instanceName = topLevel.instanceName
        ..addChild(topLevel);
    }
  }

  /// Whether [a] and [b] have the same (non-repeat) structure.
  ///
  /// Port of `FormInstance.isHomogeneous`.
  static bool isHomogeneous(TreeElement a, TreeElement b) {
    if (a.isLeaf && b.isLeaf) return true;
    if (!a.isChildable || !b.isChildable) return false;
    for (final (n1, n2) in [(a, b), (b, a)]) {
      for (final child1 in n1.children) {
        if (child1.isRepeatable) continue;
        final child2 = n2.getChild(child1.name!, 0);
        if (child2 == null) return false;
        if (child2.isRepeatable) throw StateError("shouldn't happen");
      }
    }
    for (final childA in a.children) {
      if (childA.isRepeatable) continue;
      if (!isHomogeneous(childA, b.getChild(childA.name!, 0)!)) return false;
    }
    return true;
  }

  /// Copies the element at [from] to [to] (a new repeat instance); returns
  /// the new element's reference.
  TreeReference copyNodeAt(TreeReference from, TreeReference to) {
    if (!from.isAbsolute) {
      throw InvalidReferenceException(
        'Source reference must be absolute for copying',
        from,
      );
    }
    final source = resolveReference(from);
    if (source == null) {
      throw InvalidReferenceException(
        'Null Source reference while attempting to copy node',
        from,
      );
    }
    return copyNode(source, to).ref;
  }

  /// Copies [source] (without templates) to [to], which may be unbound in
  /// its last step to append a new instance.
  TreeElement copyNode(TreeElement source, TreeReference to) {
    if (!to.isAbsolute) {
      throw InvalidReferenceException(
        'Destination reference must be absolute for copying',
        to,
      );
    }
    final destinationName = to.lastName;
    var destinationMultiplicity = to.lastMultiplicity;
    final parentRef = to.parentRef!;
    final parent = resolveReference(parentRef);
    if (parent == null) {
      throw InvalidReferenceException(
        'Null parent reference whle attempting to copy',
        parentRef,
      );
    }
    if (!parent.isChildable) {
      throw InvalidReferenceException(
        'Invalid Parent Node: cannot accept children.',
        parentRef,
      );
    }
    if (destinationMultiplicity == TreeReference.indexUnbound) {
      destinationMultiplicity = parent.childMultiplicity(destinationName);
    } else if (parent.getChild(destinationName, destinationMultiplicity) !=
        null) {
      throw InvalidReferenceException('Destination already exists!', to);
    }
    final destination = source.deepCopy(includeTemplates: false)
      ..name = destinationName
      ..multiplicity = destinationMultiplicity;
    parent.addChild(destination);
    return destination;
  }
}

/// A reference that can't be used for the requested operation. Port of
/// `org.javarosa.core.model.instance.InvalidReferenceException`.
final class InvalidReferenceException implements Exception {
  /// Creates the exception for [reference].
  InvalidReferenceException(this.message, this.reference);

  /// What went wrong.
  final String message;

  /// The offending reference.
  final TreeReference reference;

  @override
  String toString() => message;
}
