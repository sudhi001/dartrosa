// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DigestTest), Copyright 2018 Nafundi; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 DigestTest.
//
// DartRosa has no public `DigestAlgorithm`; `generates_a_digest` evaluates
// `digest()` with literal arguments instead of calling
// `DigestAlgorithm.digest` directly.
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

/// (test name, Java enum name of the algorithm, input, Java enum name of
/// the encoding, expected output).
const _data = <(String, String, String, String, String)>[
  ('MD5', 'MD5', 'some text', 'HEX', '552e21cd4cd9918678e3c1a0df491bc3'),
  (
    'SHA-1',
    'SHA1',
    'some text',
    'HEX',
    '37aa63c77398d954473262e1a0057c1e632eda77',
  ),
  (
    'SHA-256',
    'SHA256',
    'some text',
    'HEX',
    'b94f6f125c79e3a5ffaa826f584c10d52ada669e6762051b826b55776d05aed2',
  ),
  (
    'SHA-384',
    'SHA384',
    'some text',
    'HEX',
    'cc94ec3e9873c0b9a72486442958f671067cdf77b9427416d031440cc62041e2ee13444'
        '98447ec0ced9f7043461bd1f3',
  ),
  (
    'SHA-512',
    'SHA512',
    'some text',
    'HEX',
    'e2732baedca3eac1407828637de1dbca702c3fc9ece16cf536ddb8d6139cd85dfe7464b'
        '8235b29826f608ccf4ac643e29b19c637858a3d8710a59111df42ddb5',
  ),
  ('MD5', 'MD5', 'some text', 'BASE64', 'VS4hzUzZkYZ448Gg30kbww=='),
  ('SHA-1', 'SHA1', 'some text', 'BASE64', 'N6pjx3OY2VRHMmLhoAV8HmMu2nc='),
  (
    'SHA-256',
    'SHA256',
    'some text',
    'BASE64',
    'uU9vElx546X/qoJvWEwQ1SraZp5nYgUbgmtVd20FrtI=',
  ),
  (
    'SHA-384',
    'SHA384',
    'some text',
    'BASE64',
    'zJTsPphzwLmnJIZEKVj2cQZ833e5QnQW0DFEDMYgQeLuE0RJhEfsDO2fcENGG9Hz',
  ),
  (
    'SHA-512',
    'SHA512',
    'some text',
    'BASE64',
    '4nMrrtyj6sFAeChjfeHbynAsP8ns4Wz1Nt241hOc2F3+dGS4I1spgm9gjM9KxkPimxnGN4WK'
        'PYcQpZER30LdtQ==',
  ),
  (
    'MD5 HEX of empty string (baseline from forum feedback)',
    'MD5',
    '',
    'HEX',
    'd41d8cd98f00b204e9800998ecf8427e',
  ),
];

void main() {
  for (final (testName, algorithm, text, encoding, expectedOutput) in _data) {
    group('$testName ($encoding)', () {
      test('generates_a_digest', () {
        final result = parseXPath(
          "digest('$text', '$algorithm', '$encoding')",
        ).eval(null, EvaluationContext(null));
        expect(result, expectedOutput);
      });

      test('digestFunction_acceptsDynamicParameters', () async {
        final scenario = await Scenario.init(
          html(
            head([
              title('Digest form'),
              model([
                mainInstance([
                  t('data id="digest"', [
                    tText('my-text', text),
                    tText('my-algorithm', algorithm),
                    tText('my-encoding', encoding),
                    t('my-digest'),
                  ]),
                ]),
                bind('/data/my-text')..type('string'),
                bind('/data/my-algorithm')..type('string'),
                bind('/data/my-encoding')..type('string'),
                bind('/data/my-digest')
                  ..type('string')
                  ..calculate(
                    'digest(/data/my-text, /data/my-algorithm, '
                    '/data/my-encoding)',
                  ),
              ]),
            ]),
            body([
              input('/data/my-text'),
              input('/data/my-algorithm'),
              input('/data/my-encoding'),
            ]),
          ),
        );

        expect(
          scenario.answerOf('/data/my-digest'),
          stringAnswer(expectedOutput),
        );
      });
    });
  }
}
