import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/external/external_instance_parser.dart';
import 'package:dartrosa/src/model/instance/external_data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

final resolver = MapResourceResolver({
  'jr://file/towns.xml': bytes('<root><item><name>Lyon</name></item></root>'),
  'jr://file-csv/towns.csv': bytes('name,label\nlyon,Lyon\n'),
  'jr://file/towns.geojson': bytes(
    '{"type":"FeatureCollection","features":[{"type":"Feature",'
    '"geometry":{"type":"Point","coordinates":[4.8,45.7]},'
    '"properties":{"name":"Lyon"}}]}',
  ),
  'jr://file-csv/empty.csv': bytes('name,label\n'),
});

/// Supplies `people` with a partial element first, then the full data.
final class _People implements InstanceProvider {
  int fullLoads = 0;

  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      instanceSrc == 'jr://file-csv/people.csv';

  @override
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) {
    if (!partial) fullLoads++;
    final root = TreeElement('root')..instanceName = instanceId;
    final item = TreeElement('item', 0, partial);
    if (!partial) {
      item.addChild(TreeElement('name')..value = const StringValue('Ada'));
    }
    return root..addChild(item);
  }
}

void main() {
  test('dispatches on src: XML, CSV and GeoJSON', () async {
    final xml = await ExternalDataInstance.build(
      resolver,
      'jr://file/towns.xml',
      'x',
    );
    final csv = await ExternalDataInstance.build(
      resolver,
      'jr://file-csv/towns.csv',
      'c',
    );
    final geo = await ExternalDataInstance.build(
      resolver,
      'jr://file/towns.geojson',
      'g',
    );
    expect(
      xml.resolveReference(getRef("instance('x')/root/item/name"))!.value,
      const UncastValue('Lyon'),
    );
    expect(
      csv.resolveReference(getRef("instance('c')/root/item/label"))!.value,
      const UncastValue('Lyon'),
    );
    expect(
      geo.resolveReference(getRef("instance('g')/root/item/geometry"))!.value,
      const UncastValue('45.7 4.8 0 0'),
    );
    expect(csv.name, 'c');
    expect(csv.instanceId, 'c');
    expect(csv.path, 'jr://file-csv/towns.csv');
    expect(csv.root.instanceName, 'c');
    expect(csv.isUsingPlaceholder, isFalse);
  });

  test('a missing or empty file uses the placeholder', () async {
    final missing = await ExternalDataInstance.build(
      resolver,
      'jr://file/nope.xml',
      'm',
    );
    expect(missing.isUsingPlaceholder, isTrue);
    expect(missing.root.name, ExternalDataInstance.placeholderName);
    final empty = await ExternalDataInstance.build(
      resolver,
      'jr://file-csv/empty.csv',
      'e',
    );
    expect(empty.isUsingPlaceholder, isTrue);
  });

  test('ExternalInstanceParser rethrows a missing file', () {
    expect(
      ExternalInstanceParser().parse(resolver, 'm', 'jr://file/nope.xml'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('registered file parsers take precedence', () async {
    final parser = ExternalInstanceParser()..addFileInstanceParser(_Upper());
    final root = await parser.parse(resolver, 'c', 'jr://file-csv/towns.csv');
    expect(root.name, 'UPPER');
  });

  test(
    'providers supply partial instances that load fully on demand',
    () async {
      final people = _People();
      final parser = ExternalInstanceParser()..addInstanceProvider(people);
      final instance = await ExternalDataInstance.build(
        MapResourceResolver({}),
        'jr://file-csv/people.csv',
        'people',
        parser: parser,
      );
      expect(people.fullLoads, 0);
      // Resolving the partial element itself triggers the full load (as in
      // JavaRosa's InstancePluginTest); a child of a partial element simply
      // isn't found.
      expect(
        instance.resolveReference(getRef("instance('people')/root/item/name")),
        isNull,
      );
      final item = instance.resolveReference(
        getRef("instance('people')/root/item[1]"),
      );
      expect(item!.isPartial, isFalse);
      expect(people.fullLoads, 1);
      expect(
        instance
            .resolveReference(getRef("instance('people')/root/item/name"))!
            .value,
        const StringValue('Ada'),
      );
    },
  );
}

final class _Upper implements FileInstanceParser {
  @override
  bool isSupported(String instanceId, String instanceSrc) => true;

  @override
  TreeElement parse(
    String instanceId,
    Uint8List bytes, {
    bool partial = false,
  }) => TreeElement('UPPER');
}
