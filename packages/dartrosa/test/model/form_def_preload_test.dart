// DartRosa tests of FormDef preloads, properties and evaluation events
// (JavaRosa covers these through Scenario-based tests ported in P4).
import 'package:clock/clock.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/model/utils/question_preloader.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

String formXml() => html(
  head([
    title('Preloads'),
    model([
      mainInstance([
        t('data id="preloads"', [
          t('start'),
          t('end'),
          t('today'),
          t('device'),
          t('user'),
          t('prop'),
          t('meta', [t('instanceID')]),
        ]),
      ]),
      bind('/data/start')
        ..type('dateTime')
        ..withAttribute('jr', 'preload', 'timestamp')
        ..withAttribute('jr', 'preloadParams', 'start'),
      bind('/data/end')
        ..type('dateTime')
        ..withAttribute('jr', 'preload', 'timestamp')
        ..withAttribute('jr', 'preloadParams', 'end'),
      bind('/data/today')
        ..type('date')
        ..withAttribute('jr', 'preload', 'date')
        ..withAttribute('jr', 'preloadParams', 'today'),
      bind('/data/device')
        ..type('string')
        ..withAttribute('jr', 'preload', 'property')
        ..withAttribute('jr', 'preloadParams', 'deviceid'),
      bind('/data/user')
        ..type('string')
        ..withAttribute('jr', 'preload', 'property')
        ..withAttribute('jr', 'preloadParams', 'username'),
      bind('/data/prop')
        ..type('string')
        ..calculate("property('deviceid')"),
      bind('/data/meta/instanceID')
        ..type('string')
        ..withAttribute('jr', 'preload', 'uid'),
    ]),
  ]),
  body([input('/data/user')]),
).asXml();

void main() {
  test('preloads on initialize and post-processing', () async {
    final form = await parseXml(formXml());
    form.preloader = QuestionPreloader(
      properties: MapPropertyManager({'deviceid': 'collect:abc'}),
    );
    final started = DateTime(2026, 10, 4, 9, 30);
    withClock(Clock.fixed(started), () => form.initialize(newInstance: true));
    String? value(String ref) =>
        form.mainInstance.resolveReference(getRef(ref))!.value?.displayText;
    final root = form.mainInstance;
    expect(root.resolveReference(getRef('/data/start'))!.value!.value, started);
    expect(value('/data/end'), isNull);
    expect(
      root.resolveReference(getRef('/data/today'))!.value!.value,
      DateTime(2026, 10, 4),
    );
    expect(value('/data/device'), 'collect:abc');
    expect(value('/data/user'), isNull);
    expect(value('/data/prop'), 'collect:abc');
    expect(
      value('/data/meta/instanceID'),
      matches(RegExp(r'^uuid:[0-9a-f-]{36}$')),
    );

    // Finalization sets `end` and saves `property` answers.
    form.setValue(const StringValue('alice'), getRef('/data/user'));
    final finished = DateTime(2026, 10, 4, 10);
    withClock(Clock.fixed(finished), form.postProcessInstance);
    expect(root.resolveReference(getRef('/data/end'))!.value!.value, finished);
    expect(form.preloader.properties.getProperty('username'), 'alice');
  });

  test('evaluation events', () async {
    final form = await parseXml(formXml());
    final events = <EvaluationEvent>[];
    form
      ..addEventListener(events.add)
      ..initialize(newInstance: true);
    expect(events.last.message, startsWith('Form initialized: '));
    expect(
      events.where((e) => e.message == 'Recalculate').single.results.single.ref,
      getRef('/data/prop[1]'),
    );
  });
}
