// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XFormSerializingVisitor, XFormSerializer), Copyright
//  (C) 2009 JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../util/java_lang.dart';
import 'kxml_writer.dart';
import 'xform_answer_data_serializer.dart';

/// Serializes a form instance to XForms submission XML, exactly as
/// JavaRosa does (byte for byte, including kXML's escaping, namespace
/// prefixes and ` />` empty elements).
///
/// Port of `org.javarosa.model.xform.XFormSerializingVisitor` with
/// `XFormSerializer.getUtfBytes`. Non-relevant nodes are left out unless
/// not [respectRelevance] (drafts); repeat templates always are.
final class XFormSerializingVisitor {
  /// Creates a serializer.
  XFormSerializingVisitor({this.respectRelevance = true});

  /// Whether non-relevant nodes are left out.
  final bool respectRelevance;

  final List<DataPointer> _dataPointers = [];

  /// The attachments referenced by the last serialized instance.
  List<DataPointer> get dataPointers => List.unmodifiable(_dataPointers);

  /// [instance] as UTF-8 XML, from the node at [root] (the instance root
  /// by default).
  Uint8List serializeInstance(FormInstance instance, {TreeReference? root}) =>
      Uint8List.fromList(
        utf8.encode(serializeInstanceToString(instance, root: root)),
      );

  /// [instance] as an XML string, from the node at [root] (the instance
  /// root by default).
  String serializeInstanceToString(
    FormInstance instance, {
    TreeReference? root,
  }) {
    _dataPointers.clear();
    final rootNode =
        (root == null ? null : instance.resolveReference(root)) ??
        instance.root;
    final top = _serializeNode(rootNode);
    final out = StringBuffer("<?xml version='1.0' encoding='UTF-8' ?>");
    if (top != null) {
      // Declared on the top element in JavaRosa's (HashMap) order, then
      // the schema as default namespace.
      for (final prefix in javaHashMapOrder(instance.namespaces.keys)) {
        top.declarations.add((prefix, instance.namespaces[prefix]!));
      }
      final schema = instance.schema;
      if (schema != null) {
        top
          ..namespace = schema
          ..declarations.add(('', schema));
      }
      KxmlWriter(out).write(top);
    }
    return out.toString();
  }

  KxmlElement? _serializeNode(TreeElement node) {
    if ((respectRelevance && !node.isRelevant) ||
        node.multiplicity == TreeReference.indexTemplate) {
      return null;
    }
    final e = KxmlElement();
    final value = node.value;
    if (value != null) {
      final Object? serialized;
      try {
        serialized = serializeAnswerData(value);
      } on Object catch (ex) {
        throw StateError('Unable to serialize $value. Exception: $ex');
      }
      switch (serialized) {
        case final List<Object?> names:
          // Several attachments: one <data> child each.
          for (final name in names) {
            e.children.add(
              KxmlElement()
                ..name = 'data'
                ..children.add('$name'),
            );
          }
        case final String text:
          e.children.add(text);
        default:
          throw StateError(
            "Can't handle serialized output for$value, $serialized",
          );
      }
      switch (value) {
        case PointerValue(:final pointer):
          _dataPointers.add(pointer);
        case MultiPointerValue(:final pointers):
          _dataPointers.addAll(pointers);
        default:
          break;
      }
    } else {
      final childNames = <String>[];
      for (final child in node.children) {
        if (!childNames.contains(child.name)) childNames.add(child.name!);
      }
      for (final childName in childNames) {
        final count = node.childMultiplicity(childName);
        for (var j = 0; j < count; j++) {
          final child = _serializeNode(node.getChild(childName, j)!);
          if (child != null) e.children.add(child);
        }
      }
    }
    e.name = node.name;
    for (final a in node.attributes) {
      e.attributes.add((a.namespace, a.name!, a.attributeValue ?? ''));
    }
    final namespace = node.namespace;
    if (namespace != null) e.namespace = namespace;
    return e;
  }
}
