// Port of JavaRosa v6.0.0 SetGeopointActionTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';
import '../../support/matchers.dart';

void main() {
  final expectedStubAnswer = stringAnswer('no client implementation');

  test('when_namespaceIsNotOdk_exceptionIsThrown', () async {
    await expectLater(
      scenarioFor('setgeopoint-action-bad-namespace.xml'),
      throwsA(isA<XFormParseException>()),
    );
  });

  test('when_instanceIsLoaded_locationIsSetAtTarget', () async {
    final scenario = await scenarioFor('setgeopoint-action-instance-load.xml');

    expect(scenario.answerOf('/data/location'), expectedStubAnswer);
  });

  test('when_triggerNodeIsUpdated_locationIsSetAtTarget', () async {
    final scenario = await scenarioFor('setgeopoint-action-value-changed.xml');

    // The test form has no default value at /data/location, and
    // no other event sets any value on it
    expect(scenario.answerOf('/data/location'), isNull);

    // Answering a question triggers its "xforms-value-changed" event
    scenario.answer('/data/text', 'some answer');

    expect(scenario.answerOf('/data/location'), expectedStubAnswer);
  });

  test(
    'testSerializationAndDeserialization',
    () {},
    skip:
        'Externalizable binary format is not ported (FormDefCodec replaces it)',
  );
}
