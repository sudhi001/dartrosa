// Ports of JavaRosa v6.0.0 TreeReferenceAnchorTest,
// TreeReferenceAnchorHarnessTest, TreeReferenceContextualizeTest,
// TreeReferenceEqualsTest, TreeReferenceGenericizeTest,
// TreeReferenceIsAncestorOfTest and TreeReferenceParentTest.
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  group('TreeReferenceAnchorTest', () {
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
      final tr = getRef('/some/absolute/ref');
      expect(tr.anchor(getRef('/some/other/absolute/ref')), tr);
    });
  });

  group('TreeReferenceAnchorHarnessTest', () {
    for (final (tr, base) in [('foo', '/bar'), ('/foo', '/bar')]) {
      test('$tr.anchor($base)', () {
        expect(
          getRef(tr).anchor(getRef(base)),
          getRef(tr).parent(getRef(base)),
        );
      });
    }
  });

  group('TreeReferenceContextualizeTest', () {
    for (final (name, a, b, expected) in [
      ('Relative context ref', 'bar', 'foo', null),
      ('Non-matching absolute refs', '/foo', '/bar', '/foo'),
      (
        'Contextualizing a ref with itself and multiplicity #1',
        '/foo',
        '/foo[2]',
        '/foo[2]',
      ),
      (
        'Contextualizing a ref with itself and multiplicity #2',
        '/foo[-1]',
        '/foo[2]',
        '/foo[2]',
      ),
      (
        'Contextualizing a ref with itself and multiplicity #3',
        '/foo[0]',
        '/foo[2]',
        '/foo[2]',
      ),
      (
        'Contextualizing a ref with itself and multiplicity #4',
        '/foo[3]',
        '/foo[2]',
        '/foo[2]',
      ),
      (
        'Contextualizing a ref with itself and predicate #1',
        '/foo',
        '/foo[position() = 3]',
        '/foo[position() = 3]',
      ),
      (
        'Contextualizing a ref with itself and predicate #2',
        '/foo[position() = 2]',
        '/foo[position() = 3]',
        '/foo[position() = 2]',
      ),
      (
        'Contextualizing a ref with predicate with itself and multiplicity',
        '/foo[position() = 2]',
        '/foo[1]',
        '/foo[position() = 2]',
      ),
      (
        'Contextualizing a ref with multiplicity with itself and predicate',
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
        'Parent refs in child of repeat (deeper)',
        '../../../outer/inner/bar/baz',
        '/data/outer[17]/inner[5]/foo',
        '/data/outer/inner/bar/baz',
      ),
    ]) {
      test(name, () {
        expect(
          getRef(a).contextualize(getRef(b)),
          expected == null ? isNull : getRef(expected),
        );
      });
    }
  });

  group('TreeReferenceEqualsTest', () {
    for (final (name, a, b, equal) in [
      ('same path in primary instance are equal', '/foo/bar', '/foo/bar', true),
      (
        'same path in secondary instance are equal',
        "instance('foo')/bar/baz",
        "instance('foo')/bar/baz",
        true,
      ),
      (
        'same path in primary and secondary instance are not equal',
        '/foo/bar',
        "instance('foo')/foo/bar",
        false,
      ),
      (
        'same path in secondary and primary instance are not equal',
        "instance('foo')/foo/bar",
        '/foo/bar',
        false,
      ),
      (
        'same path in different secondary instances are not equal',
        "instance('foo')/foo/bar",
        "instance('bar')/foo/bar",
        false,
      ),
      (
        'different paths in primary instance are not equal',
        '/foo/bar',
        '/foo/bar/quux',
        false,
      ),
      (
        'different paths in secondary instance are not equal',
        "instance('foo')/foo/bar",
        "instance('foo')/foo/bar/quux",
        false,
      ),
    ]) {
      test(name, () => expect(getRef(a) == getRef(b), equal));
    }
  });

  group('TreeReferenceGenericizeTest', () {
    test('genericize sets all steps with unbound multiplicity', () {
      expect(getRef('/foo/bar').genericize(), getRef('/foo/bar'));
      final original = getRef('/foo[3]/bar[4]');
      expect(original.multiplicityAt(0), 2);
      expect(original.multiplicityAt(1), 3);
      final generic = original.genericize();
      for (var i = 0; i < original.size; i++) {
        expect(generic.multiplicityAt(i), -1);
      }
    });
  });

  group('TreeReferenceIsAncestorOfTest', () {
    const irrelevant = true;
    for (final (name, a, b, proper, expected) in [
      ('/foo not ancestor of /foo excluding self', '/foo', '/foo', true, false),
      (
        '/foo/bar not ancestor of /foo/bar excluding self',
        '/foo/bar',
        '/foo/bar',
        true,
        false,
      ),
      ('/foo ancestor of /foo including self', '/foo', '/foo', false, true),
      (
        '/foo/bar ancestor of /foo/bar including self',
        '/foo/bar',
        '/foo/bar',
        false,
        true,
      ),
      (
        '/foo/bar is not ancestor of /foo',
        '/foo/bar',
        '/foo',
        irrelevant,
        false,
      ),
      ('/foo is not ancestor of /bar', '/foo', '/bar', irrelevant, false),
      ('foo is not ancestor of bar', 'foo', 'bar', irrelevant, false),
      (
        '/foo is not ancestor of /bar/foo',
        '/foo',
        '/bar/foo',
        irrelevant,
        false,
      ),
      ('/foo is ancestor of /foo/bar', '/foo', '/foo/bar', irrelevant, true),
      (
        '/foo/bar is ancestor of /foo/bar/baz',
        '/foo/bar',
        '/foo/bar/baz',
        irrelevant,
        true,
      ),
      (
        '/foo is ancestor of /foo/bar/baz',
        '/foo',
        '/foo/bar/baz',
        irrelevant,
        true,
      ),
      ('foo is not ancestor of /foo/bar', 'foo', '/foo/bar', irrelevant, false),
      ('/foo is not ancestor of foo/bar', '/foo', 'foo/bar', irrelevant, false),
      (
        '/foo is ancestor of /foo[-1]/bar',
        '/foo',
        '/foo[-1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo is ancestor of /foo[1]/bar',
        '/foo',
        '/foo[1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo is ancestor of /foo[3]/bar',
        '/foo',
        '/foo[3]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo/bar is ancestor of /foo/bar[-1]/baz',
        '/foo/bar',
        '/foo/bar[-1]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo/bar is ancestor of /foo/bar[1]/baz',
        '/foo/bar',
        '/foo/bar[1]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo/bar is ancestor of /foo/bar[3]/baz',
        '/foo/bar',
        '/foo/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[-1] is ancestor of /foo/bar',
        '/foo[-1]',
        '/foo/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[-1] is ancestor of /foo[-1]/bar',
        '/foo[-1]',
        '/foo[-1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[-1] is ancestor of /foo[1]/bar',
        '/foo[-1]',
        '/foo[1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[-1] is ancestor of /foo[3]/bar',
        '/foo[-1]',
        '/foo[3]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[-1] is ancestor of /foo/bar/baz',
        '/foo/bar[-1]',
        '/foo/bar/baz',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[-1] is ancestor of /foo/bar[-1]/bzr',
        '/foo/bar[-1]',
        '/foo/bar[-1]/bzr',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[-1] is ancestor of /foo/bar[1]/bzr',
        '/foo/bar[-1]',
        '/foo/bar[1]/bzr',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[-1] is ancestor of /foo/bar[3]/bzr',
        '/foo/bar[-1]',
        '/foo/bar[3]/bzr',
        irrelevant,
        true,
      ),
      (
        '/foo[0] is ancestor of /foo/bar',
        '/foo[1]',
        '/foo/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[0] is ancestor of /foo[-1]/bar',
        '/foo[1]',
        '/foo[-1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[0] is ancestor of /foo[1]/bar',
        '/foo[1]',
        '/foo[1]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo[0] is not ancestor of /foo[3]/bar',
        '/foo[1]',
        '/foo[3]/bar',
        irrelevant,
        false,
      ),
      (
        '/foo/bar[0] is not ancestor of /foo/bar/baz',
        '/foo/bar[1]',
        '/foo/bar/baz',
        irrelevant,
        false,
      ),
      (
        '/foo/bar[0] is not ancestor of /foo/bar[-1]/baz',
        '/foo/bar[1]',
        '/foo/bar[-1]/baz',
        irrelevant,
        false,
      ),
      (
        '/foo/bar[0] is ancestor of /foo/bar[1]/baz',
        '/foo/bar[1]',
        '/foo/bar[1]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[0] is not ancestor of /foo/bar[3]/baz',
        '/foo/bar[1]',
        '/foo/bar[3]/baz',
        irrelevant,
        false,
      ),
      (
        '/foo[2] is not ancestor of /foo[0]/bar',
        '/foo[3]',
        '/foo[1]/bar',
        irrelevant,
        false,
      ),
      (
        '/foo[2] is not ancestor of /foo[-1]/bar',
        '/foo[3]',
        '/foo[-1]/bar',
        irrelevant,
        false,
      ),
      (
        '/foo[2] is ancestor of /foo[2]/bar',
        '/foo[3]',
        '/foo[3]/bar',
        irrelevant,
        true,
      ),
      (
        '/foo/bar[2] is not ancestor of /foo/bar[0]/baz',
        '/foo/bar[3]',
        '/foo/bar[1]/baz',
        irrelevant,
        false,
      ),
      (
        '/foo/bar[2] is not ancestor of /foo/bar[-1]/baz',
        '/foo/bar[3]',
        '/foo/bar[-1]/baz',
        irrelevant,
        false,
      ),
      (
        '/foo/bar[2] is ancestor of /foo/bar[2]/baz',
        '/foo/bar[3]',
        '/foo/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[-1]/bar[2] is ancestor of /foo/bar[2]/baz',
        '/foo[-1]/bar[3]',
        '/foo/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[-1]/bar[2] is ancestor of /foo[-1]/bar[2]/baz',
        '/foo[-1]/bar[3]',
        '/foo[-1]/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[-1]/bar[2] is ancestor of /foo[0]/bar[2]/baz',
        '/foo[-1]/bar[3]',
        '/foo[1]/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[-1]/bar[2] is ancestor of /foo[2]/bar[2]/baz',
        '/foo[-1]/bar[3]',
        '/foo[3]/bar[3]/baz',
        irrelevant,
        true,
      ),
      (
        '/foo[2]/bar[2] is not ancestor of /foo[3]/bar[2]/baz',
        '/foo[3]/bar[3]',
        '/foo[4]/bar[3]/baz',
        irrelevant,
        false,
      ),
    ]) {
      test(name, () {
        expect(getRef(a).isAncestorOf(getRef(b), proper: proper), expected);
      });
    }
  });

  group('TreeReferenceParentTest', () {
    for (final (name, tr, base, expected) in [
      ("Parenting absolute refs doesn't change them", '/foo', '/bar', '/foo'),
      ("Parenting to an empty ref doesn't change them", '../foo', '', '../foo'),
      ('foo.parent(bar) gives bar/foo', 'foo', 'bar', 'bar/foo'),
      ('foo.parent(../bar) gives ../bar/foo', 'foo', '../bar', '../bar/foo'),
      ('../foo.parent(bar/baz) gives null', '../foo', 'bar/baz', null),
      ('../../a.parent(..) gives ../../../a', '../../a', '..', '../../../a'),
    ]) {
      test(name, () {
        expect(
          getRef(tr).parent(getRef(base)),
          expected == null ? isNull : getRef(expected),
        );
      });
    }
  });
}
