import '../model/data/answer_value.dart';
import '../model/data_type.dart';
import '../model/form_def.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import 'instance_structure.dart';
import 'kdom.dart';
import 'xform_answer_data_parser.dart';

/// Turns a saved answer's text into a typed answer for [element].
///
/// Port of `IAnswerResolver` (JavaRosa sets it statically on the parser;
/// here it is passed to [XFormInstanceLoading.loadXmlInstance]).
typedef AnswerResolver =
    AnswerValue? Function(String text, TreeElement element, FormDef form);

/// The default [AnswerResolver]: parses [text] for the element's data
/// type. Port of `DefaultAnswerResolver`.
AnswerValue? defaultAnswerResolver(
  String text,
  TreeElement element,
  FormDef form,
) => parseAnswerData(
  text,
  element.dataType,
  questionForData(element.dataType, form, element.ref),
);

/// Filling a template instance tree from a saved one.
extension TreeElementPopulate on TreeElement {
  /// Fills this template node (and its subtree) from the saved node
  /// [incoming]: typed values, repeat instances, attributes; a missing
  /// non-repeat child becomes non-relevant. Port of
  /// `TreeElement.populate`.
  void populate(
    TreeElement incoming,
    FormDef form, {
    AnswerResolver resolver = defaultAnswerResolver,
  }) {
    if (isLeaf) {
      final value = incoming.value;
      if (value == null) {
        this.value = null;
      } else if (dataType == DataType.text || dataType == DataType.nullType) {
        this.value = value;
      } else {
        this.value = resolver(value.value as String, this, form);
      }
    } else {
      final names = <String>[];
      for (final child in children) {
        if (!names.contains(child.name)) names.add(child.name!);
      }
      // Remove the default repeat instances, keeping templates.
      for (var i = 0; i < numChildren; i++) {
        final child = childAt(i);
        if (child.isRepeatable &&
            child.multiplicity != TreeReference.indexTemplate) {
          removeChildAt(i);
          i--;
        }
      }
      // Keep the schema's order.
      if (numChildren != names.length) throw StateError('sanity check failed');
      for (var i = 0; i < numChildren; i++) {
        final child = childAt(i);
        final expectedName = names[i];
        if (child.name != expectedName) {
          var j = i + 1;
          while (j < numChildren && childAt(j).name != expectedName) {
            j++;
          }
          if (j == numChildren) throw StateError('sanity check failed');
          final child2 = childAt(j);
          removeChildAt(j);
          insertChildAt(i, child2);
        }
      }
      for (var i = 0; i < numChildren; i++) {
        final child = childAt(i);
        final newChildren = incoming.childrenWithName(child.name!);
        if (child.isRepeatable) {
          for (var k = 0; k < newChildren.length; k++) {
            final newChild = child.deepCopy(includeTemplates: true)
              ..multiplicity = k;
            insertChildAt(i + k + 1, newChild);
            newChild.populate(newChildren[k], form, resolver: resolver);
          }
          i += newChildren.length;
        } else if (newChildren.isEmpty) {
          child.isRelevant = false;
        } else {
          child.populate(newChildren.first, form, resolver: resolver);
        }
      }
    }
    for (final a in incoming.attributes) {
      setAttribute(a.namespace, a.name!, a.attributeValue);
    }
  }
}

/// Loading saved instance XML into a parsed form.
extension XFormInstanceLoading on FormDef {
  /// Replaces the main instance with the saved instance [instanceXml]
  /// (typed against the form). Port of `XFormParser.loadXmlInstance`.
  void loadXmlInstance(
    String instanceXml, {
    AnswerResolver resolver = defaultAnswerResolver,
  }) {
    final root = parseKDocument(instanceXml);
    consolidateText(root);
    final savedRoot = restoreDataModel(root).root;
    final templateRoot = mainInstance.root.deepCopy(includeTemplates: true);
    // A weak check that the instance belongs to the form.
    if (savedRoot.name != templateRoot.name || savedRoot.multiplicity != 0) {
      throw StateError(
        'Saved form instance does not match template form definition',
      );
    }
    templateRoot.populate(savedRoot, this, resolver: resolver);
    mainInstance.setRoot(templateRoot);
  }
}
