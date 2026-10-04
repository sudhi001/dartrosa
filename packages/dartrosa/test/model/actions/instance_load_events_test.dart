// Port of JavaRosa v6.0.0 InstanceLoadEventsTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

void main() {
  XFormsElement instanceLoadForm(String event) => html(
    head([
      title('Instance load form'),
      model([
        mainInstance([
          t('data id="instance-load-form"', [t('q1')]),
        ]),
        bind('/data/q1')..type('int'),
        setvalue(event, '/data/q1', '4*4'),
      ]),
    ]),
    body([input('/data/q1')]),
  );

  test('instanceLoadEvent_firesOnFirstLoad', () async {
    final scenario = await Scenario.init(instanceLoadForm('odk-instance-load'));

    expect(scenario.answerOf('/data/q1'), intAnswer(16));
  });

  test(
    'instanceLoadEvent_firesOnSecondLoad',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test(
    'instanceFirstLoadEvent_doesNotfireOnSecondLoad',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  XFormsElement nestedForm(int repeats) => html(
    head([
      title('Nested instance load'),
      model([
        mainInstance([
          t('data id="nested-instance-load"', [
            for (var i = 0; i < repeats; i++) t('repeat', [t('q1')]),
          ]),
        ]),
        bind('/data/repeat/q1')..type('string'),
      ]),
    ]),
    body([
      repeat('/data/repeat', [
        setvalue('odk-instance-load', '/data/repeat/q1', '4*4'),
        input('/data/repeat/q1'),
      ]),
    ]),
  );

  test('instanceLoadEvent_triggersNestedActions', () async {
    final scenario = await Scenario.init(nestedForm(1));

    expect(scenario.answerOf('/data/repeat[1]/q1'), stringAnswer('16'));

    scenario.createNewRepeat('/data/repeat');
    expect(scenario.answerOf('/data/repeat[2]/q1'), isNull);
  });

  test('instanceLoadEvent_triggeredForAllPreExistingRepeatInstances', () async {
    final scenario = await Scenario.init(nestedForm(2));

    expect(scenario.answerOf('/data/repeat[1]/q1'), stringAnswer('16'));
    expect(scenario.answerOf('/data/repeat[2]/q1'), stringAnswer('16'));

    scenario.createNewRepeat('/data/repeat');
    expect(scenario.answerOf('/data/repeat[3]/q1'), isNull);
  });
}
