@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 ExternalSecondaryInstanceParseTest.
import 'dart:io';

import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:dartrosa/testing.dart';
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

  test(
    'items from external GeoJSON instance with integer ids can be selected',
    () async {
      final scenario = await scenarioFor('external-select-geojson.xml');
      final choiceWithIntId = scenario.choicesOf('/data/q')[1];
      scenario
        ..next()
        ..answerCurrent(choiceWithIntId);
      expect(scenario.answerOf('/data/q')!.displayText, '67');
    },
  );

  test(
    'XFormParseException when itemset value or label not in external instance',
    () async {
      await expectLater(
        Scenario.init(
          _externalCsvForm(
            'external-data.csv',
            valueRef: 'foo',
            labelRef: 'bar',
          ),
          resolver: _configuredCorrectly(),
        ),
        throwsA(isA<XFormParseException>()),
      );
    },
  );

  test(
    'CSV secondary instance with header only parses without error',
    () async {
      final scenario = await Scenario.init(
        _externalCsvForm('header_only.csv'),
        resolver: _configuredCorrectly(),
      );

      expect(scenario.choicesOf('/data/first'), hasLength(0));
    },
  );

  for (final name in [
    'form with external secondary XML instance serializes and deserializes',
    'deserialized FormDef contains the external instance',
  ]) {
    test(name, () {}, skip: 'instance/form serialization (P6)');
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

  // region Missing external file
  test(
    'empty placeholder instance is used when external instance not found',
    () async {
      final scenario = await Scenario.fromXml(
        formFile('external-select-csv.xml').readAsStringSync(),
        resolver: _configuredIncorrectly(),
      );

      expect(scenario.choicesOf('/data/first'), hasLength(0));
    },
  );

  for (final name in [
    'real instance is resolved when form is deserialized after placeholder '
        'instance used and file now exists',
    'FileNotFoundException when form is deserialized after placeholder '
        'instance used and file still missing',
    'exception from choice selection when form is deserialized after '
        'placeholder instance used and file missing columns',
  ]) {
    test(name, () {}, skip: 'instance/form serialization (P6)');
  }
  // endregion
}

/// Resolves `jr://` URIs to the folder holding the external instances.
/// Port of `configureReferenceManagerCorrectly`.
DirectoryResolver _configuredCorrectly() =>
    DirectoryResolver(formFile('external-select-csv.xml').parent);

/// Resolves `jr://` URIs to a folder that does not exist. Port of
/// `configureReferenceManagerIncorrectly`.
DirectoryResolver _configuredIncorrectly() =>
    DirectoryResolver(Directory(formFile('external-select-csv.xml').path));

/// A form with a select from `jr://file-csv/[csv]`.
XFormsElement _externalCsvForm(
  String csv, {
  String valueRef = 'value',
  String labelRef = 'label',
}) => html(
  head([
    title('Some form'),
    model([
      mainInstance([
        t('data id="some-form"', [t('first')]),
      ]),
      t('instance id="external-csv" src="jr://file-csv/$csv"'),
      bind('/data/first')..type('string'),
    ]),
  ]),
  body([
    // Define a select using value and label references that don't exist in
    // the secondary instance
    select1Dynamic(
      '/data/first',
      "instance('external-csv')/root/item",
      valueRef: valueRef,
      labelRef: labelRef,
    ),
  ]),
);
