// TreeReference behaviour beyond JavaRosa's TreeReference*Test suites
// (ported in tree_reference_suites_test.dart).
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  group('toString', () {
    test('prints 1-based multiplicities and special markers', () {
      expect(getRef('/data/child[2]/name').toString(), '/data/child[2]/name');
      expect(getRef('/data[1]/a[1]').toString(), '/data/a[1]');
      expect(getRef('/data/r[@template]').toString(), '/data/r[@template]');
      expect(getRef('/data/@id').toString(), '/data/@id');
      expect(getRef('../../x').toString(), '../../x');
      expect(
        getRef("instance('towns')/root/item").toString(),
        'instance(towns)/root/item',
      );
      // JavaRosa prints no slash after current() for relative paths.
      expect(getRef('current()/../x').toString(), 'current()../x');
      expect(
        getRef('/data/child[2]').toString(zeroIndexMultiplicity: true),
        '/data/child[1]',
      );
    });
  });

  group('intersect and subReference', () {
    test('intersect returns the common prefix', () {
      expect(getRef('/a/b/c').intersect(getRef('/a/b/d/e')), getRef('/a/b'));
      expect(
        getRef('/a/b').intersect(getRef('/x/y')),
        const TreeReference.root(),
      );
      expect(
        getRef('a/b').intersect(getRef('/a/b')),
        const TreeReference.root(),
      );
    });

    test('subReference keeps steps up to the level', () {
      expect(getRef('/a/b/c').subReference(1), getRef('/a/b'));
    });
  });

  test('fromRef round-trips through toTreeReference', () {
    final ref = getRef('/data/*/name');
    expect(XPathPathExpr.fromRef(ref).toTreeReference(), ref);
  });
}
