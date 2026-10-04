// DartRosa's FormDefCodec (replacing JavaRosa's Externalizable FormDef).
import 'package:dartrosa/src/codec/form_def_codec.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

XFormsElement form() => html(
  head([
    title('Codec'),
    model([
      mainInstance([
        t('data id="codec"', [
          t('a'),
          t('b'),
          t('hidden'),
          t('r', [t('v')]),
        ]),
      ]),
      bind('/data/a')..type('int'),
      bind('/data/b')
        ..type('int')
        ..calculate('/data/a * 2'),
      bind('/data/hidden')
        ..type('string')
        ..relevant('/data/a > 5'),
      bind('/data/r/v')..type('string'),
    ]),
  ]),
  body([
    input('/data/a'),
    input('/data/hidden'),
    repeat('/data/r', [input('/data/r/v')]),
  ]),
);

void main() {
  test('round trip keeps answers, repeats and non-relevant values', () async {
    final scenario = await Scenario.init(form());
    scenario
      ..answer('/data/a', 10)
      ..answer('/data/hidden', 'kept')
      ..createNewRepeat('/data/r')
      ..answer('/data/r[2]/v', 'second')
      ..answer('/data/a', 1);
    expect(scenario.getAnswerNode('/data/hidden'), nonRelevant);

    final restored = await scenario.serializeAndDeserializeForm();
    expect(restored.answerOf('/data/a'), intAnswer(1));
    expect(restored.answerOf('/data/b'), intAnswer(2));
    expect(restored.answerOf('/data/hidden'), stringAnswer('kept'));
    expect(restored.getAnswerNode('/data/hidden'), nonRelevant);
    expect(restored.countRepeatInstancesOf('/data/r'), 2);
    expect(restored.answerOf('/data/r[2]/v'), stringAnswer('second'));
    restored.answer('/data/a', 7);
    expect(restored.getAnswerNode('/data/hidden'), relevant);
  });

  test('instance round trip through submission XML', () async {
    final scenario = await Scenario.init(form());
    scenario
      ..answer('/data/a', 3)
      ..createNewRepeat('/data/r')
      ..answer('/data/r[2]/v', 'x');
    final restored = await scenario.serializeAndDeserializeInstance(form());
    expect(restored.answerOf('/data/a'), intAnswer(3));
    expect(restored.answerOf('/data/b'), intAnswer(6));
    expect(restored.answerOf('/data/r[2]/v'), stringAnswer('x'));
  });

  test('cache key depends on the form and codec version', () {
    expect(FormDefCodec.cacheKey('<a/>'), FormDefCodec.cacheKey('<a/>'));
    expect(FormDefCodec.cacheKey('<a/>'), isNot(FormDefCodec.cacheKey('<b/>')));
    expect(
      FormDefCodec.cacheKey('<a/>'),
      startsWith('v${FormDefCodec.version}-'),
    );
  });
}
