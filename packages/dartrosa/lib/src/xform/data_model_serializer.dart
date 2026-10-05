import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import 'kxml_writer.dart';

/// Writes an instance (or the subtree at a reference) as plain XML: no XML
/// declaration, no namespace declarations beyond kXML's automatic ones, the
/// root's attributes left out, non-relevant nodes and repeat templates left
/// out, and every value written uncast.
///
/// Port of `org.javarosa.model.xform.DataModelSerializer` (which writes to
/// a stream through kXML's `KXmlSerializer`); returns the XML instead.
final class DataModelSerializer {
  /// Creates a serializer.
  const DataModelSerializer();

  /// [instance] from its root, or from the node at [base], as XML.
  String serialize(DataInstance instance, [TreeReference? base]) {
    final root = base == null
        ? instance.root!
        : instance.resolveReference(base)!;
    final element = KxmlElement()
      ..name = root.name
      ..namespace = root.namespace;
    for (var i = 0; i < root.numChildren; i++) {
      final child = serializeNode(root.childAt(i));
      if (child != null) element.children.add(child);
    }
    final out = StringBuffer();
    KxmlWriter(out).write(element);
    return out.toString();
  }

  /// The element for [instanceNode], or `null` for a non-relevant node or
  /// a repeat template.
  KxmlElement? serializeNode(TreeElement instanceNode) {
    // don't serialize template nodes or non-relevant nodes
    if (!instanceNode.isRelevant ||
        instanceNode.multiplicity == TreeReference.indexTemplate) {
      return null;
    }
    final element = KxmlElement()
      ..name = instanceNode.name
      ..namespace = instanceNode.namespace;
    for (final attribute in instanceNode.attributes) {
      element.attributes.add((
        attribute.namespace,
        attribute.name!,
        attribute.attributeValue ?? '',
      ));
    }
    final value = instanceNode.value;
    if (value != null) {
      element.children.add(value.uncast().string);
    } else {
      for (var i = 0; i < instanceNode.numChildren; i++) {
        final child = serializeNode(instanceNode.childAt(i));
        if (child != null) element.children.add(child);
      }
    }
    return element;
  }
}
