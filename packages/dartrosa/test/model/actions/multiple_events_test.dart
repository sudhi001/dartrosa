// Port of JavaRosa v6.0.0 MultipleEventsTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';

void main() {
  test('nestedFirstLoadEvent_setsValue', () async {
    final scenario = await scenarioFor('multiple-events.xml');

    expect(scenario.answerOf('/data/nested-first-load')!.displayText, 'cheese');
  });

  test('nestedFirstLoadEventInGroup_setsValue', () async {
    final scenario = await scenarioFor('multiple-events.xml');

    expect(
      scenario
          .answerOf('/data/my-group/nested-first-load-in-group')!
          .displayText,
      'more cheese',
    );
  });

  test(
    'serializedAndDeserializedNestedFirstLoadEvent_setsValue',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test(
    'serializedAndDeserializedNestedFirstLoadEventInGroup_setsValue',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test('nestedFirstLoadAndValueChangedEvents_setValue', () async {
    final scenario = await scenarioFor('multiple-events.xml');

    expect(scenario.answerOf('/data/my-calculated-value')!.displayText, '10');
    scenario.answer('/data/my-value', '15');
    expect(scenario.answerOf('/data/my-calculated-value')!.displayText, '30');
  });

  test(
    'serializedAndDeserializedNestedFirstLoadAndValueChangedEvents_setValue',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  test('invalidEventNames_throwException', () async {
    await expectLater(
      scenarioFor('invalid-events.xml'),
      throwsA(
        isA<XFormParseException>().having(
          (e) => e.message,
          'message',
          contains(
            'An action was registered for unsupported events: '
            'odk-inftance-first-load, my-fake-event',
          ),
        ),
      ),
    );
  });
}
