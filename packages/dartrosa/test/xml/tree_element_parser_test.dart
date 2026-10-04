// Port of JavaRosa v6.0.0 TreeElementParserTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/xml/tree_element_parser.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  test('parses internal instances', () {
    final instances = parseInternalSecondaryInstances(
      javarosaResource('secondary-instance.xml').readAsStringSync(),
    );
    expect(instances, hasLength(1));
    final towns = instances.first;
    expect(towns.instanceName, 'towns');
    expect(towns.numChildren, 1); // only one root node: <towndata z="1">
    expect(towns.childAt(0).numChildren, 1); // only one <data_set>
    expect(towns.childAt(0).childAt(0).value!.displayText, 'us_east');
  });

  test('does not include external instances', () {
    final instances = parseInternalSecondaryInstances(
      javarosaResource('external-select-xml.xml').readAsStringSync(),
    );
    expect(instances, isEmpty);
  });

  test('does not include the primary instance when it has an id', () {
    final instances = parseInternalSecondaryInstances(
      javarosaResource('primary-instance-with-id.xml').readAsStringSync(),
    );
    expect(instances, hasLength(1));
  });

  test('buildInternalInstances keys FormInstances by id', () {
    final instances = buildInternalInstances(
      javarosaResource('secondary-instance.xml').readAsStringSync(),
    );
    expect(instances.keys, ['towns']);
    expect(instances['towns']!.root!.name, 'towndata');
  });
}
