// Port of JavaRosa v6.0.0 IndexedRepeatRelativeRefsTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

const absoluteTarget = '/data/some-group/item/value';
const relativeTarget = '../item/value';
const absoluteGroup = '/data/some-group/item';
const relativeGroup = '../item';
const absoluteIndex = '/data/total-items';
const relativeIndex = '../../total-items';

void main() {
  // JUnit parameters: (testName, target, group, index).
  const data = [
    (
      'Target: absolute, group: absolute, index: absolute',
      absoluteTarget,
      absoluteGroup,
      absoluteIndex,
    ),
    (
      'Target: absolute, group: absolute, index: relative',
      absoluteTarget,
      absoluteGroup,
      relativeIndex,
    ),
    (
      'Target: absolute, group: relative, index: absolute',
      absoluteTarget,
      relativeGroup,
      absoluteIndex,
    ),
    (
      'Target: absolute, group: relative, index: relative',
      absoluteTarget,
      relativeGroup,
      relativeIndex,
    ),
    (
      'Target: relative, group: absolute, index: absolute',
      relativeTarget,
      absoluteGroup,
      absoluteIndex,
    ),
    (
      'Target: relative, group: absolute, index: relative',
      relativeTarget,
      absoluteGroup,
      relativeIndex,
    ),
    (
      'Target: relative, group: relative, index: absolute',
      relativeTarget,
      relativeGroup,
      absoluteIndex,
    ),
    (
      'Target: relative, group: relative, index: relative',
      relativeTarget,
      relativeGroup,
      relativeIndex,
    ),
  ];

  for (final (testName, target, group, index) in data) {
    test('indexed_repeat [$testName]', () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('some-group', [
                    t('item jr:template=""', [t('value')]),
                    t('last-value'),
                  ]),
                  t('total-items'),
                ]),
              ]),
              bind(absoluteTarget)..type('int'),
              bind('/data/total-items')
                ..type('int')
                ..calculate('count(/data/some-group/item)'),
              bind('/data/some-group/last-value')
                ..type('int')
                ..calculate('indexed-repeat($target, $group, $index)'),
            ]),
          ]),
          body([
            formGroup('/data/some-group', [
              formGroup('/data/some-group/item', [
                repeat('/data/some-group/item', [
                  input('/data/some-group/item/value'),
                ]),
              ]),
            ]),
          ]),
        ),
      );

      scenario
        ..answer('/data/some-group[1]/item[1]/value', 11)
        ..answer('/data/some-group[1]/item[2]/value', 22)
        ..answer('/data/some-group[1]/item[3]/value', 33);

      expect(scenario.answerOf('/data/total-items'), intAnswer(3));
      expect(scenario.answerOf('/data/some-group/last-value'), intAnswer(33));
    });
  }
}
