// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (GeoJsonExternalInstanceTest), Copyright 2022 ODK;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 GeoJsonExternalInstanceTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/instance/external/geojson_instance.dart';
import 'package:dartrosa/src/model/instance/external/instance_format_exception.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:test/test.dart';

import '../../../fixtures.dart';

TreeElement parse(String resource, [String instanceId = 'id']) =>
    const GeoJsonExternalInstance().parse(instanceId, resourceBytes(resource));

final throwsIoException = throwsA(isA<InstanceFormatException>());

void main() {
  test('adds geometries as children for multiple features', () {
    final collection = parse('feature-collection.geojson');
    expect(collection.numChildren, 3);
    expect(
      collection.childAt(0).getChild('geometry', 0)!.value!.value,
      '0.5 102 0 0',
    );
    expect(
      collection.childAt(1).getChild('geometry', 0)!.value!.value,
      '0.5 104 0 0; 0.5 105 0 0',
    );
    expect(
      collection.childAt(2).getChild('geometry', 0)!.value!.value,
      '63 5 0 0; 83 10 0 0; 63 5 0 0',
    );
  });

  test('throws if there is no top-level object', () {
    expect(() => parse('not-object.geojson'), throwsIoException);
  });

  test('throws if the top-level type is not FeatureCollection', () {
    expect(() => parse('invalid-type.geojson'), throwsIoException);
  });

  test('ignores extra top-level properties', () {
    expect(
      parse('feature-collection-extra-toplevel.geojson').childAt(0).numChildren,
      3,
    );
  });

  test('accepts any top-level property order', () {
    expect(
      parse('feature-collection-toplevel-order.geojson').childAt(0).numChildren,
      3,
    );
  });

  test('throws if there is no features array', () {
    expect(() => parse('bad-futures-collection.geojson'), throwsIoException);
  });

  test('throws if features is not an array', () {
    expect(() => parse('bad-features-not-array.geojson'), throwsIoException);
  });

  test('throws if a feature is not of type Feature', () {
    expect(() => parse('bad-feature-not-feature.geojson'), throwsIoException);
  });

  test('adds all other properties as children', () {
    final collection = parse('feature-collection.geojson');
    expect(collection.childAt(0).numChildren, 4);
    expect(
      collection.childAt(0).getChild('name', 0)!.value!.value,
      'My cool point',
    );
    expect(collection.childAt(1).numChildren, 5);
    expect(
      collection.childAt(1).getChild('special-property', 0)!.value!.value,
      'special value',
    );
  });

  test('uses the top-level id', () {
    final item = parse('feature-collection-id-toplevel.geojson').childAt(0);
    expect(item.numChildren, 4);
    expect(item.getChild('id', 0)!.value!.value, 'top-level-id');
  });

  test('prioritizes the top-level id', () {
    final item = parse('feature-collection-id-twice.geojson').childAt(0);
    expect(item.numChildren, 4);
    expect(item.getChild('id', 0)!.value!.value, 'top-level-id');
  });

  test('allows an integer id', () {
    final item = parse('feature-collection-integer-id.geojson').childAt(0);
    expect(item.numChildren, 4);
    expect(item.getChild('id', 0)!.value!.value, '77');
  });

  test('ignores unknown feature-level properties', () {
    final item = parse(
      'feature-collection-extra-feature-toplevel.geojson',
    ).childAt(0);
    expect(item.numChildren, 3);
    expect(item.getChild('ignored', 0), isNull);
  });

  test('adds features with no properties', () {
    expect(
      parse('feature-collection-no-properties.geojson').childAt(0).numChildren,
      1,
    );
  });

  test('throws when the geometry is not supported', () {
    expect(
      () => parse('feature-collection-with-unsupported-type.geojson'),
      throwsIoException,
    );
  });

  test('allows null feature property values', () {
    final item = parse('feature-collection-with-null.geojson').childAt(0);
    expect(item.numChildren, 4);
    expect(item.getChild('extra', 0)!.value!.displayText, '');
  });

  test('preserves whitespace', () {
    final item = parse('spaces-in-names.geojson', 'places').childAt(0);
    expect(item.getChild('geometry', 0), isNull);
    expect(item.getChild('name', 0), isNull);
    expect(item.getChild(' name ', 0)!.value!.displayText, ' My cool point ');
    expect(item.getChild('id', 0), isNull);
    expect(item.getChild(' id ', 0)!.value!.displayText, ' fs87b ');
    expect(item.getChild('foo', 0), isNull);
    expect(item.getChild(' foo ', 0)!.value!.displayText, ' bar ');
  });
}
