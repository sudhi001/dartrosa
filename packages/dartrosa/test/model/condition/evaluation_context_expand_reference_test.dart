// Port of JavaRosa v6.0.0 EvaluationContextExpandReferenceTest.
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  late Scenario scenario;
  late EvaluationContext ec;

  setUpAll(() async {
    scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('group jr:template=""', [t('number')]),
              ]),
            ]),
            bind('/data/group/number')..type('int'),
          ]),
        ]),
        body([
          formGroup('/data/group', [
            repeat('/data/group', [input('/data/group/number')]),
          ]),
        ]),
      ),
    );
    scenario.next();
    for (var i = 0; i < 5; i++) {
      scenario
        ..createNewRepeatHere()
        ..next()
        ..next();
    }
    ec = scenario.evaluationContext;
  });

  test('test_normal_case', () {
    expect(
      ec.expandReference(getRef('/data/group/number')),
      containsAll([
        getRef('/data/group[1]/number[1]'),
        getRef('/data/group[2]/number[1]'),
        getRef('/data/group[3]/number[1]'),
        getRef('/data/group[4]/number[1]'),
        getRef('/data/group[5]/number[1]'),
      ]),
    );
  });

  test('test_include_templates_case', () {
    expect(
      ec.expandReference(getRef('/data/group/number'), includeTemplates: true),
      orderedEquals([
        getRef('/data/group[1]/number[1]'),
        getRef('/data/group[2]/number[1]'),
        getRef('/data/group[3]/number[1]'),
        getRef('/data/group[4]/number[1]'),
        getRef('/data/group[5]/number[1]'),
        getRef('/data/group[@template]/number[1]'),
      ]),
    );
  });

  test('test_relative_ref_case', () {
    expect(ec.expandReference(getRef('group/number')), isNull);
  });

  test('returns_itself_if_fully_qualified', () {
    final numberRef = getRef('/data/group[4]/number[1]');
    expect(ec.expandReference(numberRef), orderedEquals([numberRef]));

    final groupRef = getRef('/data/group[4]');
    expect(ec.expandReference(groupRef), orderedEquals([groupRef]));
  });

  test('expands_partially_qualified_refs', () {
    expect(
      ec.expandReference(getRef('/data/group[4]/number')),
      orderedEquals([getRef('/data/group[4]/number[1]')]),
    );
    expect(
      ec.expandReference(getRef('/data/group')),
      orderedEquals([
        getRef('/data/group[1]'),
        getRef('/data/group[2]'),
        getRef('/data/group[3]'),
        getRef('/data/group[4]'),
        getRef('/data/group[5]'),
      ]),
    );
  });
}
