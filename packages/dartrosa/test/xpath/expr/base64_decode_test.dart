// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (Base64DecodeTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 Base64DecodeTest.
import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

Future<Scenario> getBase64DecodeScenario(String testName, String source) =>
    Scenario.init(
      html(
        head([
          title(testName),
          model([
            mainInstance([
              t('data id="base64"', [tText('text', source), t('decoded')]),
            ]),
            bind('/data/text')..type('string'),
            bind('/data/decoded')
              ..type('string')
              ..calculate('base64-decode(/data/text)'),
          ]),
        ]),
        body([input('/data/text')]),
      ),
    );

void main() {
  test('asciiString_isSuccessfullyDecoded', () async {
    final scenario = await getBase64DecodeScenario('ASCII string', 'SGVsbG8=');
    expect(scenario.answerOf('/data/decoded'), stringAnswer('Hello'));
  });

  test('exampleFromSaxonica_isSuccessfullyDecoded', () async {
    final scenario = await getBase64DecodeScenario(
      'Example from Saxonica',
      'RGFzc2Vs',
    );
    expect(scenario.answerOf('/data/decoded'), stringAnswer('Dassel'));
  });

  test('accentString_isSuccessfullyDecoded', () async {
    final scenario = await getBase64DecodeScenario(
      'String with accented characters',
      'w6nDqMOx',
    );
    expect(scenario.answerOf('/data/decoded'), stringAnswer('éèñ'));
  });

  test('emojiString_isSuccessfullyDecoded', () async {
    final scenario = await getBase64DecodeScenario(
      'String with emoji',
      '8J+lsA==',
    );
    expect(scenario.answerOf('/data/decoded'), stringAnswer('🥰'));
  });

  test('utf16String_isDecodedToGarbage', () async {
    final scenario = await getBase64DecodeScenario(
      'UTF-16 encoded string',
      'AGEAYgBj',
    );
    // source string: "abc" in UTF-16
    expect(
      scenario.answerOf('/data/decoded'),
      stringAnswer('\u0000a\u0000b\u0000c'),
    );
  });

  test('base64DecodeFunction_throwsWhenNotExactlyOneArg', () async {
    await expectLater(
      Scenario.init(
        html(
          head([
            title('Invalid base64 string'),
            model([
              mainInstance([
                t('data id="base64"', [tText('text', 'a'), t('decoded')]),
              ]),
              bind('/data/text')..type('string'),
              bind('/data/decoded')
                ..type('string')
                ..calculate('base64-decode()'),
            ]),
          ]),
          body([input('/data/text')]),
        ),
      ),
      throwsA(
        isA<TriggerableEvaluationException>().having(
          (e) => e.cause,
          'cause',
          isA<XPathUnhandledException>(),
        ),
      ),
    );
  });

  test('base64DecodeFunction_returnsEmptyStringWhenInputInvalid', () async {
    final scenario = await getBase64DecodeScenario(
      'Invalid base64 string',
      'a',
    );

    expect(scenario.answerOf('/data/decoded'), isNull);
  });
}
