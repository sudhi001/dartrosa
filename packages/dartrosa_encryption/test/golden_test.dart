import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:test/test.dart';

import 'src/counter_random.dart';
import 'src/golden_case.dart';
import 'src/golden_fixtures.dart';
import 'src/odk_decryptor.dart';

/// Compares with encryptions made by Collect's own code (EncryptionUtils on
/// the JVM, BouncyCastle, kXML 2.3.0; see tool/golden) given the same
/// random bytes.
void main() {
  final decryptor = OdkDecryptor.fromHex(
    testModulusHex,
    testPrivateExponentHex,
  );

  for (final golden in goldenCases) {
    group(golden.name, () {
      Map<String, Uint8List> media() => {
        for (final MapEntry(:key, :value) in golden.media.entries)
          key: base64.decode(value),
      };

      EncryptedFormInformation formInfo() =>
          EncryptedFormInformation.fromMetadata(
            formId: golden.formId,
            formVersion: golden.formVersion,
            base64RsaPublicKey: testPublicKeyBase64,
            instanceId: golden.instanceId,
            random: CounterRandom(golden.seed),
          )!;

      test('is byte-for-byte what Collect produces', () {
        final info = formInfo();
        final result = generateEncryptedSubmission(
          info,
          submissionXml: base64.decode(golden.submissionXml),
          mediaFiles: media(),
        );
        expect(info.elementSignatureSource, golden.signatureSource);
        expect(result.manifest, golden.manifest);
        expect(result.encryptedFiles.keys, golden.encryptedFiles.keys);
        for (final MapEntry(:key, :value) in golden.encryptedFiles.entries) {
          expect(
            base64.encode(result.encryptedFiles[key]!),
            value,
            reason: key,
          );
        }
        expect(result.mediaFileNames, golden.media.keys);
      });

      test("Collect's output decrypts with the ODK procedure", () {
        final decrypted = decryptor.decrypt(golden.manifest, {
          for (final MapEntry(:key, :value) in golden.encryptedFiles.entries)
            key: base64.decode(value),
        });
        expect(decrypted.submissionXml, base64.decode(golden.submissionXml));
        expect(decrypted.media, media());
      });
    });
  }
}
