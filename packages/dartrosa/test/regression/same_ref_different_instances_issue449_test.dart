// Port of JavaRosa v6.0.0 SameRefDifferentInstancesIssue449Test.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void main() {
  test(
    'formWithSameRefInDifferentInstances_isSuccessfullyDeserialized',
    () async {
      final file = formFile('issue_449.xml');
      final resolver = DirectoryResolver(file.parent);
      final scenario = await Scenario.fromXml(
        file.readAsStringSync(),
        resolver: resolver,
      );

      scenario.answer('/data/new-part', 'c');
      expect(scenario.answerOf('/data/aggregated'), stringAnswer('a b c'));

      final deserialized = await scenario.serializeAndDeserializeForm(
        resolver: resolver,
      );
      expect(deserialized.answerOf('/data/new-part[0]'), stringAnswer('c'));
      expect(
        deserialized.answerOf('/data/aggregated[0]'),
        stringAnswer('a b c'),
      );

      deserialized.answer('/data/new-part', 'c2');
      expect(
        deserialized.answerOf('/data/aggregated[0]'),
        stringAnswer('a b c2'),
      );
    },
  );

  test('constraintsAreCorrectlyApplied_afterDeserialization', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Tree reference deserialization'),
          model([
            mainInstance([
              t('data id="treeref-deserialization"', [
                tText('a', 'not ok'),
                t('b'),
              ]),
            ]),
            bind('/data/a')..type('string'),
            bind('/data/b')
              ..type('string')
              ..constraint('. != /data/a'),
          ]),
        ]),
        body([input('/data/b')]),
      ),
    );

    scenario
      ..next()
      ..answerCurrent('ok');
    expect(scenario.answerOf('/data/b[0]'), stringAnswer('ok'));

    scenario.answerCurrent('not ok');
    expect(scenario.answerOf('/data/b[0]'), stringAnswer('ok'));

    final deserialized = await scenario.serializeAndDeserializeForm();

    deserialized
      ..next()
      ..answerCurrent('ok');
    expect(deserialized.answerOf('/data/b[0]'), stringAnswer('ok'));

    deserialized.answerCurrent('not ok');
    expect(deserialized.answerOf('/data/b[0]'), stringAnswer('ok'));
  });
}
