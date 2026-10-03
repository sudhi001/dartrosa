// Port of JavaRosa v6.0.0 TreeReference{Parent,Equals,Genericize,
// AnchorHarness,Anchor,Contextualize,IsAncestorOf}Test.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  group('parent', () {
    const cases = [
      ("Parenting absolute refs doesn't change them", '/foo', '/bar', '/foo'),
      ("Parenting to an empty ref doesn't change them", '../foo', '', '../foo'),
      ('foo.parent(bar) gives bar/foo', 'foo', 'bar', 'bar/foo'),
      ('foo.parent(../bar) gives ../bar/foo', 'foo', '../bar', '../bar/foo'),
      ('../foo.parent(bar/baz) gives null', '../foo', 'bar/baz', null),
      ('../../a.parent(..) gives ../../../a', '../../a', '..', '../../../a'),
    ];
    for (final (name, ref, base, expected) in cases) {
      test(name, () {
        expect(
          getRef(ref).parent(getRef(base)),
          expected == null ? isNull : getRef(expected),
        );
      });
    }
  });

  group('equals', () {
    const cases = [
      ('same path in primary instance', '/foo/bar', '/foo/bar', true),
      (
        'same path in secondary instance',
        "instance('foo')/bar/baz",
        "instance('foo')/bar/baz",
        true,
      ),
      (
        'same path in primary and secondary instance',
        '/foo/bar',
        "instance('foo')/foo/bar",
        false,
      ),
      (
        'same path in secondary and primary instance',
        "instance('foo')/foo/bar",
        '/foo/bar',
        false,
      ),
      (
        'same path in different secondary instances',
        "instance('foo')/foo/bar",
        "instance('bar')/foo/bar",
        false,
      ),
      (
        'different paths in primary instance',
        '/foo/bar',
        '/foo/bar/quux',
        false,
      ),
      (
        'different paths in secondary instance',
        "instance('foo')/foo/bar",
        "instance('foo')/foo/bar/quux",
        false,
      ),
    ];
    for (final (name, a, b, equal) in cases) {
      test(name, () {
        expect(getRef(a) == getRef(b), equal);
        if (equal) expect(getRef(a).hashCode, getRef(b).hashCode);
      });
    }
  });

  test('genericize sets all steps to unbound multiplicity', () {
    expect(getRef('/foo/bar').genericize(), getRef('/foo/bar'));
    final original = getRef('/foo[3]/bar[4]');
    expect(original.multiplicityAt(0), 2);
    expect(original.multiplicityAt(1), 3);
    final generic = original.genericize();
    for (var i = 0; i < original.size; i++) {
      expect(generic.multiplicityAt(i), -1);
    }
  });

  group('anchor', () {
    for (final (ref, base) in const [('foo', '/bar'), ('/foo', '/bar')]) {
      test('$ref.anchor($base) equals parent', () {
        expect(
          getRef(ref).anchor(getRef(base)),
          getRef(ref).parent(getRef(base)),
        );
      });
    }

    test('a relative ref can be anchored to an absolute ref', () {
      expect(getRef('baz').anchor(getRef('/foo/bar')), getRef('/foo/bar/baz'));
    });

    test('anchoring to a relative ref throws', () {
      expect(
        () => getRef(
          'some/relative/path',
        ).anchor(getRef('some/other/relative/path')),
        throwsA(isA<XPathException>()),
      );
    });

    test('anchoring to a too shallow base throws', () {
      expect(
        () => getRef('../../../bar').anchor(getRef('/foo/bar')),
        throwsA(isA<XPathException>()),
      );
    });

    test('otherwise it returns an absolute ref', () {
      expect(getRef('../baz').anchor(getRef('/foo/bar')), getRef('/foo/baz'));
    });

    test('anchoring an absolute ref has no effect on it', () {
      final ref = getRef('/some/absolute/ref');
      expect(ref.anchor(getRef('/some/other/absolute/ref')), ref);
    });
  });

  group('contextualize', () {
    const cases = [
      ('Relative context ref', 'bar', 'foo', null),
      ('Non-matching absolute refs', '/foo', '/bar', '/foo'),
      ('itself and multiplicity #1', '/foo', '/foo[2]', '/foo[2]'),
      ('itself and multiplicity #2', '/foo[-1]', '/foo[2]', '/foo[2]'),
      ('itself and multiplicity #3', '/foo[0]', '/foo[2]', '/foo[2]'),
      ('itself and multiplicity #4', '/foo[3]', '/foo[2]', '/foo[2]'),
      (
        'itself and predicate #1',
        '/foo',
        '/foo[position() = 3]',
        '/foo[position() = 3]',
      ),
      (
        'itself and predicate #2',
        '/foo[position() = 2]',
        '/foo[position() = 3]',
        '/foo[position() = 2]',
      ),
      (
        'ref with predicate with itself and multiplicity',
        '/foo[position() = 2]',
        '/foo[1]',
        '/foo[position() = 2]',
      ),
      (
        'ref with multiplicity with itself and predicate',
        '/foo[1]',
        '/foo[position() = 2]',
        '/foo[position() = 2]',
      ),
      ('Wildcards #1', 'bar', '/foo/*', '/foo/*/bar'),
      ('Wildcards #2', '../baz', '/foo/*/bar', '/foo/*/baz'),
      ('Wildcards #3', '*/baz', '/foo/*/bar', '/foo/*/bar/*/baz'),
      ('Wildcards #4', '*/bar', '/foo', '/foo/*/bar'),
      ('Predicates #1', 'bar', "/foo[@foo = 'bar']", "/foo[@foo = 'bar']/bar"),
      (
        'Predicates #2',
        "bar[@foo = 'baz']",
        "/foo[@foo = 'bar']",
        "/foo[@foo = 'bar']/bar[@foo = 'baz']",
      ),
      ('Predicates #3', "bar[@foo = 'baz']", '/foo', "/foo/bar[@foo = 'baz']"),
      (
        'Predicates #4',
        "/foo[@foo = 'foo']",
        "/foo[@foo = 'bar']",
        "/foo[@foo = 'foo']",
      ),
      (
        'Parent refs in nested repeats',
        '../../inner',
        '/data/outer[0]/inner[1]/count[0]',
        '/data/outer[0]/inner',
      ),
      (
        'Parent refs in child of repeat',
        '../../repeat/value',
        '/data/repeat[0]/sum[0]',
        '/data/repeat/value',
      ),
      (
        'Parent refs in child of repeat (deep)',
        '../../../outer/inner/bar/baz',
        '/data/outer[17]/inner[5]/foo',
        '/data/outer/inner/bar/baz',
      ),
    ];
    for (final (name, a, b, expected) in cases) {
      test(name, () {
        expect(
          getRef(a).contextualize(getRef(b)),
          expected == null ? isNull : getRef(expected),
        );
      });
    }
  });

  group('isAncestorOf', () {
    const irrelevant = true;
    const cases = [
      ('/foo', '/foo', true, false),
      ('/foo/bar', '/foo/bar', true, false),
      ('/foo', '/foo', false, true),
      ('/foo/bar', '/foo/bar', false, true),
      ('/foo/bar', '/foo', irrelevant, false),
      ('/foo', '/bar', irrelevant, false),
      ('foo', 'bar', irrelevant, false),
      ('/foo', '/bar/foo', irrelevant, false),
      ('/foo', '/foo/bar', irrelevant, true),
      ('/foo/bar', '/foo/bar/baz', irrelevant, true),
      ('/foo', '/foo/bar/baz', irrelevant, true),
      ('foo', '/foo/bar', irrelevant, false),
      ('/foo', 'foo/bar', irrelevant, false),
      ('/foo', '/foo[-1]/bar', irrelevant, true),
      ('/foo', '/foo[1]/bar', irrelevant, true),
      ('/foo', '/foo[3]/bar', irrelevant, true),
      ('/foo/bar', '/foo/bar[-1]/baz', irrelevant, true),
      ('/foo/bar', '/foo/bar[1]/baz', irrelevant, true),
      ('/foo/bar', '/foo/bar[3]/baz', irrelevant, true),
      ('/foo[-1]', '/foo/bar', irrelevant, true),
      ('/foo[-1]', '/foo[-1]/bar', irrelevant, true),
      ('/foo[-1]', '/foo[1]/bar', irrelevant, true),
      ('/foo[-1]', '/foo[3]/bar', irrelevant, true),
      ('/foo/bar[-1]', '/foo/bar/baz', irrelevant, true),
      ('/foo/bar[-1]', '/foo/bar[-1]/bzr', irrelevant, true),
      ('/foo/bar[-1]', '/foo/bar[1]/bzr', irrelevant, true),
      ('/foo/bar[-1]', '/foo/bar[3]/bzr', irrelevant, true),
      ('/foo[1]', '/foo/bar', irrelevant, true),
      ('/foo[1]', '/foo[-1]/bar', irrelevant, true),
      ('/foo[1]', '/foo[1]/bar', irrelevant, true),
      ('/foo[1]', '/foo[3]/bar', irrelevant, false),
      ('/foo/bar[1]', '/foo/bar/baz', irrelevant, false),
      ('/foo/bar[1]', '/foo/bar[-1]/baz', irrelevant, false),
      ('/foo/bar[1]', '/foo/bar[1]/baz', irrelevant, true),
      ('/foo/bar[1]', '/foo/bar[3]/baz', irrelevant, false),
      ('/foo[3]', '/foo[1]/bar', irrelevant, false),
      ('/foo[3]', '/foo[-1]/bar', irrelevant, false),
      ('/foo[3]', '/foo[3]/bar', irrelevant, true),
      ('/foo/bar[3]', '/foo/bar[1]/baz', irrelevant, false),
      ('/foo/bar[3]', '/foo/bar[-1]/baz', irrelevant, false),
      ('/foo/bar[3]', '/foo/bar[3]/baz', irrelevant, true),
      ('/foo[-1]/bar[3]', '/foo/bar[3]/baz', irrelevant, true),
      ('/foo[-1]/bar[3]', '/foo[-1]/bar[3]/baz', irrelevant, true),
      ('/foo[-1]/bar[3]', '/foo[1]/bar[3]/baz', irrelevant, true),
      ('/foo[-1]/bar[3]', '/foo[3]/bar[3]/baz', irrelevant, true),
      ('/foo[3]/bar[3]', '/foo[4]/bar[3]/baz', irrelevant, false),
    ];
    for (final (a, b, proper, expected) in cases) {
      test('$a ancestor of $b (proper: $proper) = $expected', () {
        expect(getRef(a).isAncestorOf(getRef(b), proper: proper), expected);
      });
    }
  });

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
