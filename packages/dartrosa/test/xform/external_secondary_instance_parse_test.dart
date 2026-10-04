@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 ExternalSecondaryInstanceParseTest (the parse-only
// tests). Tests selecting choices or using placeholder instances need the
// form runner (P4/P5); serialization tests the codec (P6).
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

void main() {
  for (final (form, title, instance, count, index, child, text) in [
    (
      'external-select-xml.xml',
      'XML External Secondary Instance',
      'external-xml',
      12,
      4,
      'label',
      'AB',
    ),
    (
      'external-select-geojson.xml',
      'GeoJSON External Secondary Instance',
      'external-geojson',
      2,
      1,
      'name',
      'Your cool point',
    ),
    (
      'external-select-csv.xml',
      'CSV External Secondary Instance',
      'external-csv',
      12,
      4,
      'label',
      'AB',
    ),
  ]) {
    test('items from $instance are available to the XPath parser', () async {
      final formDef = await parseForm(form);
      expect(formDef.title, title);
      final ref = parsePathExpr(
        "instance('$instance')/root/item",
      ).toTreeReference();
      final refs = formDef.evaluationContext.expandReference(ref)!;
      expect(refs, hasLength(count));
      final item = formDef
          .nonMainInstance(instance)!
          .resolveReference(refs[index])!;
      expect(item.getChild(child, 0)!.value!.displayText, text);
    });
  }

  for (final name in [
    'items from external GeoJSON instance with integer ids can be selected',
    'XFormParseException when itemset value or label not in external instance',
    'CSV secondary instance with header only parses without error',
    'empty placeholder instance is used when external instance not found',
    'real instance is resolved when form is deserialized after placeholder',
  ]) {
    test(name, () {}, skip: 'needs the form runner (P4/P5)');
  }
  for (final name in [
    'form with external secondary XML instance serializes and deserializes',
    'deserialized FormDef contains the external instance',
  ]) {
    test(name, () {}, skip: 'Externalizable FormDef caching is a codec (P6)');
  }

  test(
    'external instance declaration is ignored when not referenced',
    () async {
      final formDef = await parseForm('unused-secondary-instance.xml');
      expect(formDef.nonMainInstance('external-csv'), isNull);
    },
  );

  test(
    'is ignored when not referenced after parsing a form with a reference',
    () async {
      final withReference = await parseForm('external-select-csv.xml');
      expect(
        withReference.nonMainInstance('external-csv')!.root!.hasChildren,
        isTrue,
      );
      final formDef = await parseForm('unused-secondary-instance.xml');
      expect(formDef.nonMainInstance('external-csv'), isNull);
    },
  );

  test('dummy nodes in external instance declaration are ignored', () async {
    final formDef = await parseForm('external-select-xml-dummy-nodes.xml');
    final ref = parsePathExpr(
      "instance('external-xml')/root/item",
    ).toTreeReference();
    expect(formDef.evaluationContext.expandReference(ref), hasLength(12));
  });
}
