// DartRosa tests (not ports) of XPathNodeset's lazy and invalid-path
// variants (JavaRosa's public XPathLazyNodeset and
// XPathNodeset.ConstructInvalidPathNodeset, which the engine itself doesn't
// construct). JavaRosa has no tests for these; every expectation was
// captured from JavaRosa 6.0.0 (jshell, on the same instance).
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/src/xpath/nodeset.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

const form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>NS</h:title><model>
<instance><data id="ns"><one>v1</one><hidden>secret</hidden><r><f>1</f><a>x</a></r><r><f>0</f><a>y</a></r><r><f>1</f><a>z</a></r><empty/></data></instance>
<bind nodeset="/data/hidden" relevant="false()"/>
<bind nodeset="/data/r/a" relevant="../f = 1"/>
</model></h:head>
<h:body><input ref="/data/one"><label>One</label></input></h:body></h:html>
''';

Matcher mismatch(String detail) => throwsA(
  isA<XPathTypeMismatchException>().having(
    (e) => e.toString(),
    'message',
    contains(detail),
  ),
);

void main() {
  late FormDef formDef;

  setUpAll(() async {
    formDef = await XFormParser().parse(form);
    formDef.initialize(newInstance: true);
  });

  XPathNodeset lazy(String path) => XPathNodeset.lazy(
    (parseXPath(path) as XPathPathExpr).toTreeReference(),
    formDef.mainInstance,
    formDef.evaluationContext,
  );

  group('lazy nodeset', () {
    test('a single node unpacks without expansion', () {
      expect(lazy('/data/one').unpack(), 'v1');
      final nodeset = lazy('/data/one');
      expect(nodeset.size, 1);
      expect(nodeset.toArgList(), ['v1']);
      expect(nodeset.references!.map((r) => '$r'), ['/data/one[1]']);
      expect('${nodeset.refAt(0)} ${nodeset.valueAt(0)}', '/data/one[1] v1');
      expect(nodeset.nonEmptySize, 1);
      // Once expanded, unpack uses the references.
      expect(nodeset.unpack(), 'v1');
    });

    test('non-relevant nodes are filtered out', () {
      expect(lazy('/data/hidden').unpack(), '');
      final nodeset = lazy('/data/hidden');
      expect(nodeset.size, 0);
      expect(nodeset.toArgList(), isEmpty);
      expect(nodeset.references, isEmpty);
      expect(nodeset.nonEmptySize, 0);
    });

    test('several nodes are expanded and cannot be unpacked', () {
      expect(
        () => lazy('/data/r/a').unpack(),
        mismatch(
          'This field is repeated: \n\n/data/r[1]/a[1];/data/r[3]/a[1]\n\n'
          'You may need to use the indexed-repeat() function',
        ),
      );
      final nodeset = lazy('/data/r/a');
      expect(nodeset.size, 2);
      expect(nodeset.toArgList(), ['x', 'z']);
      expect(nodeset.references!.map((r) => '$r'), [
        '/data/r[1]/a[1]',
        '/data/r[3]/a[1]',
      ]);
      expect(lazy('/data/r/a').nodeContents, '/data/r[1]/a[1];/data/r[3]/a[1]');
      expect(nodeset.nonEmptySize, 2);
    });

    test('predicates are expanded', () {
      expect(lazy('/data/r[2]/a').unpack(), '');
      expect(lazy('/data/r[2]/a').size, 0);
      expect(lazy('/data/r[position()=1]/a').unpack(), 'x');
      final nodeset = lazy('/data/r[position()=1]/a');
      expect(nodeset.references!.map((r) => '$r'), ['/data/r[1]/a[1]']);
      expect(nodeset.valueAt(0), 'x');
    });

    test('missing and empty nodes', () {
      expect(lazy('/data/missing').unpack(), '');
      expect(lazy('/data/missing').size, 0);
      expect(lazy('/data/empty').unpack(), '');
      final empty = lazy('/data/empty');
      expect(empty.size, 1);
      expect(empty.toArgList(), ['']);
      expect(empty.nonEmptySize, 0);
    });
  });

  group('invalid path nodeset', () {
    final relative = XPathNodeset.invalidPath('/data/x', 'x');
    final absolute = XPathNodeset.invalidPath('/data/x', '/data/x');

    test('access fails naming the path', () {
      const message =
          'The path x refers to the location /data/x which was not found';
      expect(relative.unpack, mismatch(message));
      expect(relative.toArgList, mismatch(message));
      expect(() => relative.refAt(0), mismatch(message));
      expect(absolute.unpack, mismatch('Location /data/x was not found'));
    });

    test('it is empty', () {
      expect(relative.size, 0);
      expect(relative.nonEmptySize, 0);
      expect(relative.references, isNull);
      expect(relative.nodeContents, 'Invalid Path: /data/x');
    });
  });
}
