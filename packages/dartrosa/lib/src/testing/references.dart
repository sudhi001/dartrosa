import '../model/instance/tree_reference.dart';
import '../xpath/expression.dart';
import '../xpath/parser.dart';

/// Parses [xpath] into a [TreeReference], turning numeric predicates into
/// multiplicities: `/data/child[2]` refers to the second `child`
/// (multiplicity 1), `[-1]` means unbound and `[@template]` the template.
///
/// To compare with references from the engine, give every step a
/// multiplicity (`/data/q[1]`), because a step without one could be an
/// unbound repeat.
///
/// Port of `org.javarosa.test.Scenario.getRef`.
TreeReference getRef(String xpath) {
  if (xpath.trim().isEmpty) return const TreeReference.relative();
  var ref = (parseXPath(xpath) as XPathPathExpr).toTreeReference();
  for (var i = 0; i < ref.size; i++) {
    final multiplicity = _multiplicityFromPredicate(ref.predicatesAt(i));
    if (multiplicity != null) {
      ref = ref.withMultiplicity(i, multiplicity).removePredicates(i);
    }
  }
  return ref;
}

int? _multiplicityFromPredicate(List<XPathExpression>? predicates) {
  if (predicates == null || predicates.length != 1) return null;
  return switch (predicates.single) {
    XPathNumericLiteral(:final value) => (value - 1).toInt(),
    XPathNumNegExpr(a: XPathNumericLiteral(:final value)) => -value.toInt(),
    XPathPathExpr(
      start: PathStart.relative,
      steps: [XPathStep(axis: XPathAxis.attribute, name: final name?)],
    )
        when name.name == 'template' =>
      TreeReference.indexTemplate,
    _ => null,
  };
}
