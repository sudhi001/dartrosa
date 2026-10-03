import '../i18n/localizer.dart';
import '../xpath/expression.dart';
import 'condition/conditions.dart';
import 'form_def.dart';
import 'form_element.dart';
import 'instance/tree_reference.dart';

/// The `<itemset>` of a select question: where its choices come from.
///
/// Port of `org.javarosa.core.model.ItemsetBinding`. This holds what the
/// parser sets up; computing the choices at runtime is added in Phase 5.
final class ItemsetBinding implements Localizable {
  /// Absolute reference of the source nodes.
  TreeReference? nodesetRef;

  /// Path expression for the source nodes; may be relative and have
  /// predicates (the choice filter).
  XPathConditional? nodesetExpr;

  /// Context of [nodesetExpr]: the question's reference.
  TreeReference? contextRef;

  /// Absolute reference of the label.
  TreeReference? labelRef;

  /// Path expression for the label, relative to a source node.
  XPathConditional? labelExpr;

  /// Whether the label is an itext id (`jr:itext(path)`).
  bool labelIsItext = false;

  /// Absolute reference of the value.
  TreeReference? valueRef;

  /// Path expression for the value.
  XPathConditional? valueExpr;

  TreeReference? _destRef;

  /// The question's reference (plus the copied node in copy mode).
  TreeReference? get destRef => _destRef;

  bool _limitValueToSelectChoices = true;

  /// Whether answers without a matching choice are cleared.
  bool get limitValueToSelectChoices => _limitValueToSelectChoices;

  /// Whether the choices are shuffled (`randomize(...)`).
  bool randomize = false;

  /// The `randomize()` seed expression, if any.
  XPathExpression? randomSeedExpr;

  /// Deprecated `<copy>` mode: copy subtrees instead of values.
  bool copyMode = false;

  /// Deprecated `<copy>` expression.
  XPathConditional? copyExpr;

  /// Deprecated `<copy>` absolute reference.
  TreeReference? copyRef;

  /// Computes the absolute references once the instance exists; with
  /// [question] (on the second pass) also the destination reference.
  void initReferences(QuestionDef? question) {
    nodesetRef = _absoluteRef(nodesetExpr!, contextRef!);
    if (labelExpr != null) labelRef = _absoluteRef(labelExpr!, nodesetRef!);
    if (copyExpr != null) copyRef = _absoluteRef(copyExpr!, nodesetRef!);
    if (valueExpr != null) valueRef = _absoluteRef(valueExpr!, nodesetRef!);
    if (question != null) {
      var dest = question.bind!;
      if (copyMode) {
        dest = dest.extend(copyRef!.lastName, TreeReference.indexUnbound);
      }
      _destRef = dest;
      _limitValueToSelectChoices = question.shouldLimitValueToSelectChoices;
    }
  }

  static TreeReference _absoluteRef(
    XPathConditional expression,
    TreeReference base,
  ) => FormDef.getAbsRef(
    (expression.expr as XPathPathExpr).toTreeReference(),
    base,
  );

  @override
  void localeChanged(String locale, Localizer localizer) {}
}
