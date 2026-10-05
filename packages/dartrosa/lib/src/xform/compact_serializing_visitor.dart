import 'dart:convert';
import 'dart:typed_data';

import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../util/java_lang.dart';
import 'xform_answer_data_serializer.dart';
import 'xform_parser.dart' show namespaceOdk;

/// Serializes the answers of an instance into a compact (SMS) text: the
/// root's `odk:prefix`, then `tag value` pairs for every leaf with an
/// `odk:tag` attribute, separated by the root's `odk:delimiter` (a space by
/// default; a delimiter or backslash in a value is escaped with a
/// backslash).
///
/// Port of `org.javarosa.model.xform.CompactSerializingVisitor`. As in
/// JavaRosa the text is kept between calls: serializing again with a root
/// that has no prefix appends to the previous text.
final class CompactSerializingVisitor {
  /// Creates a serializer.
  CompactSerializingVisitor();

  String _resultText = '';
  String _delimiter = ' ';

  /// The text of [instance], encoded in UTF-16BE (the default for complex
  /// messages).
  Uint8List serializeInstance(FormInstance instance) {
    _visit(instance);
    return javaUtf16Bytes(_resultText);
  }

  /// The text of [instance], encoded in UTF-8 (JavaRosa's SMS
  /// `ByteArrayPayload`).
  Uint8List createSerializedPayload(FormInstance instance) {
    _visit(instance);
    return Uint8List.fromList(utf8.encode(_resultText));
  }

  /// The text of [instance].
  String serializeInstanceToString(FormInstance instance) {
    _visit(instance);
    return _resultText;
  }

  void _visit(FormInstance tree) {
    final root = tree.root;
    final delimiter = root.getAttributeValue(namespaceOdk, 'delimiter');
    final prefix = root.getAttributeValue(namespaceOdk, 'prefix');
    _delimiter = delimiter ?? ' ';
    if (prefix != null) _resultText = '$prefix$_delimiter';
    // serialize each node (and its children) to get its answers
    _resultText += _serializeTreeToString(root);
  }

  String _serializeTreeToString(TreeElement root) {
    final sb = StringBuffer();
    _serializeTree(root, sb);
    return javaTrim(sb.toString());
  }

  void _serializeTree(TreeElement root, StringBuffer sb) {
    for (var j = 0; j < root.numChildren; j++) {
      final treeElement = root.childAt(j);
      if (treeElement.isLeaf &&
          treeElement.getAttribute(namespaceOdk, 'tag') != null) {
        final result = serializeNode(treeElement);
        if (result != null) sb.write(result);
      } else {
        _serializeTree(treeElement, sb);
      }
    }
  }

  /// The `tag value ` text of the leaf [instanceNode]: empty without an
  /// answer, `null` when non-relevant or a repeat template.
  String? serializeNode(TreeElement instanceNode) {
    // don't serialize template nodes or non-relevant nodes
    if (!instanceNode.isRelevant ||
        instanceNode.multiplicity == TreeReference.indexTemplate) {
      return null;
    }
    final sb = StringBuffer();
    final value = instanceNode.value;
    if (value != null) {
      final serializedAnswer = serializeAnswerData(value);
      if (serializedAnswer is! String) {
        throw StateError(
          "Can't handle serialized output for $value, $serializedAnswer",
        );
      }
      final tag = instanceNode.getAttributeValue(namespaceOdk, 'tag');
      sb
        ..write(tag)
        ..write(_delimiter)
        ..write(
          serializedAnswer
              .replaceAll(r'\', r'\\')
              .replaceAll(_delimiter, '\\$_delimiter'),
        )
        ..write(_delimiter);
    }
    return sb.toString();
  }
}
