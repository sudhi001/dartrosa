// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ExtractSignedTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ExtractSignedTest (Bouncy Castle's Ed25519
// becomes pinenacl's).
import 'dart:convert';

import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:pinenacl/ed25519.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

SigningKey createKeyPair() => SigningKey.generate();

/// The signature followed by the UTF-8 message.
Uint8List signMessage(String message, SigningKey privateKey) =>
    Uint8List.fromList(
      privateKey.sign(Uint8List.fromList(utf8.encode(message))).asTypedList,
    );

String encodedPublicKeyOf(SigningKey keyPair) =>
    base64Encode(keyPair.verifyKey.asTypedList);

Future<Scenario> createScenario(
  String encodedContents,
  String encodedPublicKey,
) => Scenario.init(
  html(
    head([
      title('extract signed form'),
      model([
        mainInstance([
          t('data id="extract-signed"', [
            tText('contents', encodedContents),
            t('extracted'),
          ]),
        ]),
        bind('/data/contents')..type('string'),
        bind('/data/extracted')
          ..type('string')
          ..calculate("extract-signed(/data/contents,'$encodedPublicKey')"),
      ]),
    ]),
    body([input('/data/contents')]),
  ),
);

void main() {
  test('whenSignatureIsValid_returnsNonSignatureContents', () async {
    const message = 'real genuine data';
    final keyPair = createKeyPair();

    final signedMessage = signMessage(message, keyPair);
    final encodedPublicKey = encodedPublicKeyOf(keyPair);
    final encodedContents = base64Encode(signedMessage);

    final scenario = await createScenario(encodedContents, encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), stringAnswer(message));
  });

  test('whenSignatureIsNotValid_returnsEmptyString', () async {
    const message = 'real genuine data';
    final keyPair1 = createKeyPair();
    final keyPair2 = createKeyPair();

    final signedMessage = signMessage(message, keyPair1);
    final encodedPublicKey = encodedPublicKeyOf(keyPair2);
    final encodedContents = base64Encode(signedMessage);

    final scenario = await createScenario(encodedContents, encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), isNull);
  });

  test('whenNoArgs_throwsException', () async {
    await expectLater(
      Scenario.init(
        html(
          head([
            title('extract signed form'),
            model([
              mainInstance([
                t('data id="extract-signed"', [
                  tText('contents', 'blah'),
                  t('extracted'),
                ]),
              ]),
              bind('/data/extracted')
                ..type('string')
                ..calculate('extract-signed()'),
            ]),
          ]),
          body([input('/data/contents')]),
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

  test('whenContentIsTooShort_returnsEmptyString', () async {
    final keyPair = createKeyPair();
    final encodedPublicKey = encodedPublicKeyOf(keyPair);

    final scenario = await createScenario('blah', encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), isNull);
  });

  test(
    'whenNonSignatureDataIsEmpty_andSignatureIsValid_returnsEmptyString',
    () async {
      const message = '';
      final keyPair = createKeyPair();

      final signedMessage = signMessage(message, keyPair);
      final encodedPublicKey = encodedPublicKeyOf(keyPair);
      final encodedContents = base64Encode(signedMessage);

      final scenario = await createScenario(encodedContents, encodedPublicKey);
      expect(scenario.answerOf('/data/extracted'), isNull);
    },
  );

  test('whenPublicKeyIsTooShort_returnsEmptyString', () async {
    const message = '';
    final keyPair = createKeyPair();

    final signedMessage = signMessage(message, keyPair);
    final encodedPublicKey = base64Encode(utf8.encode('blah'));
    final encodedContents = base64Encode(signedMessage);

    final scenario = await createScenario(encodedContents, encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), isNull);
  });

  test('whenPublicKeyIsInvalid_returnsEmptyString', () async {
    const message = '';
    final keyPair = createKeyPair();

    final signedMessage = signMessage(message, keyPair);
    // JavaRosa uses a random UUID's text.
    final encodedPublicKey = base64Encode(
      utf8.encode('3b241101-e2bb-4255-8caf-4136c566a962'),
    );
    final encodedContents = base64Encode(signedMessage);

    final scenario = await createScenario(encodedContents, encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), isNull);
  });

  test('whenNonSignaturePartIncludesUnicode_successfullyDecodes', () async {
    const message = '🎃';
    final keyPair = createKeyPair();

    final signedMessage = signMessage(message, keyPair);
    final encodedPublicKey = encodedPublicKeyOf(keyPair);
    final encodedContents = base64Encode(signedMessage);

    final scenario = await createScenario(encodedContents, encodedPublicKey);
    expect(scenario.answerOf('/data/extracted'), stringAnswer(message));
  });
}
