// Edge cases of secondary-instance parsing. Expected trees were captured
// from JavaRosa 6.0.0 (jshell: CsvExternalInstance, GeoJsonExternalInstance,
// XmlExternalInstance on the same input). For inputs JavaRosa rejects, the
// expectation is the Dart exception type this port maps the Java one to:
//   IOException (also wrapped, and Jackson's) -> InstanceFormatException
//   IllegalArgumentException -> ArgumentError
//   NullPointerException / TreeElement RuntimeException -> StateError
//   kXML IOException -> FormatException
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/src/model/instance/external/csv_instance.dart';
import 'package:dartrosa/src/model/instance/external/external_instance_parser.dart';
import 'package:dartrosa/src/model/instance/external/geojson_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:test/test.dart';

/// (format, name, file content, expected tree dump or `ERR <Type>`).
const cases = <(String, String, String, String)>[
  ('csv', 'basic', 'a,b\n1,2\n', 'root[0](item[0](a[0]=<1>,b[0]=<2>))'),
  (
    'csv',
    'semicolon-crlf',
    'a;b\r\n1;2\r\n3',
    'root[0](item[0](a[0]=<1>,b[0]=<2>),item[1](a[0]=<3>,b[0]=<>))',
  ),
  ('csv', 'header-only', 'a,b\n', 'root[0]'),
  ('csv', 'empty', '', 'ERR StateError'),
  ('csv', 'dup-header', 'a,a\n1,2', 'ERR ArgumentError'),
  ('csv', 'blank-dup-header', ',\n1,2', 'ERR ArgumentError'),
  ('csv', 'one-blank-header', 'a,\n1,2', 'root[0](item[0](a[0]=<1>,[0]=<2>))'),
  (
    'csv',
    'quoted-newline',
    'name,label\n"x\ny","he said ""hi"""\n',
    'root[0](item[0](name[0]=<x\ny>,label[0]=<he said "hi">))',
  ),
  ('csv', 'bad-char-after-quote', 'a\n"x"y\n', 'ERR InstanceFormatException'),
  ('csv', 'unterminated', 'a\n"x\n', 'ERR InstanceFormatException'),
  (
    'csv',
    'empty-and-blank-lines',
    'a,b\n\n1,2\n   \n\n3,4',
    'root[0](item[0](a[0]=<1>,b[0]=<2>),item[1](a[0]=<   >,b[0]=<>),item[2](a[0]=<3>,b[0]=<4>))',
  ),
  (
    'csv',
    'trailing-delimiter',
    'a,b,\n1,2,3,4\n',
    'root[0](item[0](a[0]=<1>,b[0]=<2>,[0]=<3>))',
  ),
  (
    'csv',
    'fewer-fields',
    'a,b,c\n1\n',
    'root[0](item[0](a[0]=<1>,b[0]=<>,c[0]=<>))',
  ),
  (
    'csv',
    'semicolon-in-quoted-header',
    '\uFEFF"a;b",c\n1,2',
    'ERR InstanceFormatException',
  ),
  ('csv', 'quote-mid-token', 'a\nx"y\n', 'root[0](item[0](a[0]=<x"y>))'),
  (
    'csv',
    'space-after-quote',
    'a,b\n"x" ,y\n',
    'root[0](item[0](a[0]=<x>,b[0]=<y>))',
  ),
  ('csv', 'cr-only', 'a\r1\r2', 'root[0](item[0](a[0]=<1>),item[1](a[0]=<2>))'),
  (
    'csv',
    'bom',
    '\uFEFFname,v\nn1,é\n',
    'root[0](item[0](name[0]=<n1>,v[0]=<é>))',
  ),
  (
    'csv',
    'trailing-empty-field',
    'a,b\n1,\n',
    'root[0](item[0](a[0]=<1>,b[0]=<>))',
  ),
  (
    'geo',
    'raw-numbers',
    '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[102,0.5]},"properties":{"n":1.50,"i":77,"b":true,"z":null,"e":1e3,"neg":-0},"id":5}]}',
    'root[0](item[0](geometry[0]=<0.5 102 0 0>,n[0]=<1.50>,i[0]=<77>,b[0]=<true>,z[0]=<>,e[0]=<1e3>,neg[0]=<-0>,id[0]=<5>))',
  ),
  (
    'geo',
    'float-coords',
    '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[1.0E-7,-0.0],[3e2,12345678901234567890],[-0,"s"]]}}]}',
    'root[0](item[0](geometry[0]=<-0.0 1.0E-7 0 0; 12345678901234567890 300.0 0 0; s 0 0 0>))',
  ),
  (
    'geo',
    'geometry-unknown-field',
    '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2],"bbox":[1]}}]}',
    'ERR InstanceFormatException',
  ),
  (
    'geo',
    'property-array',
    '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"a":[1]}}]}',
    'ERR InstanceFormatException',
  ),
  (
    'geo',
    'property-object',
    '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"a":{"b":1}}}]}',
    'ERR InstanceFormatException',
  ),
  (
    'geo',
    'null-feature',
    '{"type":"FeatureCollection","features":[null]}',
    'ERR StateError',
  ),
  (
    'geo',
    'features-first-then-garbage',
    '{"features":[],"type":"FeatureCollection", garbage',
    'root[0]',
  ),
  ('geo', 'empty-object', '{}', 'ERR InstanceFormatException'),
  ('geo', 'array-top', '[]', 'ERR InstanceFormatException'),
  (
    'geo',
    'feature-without-type',
    '{"type":"FeatureCollection","features":[{"properties":{}}]}',
    'ERR StateError',
  ),
  (
    'geo',
    'geometry-property-and-id',
    '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Polygon","coordinates":[]},"properties":{"id":"p","geometry":"g","x":"1","x":"2"},"id":"top"}]}',
    'root[0](item[0](geometry[0]=<>,id[0]=<top>,geometry[0]=<g>,x[0]=<2>))',
  ),
  (
    'geo',
    'type-number',
    '{"type":"FeatureCollection","features":[{"type":5}]}',
    'ERR InstanceFormatException',
  ),
  (
    'geo',
    'trailing-comma',
    '{"type":"FeatureCollection","features":[{"type":"Feature",},]}',
    'ERR InstanceFormatException',
  ),
  (
    'geo',
    'leading-zero',
    '{"type":"FeatureCollection","features":[{"type":"Feature","id":01}]}',
    'ERR InstanceFormatException',
  ),
  (
    'xml',
    'attrs-text-cdata-comments',
    '<root a="1" xmlns:x="urn:x" x:b="2" xmlns="urn:d"><item> text </item><item/><item><!--c--></item><v> a<!--c-->b </v><w><![CDATA[ cd ]]></w><e>&amp;&#65;</e></root>',
    'root[0] @|a=1 @urn:x|b=2(item[0]=<text>,item[1],item[2],v[0]=<ab>,w[0]=<cd>,e[0]=<&A>)',
  ),
  ('xml', 'text-then-child', '<r>t<c/></r>', 'ERR StateError'),
  ('xml', 'child-then-text', '<r><c/>t</r>', 'ERR StateError'),
  ('xml', 'whitespace-only', '<r><a>  \n </a></r>', 'r[0](a[0])'),
  (
    'xml',
    'multiplicities',
    '<r><a/><b/><a/><x:a xmlns:x="u"/></r>',
    'r[0](a[0],a[1],a[2],b[0])',
  ),
  ('xml', 'nbsp', '<r><a>\u00A0x\u00A0</a></r>', 'r[0](a[0]=<\u00A0x\u00A0>)'),
  (
    'xml',
    'bom-decl',
    '\uFEFF<?xml version="1.0" encoding="ISO-8859-1"?><r><a>é</a></r>',
    'ERR FormatException',
  ),
];

/// The dump format used to capture JavaRosa's results.
String dump(TreeElement e) {
  final sb = StringBuffer('${e.name}[${e.multiplicity}]');
  for (final a in e.attributes) {
    sb.write(' @${a.namespace}|${a.name}=${a.attributeValue}');
  }
  if (e.value != null) sb.write('=<${e.value!.uncast().string}>');
  if (e.numChildren > 0) sb.write('(${e.children.map(dump).join(',')})');
  return sb.toString();
}

void main() {
  for (final (kind, name, content, expected) in cases) {
    test('$kind: $name', () {
      final bytes = Uint8List.fromList(utf8.encode(content));
      TreeElement parse() => switch (kind) {
        'csv' => const CsvExternalInstance().parse('id', bytes),
        'geo' => const GeoJsonExternalInstance().parse('id', bytes),
        _ => parseXmlExternalInstance('id', bytes),
      };
      if (expected.startsWith('ERR ')) {
        Object? error;
        try {
          parse();
        } on Object catch (e) {
          error = e;
        }
        expect(error.runtimeType.toString(), expected.substring(4));
      } else {
        expect(dump(parse()), expected);
      }
    });
  }
}
