// DartRosa tests (not ports) of DataInstance / FormInstance reference
// operations JavaRosa has no direct tests for: explodeReference,
// hasTemplatePath (which lets a setvalue target a repeat with no
// instances), partial elements, and copyNode's failures. Expected
// behaviour follows JavaRosa 6.0.0's DataInstance / FormInstance sources;
// the setvalue case was checked with JavaRosa itself (jshell).
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

/// `/data` with `a/b`, two `r` (each with `x`), a template `t` with `y`,
/// and an attribute `att` on `a`.
FormInstance buildInstance() {
  final data = TreeElement('data', 0);
  final a = TreeElement('a', 0)
    ..addChild(TreeElement('b', 0))
    ..setAttribute(null, 'att', 'v');
  data.addChild(a);
  for (var i = 0; i < 2; i++) {
    data.addChild(
      TreeElement('r', i)
        ..isRepeatable = true
        ..addChild(TreeElement('x', 0)),
    );
  }
  data.addChild(
    TreeElement('t', TreeReference.indexTemplate)
      ..isRepeatable = true
      ..addChild(TreeElement('y', 0)),
  );
  return FormInstance(data);
}

TreeReference ref(String path) => getRef(path);

List<String>? names(List<TreeElement>? nodes) =>
    nodes?.map((n) => n.name!).toList();

void main() {
  late FormInstance instance;

  setUp(() => instance = buildInstance());

  test('explodeReference lists the nodes above the target', () {
    expect(names(instance.explodeReference(ref('/data/a/b'))), ['data', 'a']);
    expect(names(instance.explodeReference(ref('/data/r[2]/x'))), [
      'data',
      'r',
    ]);
    expect(names(instance.explodeReference(ref('/data/a/@att'))), [
      'data',
      'a',
    ]);
    // A missing attribute at the end still gives the path above it.
    expect(names(instance.explodeReference(ref('/data/a/@nope'))), [
      'data',
      'a',
    ]);
    // Ambiguous (several r) and missing steps can't be exploded.
    expect(instance.explodeReference(ref('/data/r/x')), isNull);
    expect(instance.explodeReference(ref('/data/nope/x')), isNull);
    expect(instance.explodeReference(ref('a/b')), isNull);
  });

  test('hasTemplatePath follows templates and any instance', () {
    expect(instance.hasTemplatePath(ref('/data/t/y')), isTrue);
    expect(instance.hasTemplatePath(ref('/data/r/x')), isTrue);
    expect(instance.hasTemplatePath(ref('/data/a/@att')), isTrue);
    // As in JavaRosa, the end of the reference is checked before the node,
    // so a missing final attribute still counts.
    expect(instance.hasTemplatePath(ref('/data/a/@nope')), isTrue);
    expect(instance.hasTemplatePath(ref('/data/a/@nope/x')), isFalse);
    expect(instance.hasTemplatePath(ref('/data/r/nope')), isFalse);
    expect(instance.hasTemplatePath(ref('t/y')), isFalse);
  });

  test('partial elements fail resolution until populated', () {
    final partial = TreeElement('p', 0, true);
    instance.root.addChild(partial);
    expect(
      () => instance.resolveReference(ref('/data/p')),
      throwsA(isA<PartialElementEncounteredException>()),
    );
    instance.replacePartialElements([
      TreeElement('p', 0)..addChild(TreeElement('filled', 0)),
    ]);
    expect(partial.isPartial, isFalse);
    expect(instance.resolveReference(ref('/data/p/filled')), isNotNull);
  });

  test('copyNode rejects bad destinations', () {
    final source = instance.resolveReference(ref('/data/a'))!;
    Matcher invalid(String message) => throwsA(
      isA<InvalidReferenceException>()
          .having((e) => e.message, 'message', message)
          .having((e) => '$e', 'toString', message),
    );
    expect(
      () => instance.copyNodeAt(ref('a'), ref('/data/a2')),
      invalid('Source reference must be absolute for copying'),
    );
    expect(
      () => instance.copyNodeAt(ref('/data/nope'), ref('/data/a2')),
      invalid('Null Source reference while attempting to copy node'),
    );
    expect(
      () => instance.copyNode(source, ref('a2')),
      invalid('Destination reference must be absolute for copying'),
    );
    expect(
      () => instance.copyNode(source, ref('/data/nope/a2')),
      invalid('Null parent reference whle attempting to copy'),
    );
    expect(
      () => instance.copyNode(source, ref('/data/a/@att/x')),
      invalid('Invalid Parent Node: cannot accept children.'),
    );
    expect(
      () => instance.copyNode(source, ref('/data/r[2]')),
      invalid('Destination already exists!'),
    );
    final copied = instance.copyNodeAt(ref('/data/r[1]'), ref('/data/r[-1]'));
    expect('$copied', '/data/r[3]');
  });

  test('instance names and runtime evaluation', () {
    expect('$instance', 'NULL');
    instance.name = 'main';
    expect('$instance', 'main');
    expect(instance.isRuntimeEvaluated, isFalse);
  });

  test('a setvalue targeting a repeat without instances is ignored', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Setvalue into template'),
          model([
            mainInstance([
              t('data id="sv"', [
                t('q'),
                t('r jr:template=""', [t('x')]),
              ]),
            ]),
            t(
              'setvalue event="odk-instance-first-load" ref="/data/r/x" '
              'value="5"',
            ),
          ]),
        ]),
        body([
          input('/data/q'),
          repeat('/data/r', [input('/data/r/x')]),
        ]),
      ),
    );
    expect(scenario.countRepeatInstancesOf('/data/r'), 0);
  });
}
