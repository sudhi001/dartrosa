import 'dart:convert';
import 'dart:typed_data';

import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../util/java_lang.dart';
import 'kdom.dart';
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
      _Writer(out).write(top);
    }
    return out.toString();
  }

  _Node? _serializeNode(TreeElement node) {
    if ((respectRelevance && !node.isRelevant) ||
        node.multiplicity == TreeReference.indexTemplate) {
      return null;
    }
    var e = _Node();
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
          e = _Node();
          for (final name in names) {
            e.children.add(
              _Node()
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

/// An output element: kdom's `Element` as JavaRosa builds it (a `null`
/// namespace writes the bare name).
final class _Node {
  String? name;
  String? namespace;
  final List<(String?, String, String)> attributes = [];
  final List<(String, String)> declarations = [];
  final List<Object> children = [];
}

/// kXML's `KXmlSerializer` writing a kdom document in UTF-8.
final class _Writer {
  _Writer(this._out);

  final StringBuffer _out;
  final List<Map<String, String>> _scopes = [{}];
  var _auto = 0;

  String? _boundPrefix(String namespace) {
    for (final scope in _scopes.reversed) {
      final prefix = scope[namespace];
      if (prefix != null) return prefix;
    }
    return null;
  }

  String _prefixFor(String namespace, List<(String, String)> declare) {
    final bound = _boundPrefix(namespace);
    if (bound != null) return bound;
    final prefix = 'n${_auto++}';
    _scopes.last[namespace] = prefix;
    declare.add((prefix, namespace));
    return prefix;
  }

  String _qualified(
    String? namespace,
    String name,
    List<(String, String)> declare,
  ) {
    if (namespace == null) return name;
    final prefix = _prefixFor(namespace, declare);
    return prefix.isEmpty ? name : '$prefix:$name';
  }

  void write(_Node node) {
    final scope = <String, String>{};
    _scopes.add(scope);
    final declare = <(String, String)>[];
    for (final (prefix, uri) in node.declarations) {
      scope[uri] = prefix;
      declare.add((prefix, uri));
    }
    final name = _qualified(node.namespace, node.name ?? '', declare);
    _out.write('<$name');
    for (final (namespace, attrName, value) in node.attributes) {
      final qualified = namespace == null || namespace.isEmpty
          ? attrName
          : _qualified(namespace, attrName, declare);
      final quote = value.contains('"') ? "'" : '"';
      _out.write(' $qualified=$quote');
      kxmlEscape(_out, value, quote, unicode: true);
      _out.write(quote);
    }
    for (final (prefix, uri) in declare) {
      _out.write(prefix.isEmpty ? ' xmlns="' : ' xmlns:$prefix="');
      kxmlEscape(_out, uri, '"', unicode: true);
      _out.write('"');
    }
    if (node.children.isEmpty) {
      _out.write(' />');
    } else {
      _out.write('>');
      for (final child in node.children) {
        switch (child) {
          case final _Node element:
            write(element);
          case final String text:
            kxmlEscape(_out, text, null, unicode: true);
        }
      }
      _out.write('</$name>');
    }
    _scopes.removeLast();
  }
}
