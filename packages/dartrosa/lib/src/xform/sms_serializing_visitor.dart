import 'dart:typed_data';

import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../util/java_lang.dart';
import 'xform_answer_data_serializer.dart';

/// Serializes the answers of an instance into SMS text: the node's
/// `prefix` attribute, then `tag value` pairs for its direct children,
/// separated by its `delimiter` (or misspelt `delimeter`) attribute (a
/// space by default; values are not escaped).
///
/// Port of `org.javarosa.model.xform.SMSSerializingVisitor`, deprecated in
/// JavaRosa. As in JavaRosa the node defaults to `/`, which resolves to no
/// node, so serializing fails (a [StateError]; a `NullPointerException` in
/// JavaRosa) unless a `root` reference such as `/data` is given.
@Deprecated('Deprecated in JavaRosa; use CompactSerializingVisitor')
final class SMSSerializingVisitor {
  /// Creates a serializer.
  SMSSerializingVisitor();

  String _smsText = '';
  String _delimiter = ' ';
  final List<DataPointer> _dataPointers = [];

  /// The attachments referenced by the last serialized instance.
  List<DataPointer> get dataPointers => List.unmodifiable(_dataPointers);

  /// The text of [instance] from the node at [root] (`/` by default),
  /// encoded in UTF-16BE (the default for complex messages).
  Uint8List serializeInstance(FormInstance instance, {TreeReference? root}) =>
      javaUtf16Bytes(serializeInstanceToString(instance, root: root));

  /// The text of [instance] from the node at [root] (`/` by default),
  /// encoded in UTF-16 with a byte order mark (JavaRosa's SMS
  /// `ByteArrayPayload`).
  Uint8List createSerializedPayload(
    FormInstance instance, {
    TreeReference? root,
  }) => javaUtf16Bytes(
    serializeInstanceToString(instance, root: root),
    bom: true,
  );

  /// The text of [instance] from the node at [root] (`/` by default).
  String serializeInstanceToString(
    FormInstance instance, {
    TreeReference? root,
  }) {
    _smsText = '';
    _dataPointers.clear();
    _visit(instance, root ?? const TreeReference.root());
    return _smsText;
  }

  void _visit(FormInstance tree, TreeReference rootRef) {
    final root =
        tree.resolveReference(rootRef) ??
        (throw StateError('No node at $rootRef to serialize'));
    final delimiter =
        root.getAttributeValue('', 'delimiter') ??
        // for the spelling-impaired...
        root.getAttributeValue('', 'delimeter');
    final prefix = root.getAttributeValue('', 'prefix');
    _delimiter = delimiter ?? ' ';
    // Don't bother adding any delimiters, yet. Delimiters are added before
    // tags/data
    final sms = StringBuffer(prefix ?? ' ');
    // serialize each node to get it's answers
    for (var j = 0; j < root.numChildren; j++) {
      final e = serializeNode(root.childAt(j));
      if (e != null) sms.write(e);
    }
    _smsText = javaTrim(sms.toString());
  }

  /// The `tag value ` text of [instanceNode]: empty without an answer,
  /// `null` when non-relevant or a repeat template.
  String? serializeNode(TreeElement instanceNode) {
    final b = StringBuffer();
    // don't serialize template nodes or non-relevant nodes
    if (!instanceNode.isRelevant ||
        instanceNode.multiplicity == TreeReference.indexTemplate) {
      return null;
    }
    final value = instanceNode.value;
    if (value != null) {
      final serializedAnswer = serializeAnswerData(value);
      if (serializedAnswer is! String) {
        throw StateError(
          "Can't handle serialized output for $value, $serializedAnswer",
        );
      }
      final tag = instanceNode.getAttributeValue('', 'tag');
      if (tag != null) b.write(tag);
      b
        ..write(_delimiter)
        ..write(serializedAnswer)
        ..write(_delimiter);
      switch (value) {
        case PointerValue(:final pointer):
          _dataPointers.add(pointer);
        case MultiPointerValue(:final pointers):
          _dataPointers.addAll(pointers);
        default:
          break;
      }
    }
    return b.toString();
  }
}
