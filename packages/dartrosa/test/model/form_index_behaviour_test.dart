// DartRosa tests (not ports) of FormIndex operations that JavaRosa's
// FormIndexTest doesn't cover: assignRefs, trimNegativeIndices,
// isSubElement, wrap without a current level, equality/hashing and the
// path-string encoding's limits. Expected behaviour follows JavaRosa
// 6.0.0's FormIndex source.
import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>Index</h:title><model>
<instance><data id="index"><q/><r><a/></r><r><a/></r></data></instance>
</model></h:head>
<h:body>
<input ref="/data/q"><label>Q</label></input>
<repeat nodeset="/data/r"><input ref="/data/r/a"><label>A</label></input></repeat>
</h:body></h:html>
''';

void main() {
  test('assignRefs fills in the reference of every level', () async {
    final formDef = await XFormParser().parse(form);
    final index = FormIndex(1, instanceIndex: 1, nextLevel: FormIndex(0));
    expect(index.reference, isNull);
    index.assignRefs(formDef);
    expect('${index.localReference}', '/data/r[2]');
    expect('${index.nextLevel!.localReference}', '/data/r[2]/a[1]');
    expect('${index.reference}', '/data/r[2]/a[1]');
  });

  test('trimNegativeIndices drops a negative terminal level', () {
    final trimmed = FormIndex.trimNegativeIndices(
      FormIndex(2, nextLevel: FormIndex(1, nextLevel: FormIndex(-1))),
    );
    expect(trimmed, FormIndex(2, nextLevel: FormIndex(1)));
    expect(FormIndex.trimNegativeIndices(FormIndex(-1)), isNull);
    expect(FormIndex.trimNegativeIndices(FormIndex(3)), FormIndex(3));
  });

  test('isSubElement compares the levels of the parent', () {
    final repeat = FormIndex(1, instanceIndex: 0);
    final inFirst = FormIndex(1, instanceIndex: 0, nextLevel: FormIndex(0));
    final inSecond = FormIndex(1, instanceIndex: 1, nextLevel: FormIndex(0));
    expect(FormIndex.isSubElement(repeat, inFirst), isTrue);
    expect(FormIndex.isSubElement(repeat, inSecond), isFalse);
    // A parent without an instance matches every instance.
    expect(FormIndex.isSubElement(FormIndex(1), inSecond), isTrue);
    expect(FormIndex.isSubElement(FormIndex(2), inFirst), isFalse);
    // A deeper parent than the child can't contain it.
    expect(FormIndex.isSubElement(inFirst, repeat), isFalse);
    // Nested levels must match exactly down to the parent's terminal.
    final nested = FormIndex(
      1,
      instanceIndex: 0,
      nextLevel: FormIndex(0, nextLevel: FormIndex(4)),
    );
    expect(FormIndex.isSubElement(inFirst, nested), isTrue);
    expect(
      FormIndex.isSubElement(
        FormIndex(1, instanceIndex: 0, nextLevel: FormIndex(1)),
        nested,
      ),
      isFalse,
    );
    expect(FormIndex.isSubElement(inSecond, nested), isFalse);
    expect(
      FormIndex.isSubElement(FormIndex(2, nextLevel: FormIndex(0)), nested),
      isFalse,
    );
  });

  test('wrap without a current level unwraps the next level', () {
    final ref = getRef('/data/q');
    final wrapped = FormIndex.wrap(
      FormIndex(3, instanceIndex: 2, nextLevel: FormIndex(1), reference: ref),
      null,
    );
    expect(wrapped, FormIndex(3, instanceIndex: 2, nextLevel: FormIndex(1)));
    expect(wrapped.localReference, ref);
  });

  test('equal indices have equal hash codes', () {
    final a = FormIndex(1, instanceIndex: 0, nextLevel: FormIndex(2));
    final b = FormIndex(
      1,
      instanceIndex: 0,
      nextLevel: FormIndex(2),
      reference: getRef('/data/r'),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a, b}, hasLength(1));
  });

  test('path strings only encode plain absolute references', () {
    expect(
      () => FormIndex(0, reference: getRef('q')).toPathString(),
      throwsArgumentError,
    );
    expect(
      FormIndex(0, reference: const TreeReference.root()).toPathString(),
      '0=/',
    );
    expect(FormIndex.parse('0=/').localReference, const TreeReference.root());
  });
}
