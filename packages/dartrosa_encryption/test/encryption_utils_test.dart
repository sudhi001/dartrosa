// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'src/counter_random.dart';
import 'src/golden_fixtures.dart';
import 'src/odk_decryptor.dart';

const _instanceId = 'uuid:7a3c1f52-0d6e-4b2a-9e1f-5c8d2b4a6e01';

Uint8List _bytes(String s) => utf8.encode(s);

EncryptedFormInformation _info({
  String formId = 'test-form',
  String? formVersion = '1',
  String instanceId = _instanceId,
  Random? random,
}) => EncryptedFormInformation.fromMetadata(
  formId: formId,
  formVersion: formVersion,
  base64RsaPublicKey: testPublicKeyBase64,
  instanceId: instanceId,
  random: random,
)!;

/// Replaces the form's key with the test key (whose private key we hold).
String _withTestKey(String form) => form.replaceFirst(
  RegExp('base64RsaPublicKey="[^"]*"'),
  'base64RsaPublicKey="$testPublicKeyBase64"',
);

void main() {
  final decryptor = OdkDecryptor.fromHex(
    testModulusHex,
    testPrivateExponentHex,
  );

  group('round trip through the ODK decryption procedure', () {
    test('submission and media files', () {
      final xml = _bytes('<data id="test-form"><a>Zoë ✓</a></data>');
      final media = {
        'photo.jpg': Uint8List.fromList(List.generate(70000, (i) => i * 31)),
        'voice note.m4a': _bytes('audio'),
        'blank.txt': Uint8List(0),
        'block.bin': Uint8List(16),
      };
      final result = generateEncryptedSubmission(
        _info(),
        submissionXml: xml,
        mediaFiles: media,
      );
      final decrypted = decryptor.decrypt(
        result.manifest,
        result.encryptedFiles,
      );
      expect(decrypted.submissionXml, xml);
      expect(decrypted.media, media);
      expect(decrypted.media.keys, media.keys, reason: 'order kept');
    });

    test('with a secure random, two encryptions differ', () {
      final xml = _bytes('<data/>');
      final a = generateEncryptedSubmission(_info(), submissionXml: xml);
      final b = generateEncryptedSubmission(_info(), submissionXml: xml);
      expect(a.manifest, isNot(b.manifest));
      expect(
        a.encryptedFiles['submission.xml.enc'],
        isNot(b.encryptedFiles['submission.xml.enc']),
      );
      expect(
        decryptor.decrypt(a.manifest, a.encryptedFiles).submissionXml,
        xml,
      );
      expect(
        decryptor.decrypt(b.manifest, b.encryptedFiles).submissionXml,
        xml,
      );
    });

    test('is deterministic given the random source', () {
      EncryptedSubmission run() => generateEncryptedSubmission(
        _info(random: CounterRandom(42)),
        submissionXml: _bytes('<data/>'),
        mediaFiles: {'a.png': _bytes('png')},
      );
      final a = run();
      final b = run();
      expect(a.manifest, b.manifest);
      expect(a.encryptedFiles, b.encryptedFiles);
    });

    test('more than 16 files wrap the IV counter', () {
      final media = {for (var i = 0; i < 40; i++) 'f$i.txt': _bytes('file $i')};
      final xml = _bytes('<data/>');
      final result = generateEncryptedSubmission(
        _info(random: Random(1)),
        submissionXml: xml,
        mediaFiles: media,
      );
      final decrypted = decryptor.decrypt(
        result.manifest,
        result.encryptedFiles,
      );
      expect(decrypted.media, media);
      expect(decrypted.submissionXml, xml);
    });
  });

  group('generateEncryptedSubmission', () {
    test('names the files with .enc, submission.xml last', () {
      final result = generateEncryptedSubmission(
        _info(),
        submissionXml: _bytes('<data/>'),
        mediaFiles: {'b.jpg': _bytes('b'), 'a.jpg': _bytes('a')},
      );
      expect(result.encryptedFiles.keys, [
        'b.jpg.enc',
        'a.jpg.enc',
        'submission.xml.enc',
      ]);
      expect(result.mediaFileNames, ['b.jpg', 'a.jpg']);
      expect(result.encryptedXmlFileName, 'submission.xml.enc');
    });

    test('pads to whole AES blocks', () {
      final result = generateEncryptedSubmission(
        _info(),
        submissionXml: Uint8List(15),
        mediaFiles: {'empty': Uint8List(0), 'sixteen': Uint8List(16)},
      );
      expect(result.encryptedFiles['empty.enc'], hasLength(16));
      expect(result.encryptedFiles['sixteen.enc'], hasLength(32));
      expect(result.encryptedFiles['submission.xml.enc'], hasLength(16));
    });

    test('skips dot files, leftover .enc files and submission.xml', () {
      final result = generateEncryptedSubmission(
        _info(),
        submissionXml: _bytes('<data/>'),
        mediaFiles: {
          '.DS_Store': _bytes('x'),
          'old.jpg.enc': _bytes('x'),
          'submission.xml': _bytes('x'),
          'kept.jpg': _bytes('x'),
        },
      );
      expect(result.mediaFileNames, ['kept.jpg']);
      expect(result.encryptedFiles.keys, [
        'kept.jpg.enc',
        'submission.xml.enc',
      ]);
    });

    test('the manifest has the shape Central and Briefcase read', () {
      final info = _info(formVersion: '2024');
      final result = generateEncryptedSubmission(
        info,
        submissionXml: _bytes('<data/>'),
        mediaFiles: {'a.jpg': _bytes('a')},
      );
      expect(result.manifest, startsWith('<data id="test-form" '));
      expect(result.manifestBytes, utf8.encode(result.manifest));
      final root = XmlDocument.parse(result.manifest).rootElement;
      const ns = 'http://www.opendatakit.org/xforms/encrypted';
      expect(root.namespaceUri, ns);
      expect(root.getAttribute('version'), '2024');
      expect(root.getAttribute('encrypted'), 'yes');
      expect(root.childElements.map((e) => e.name.qualified), [
        'base64EncryptedKey',
        'orx:meta',
        'media',
        'encryptedXmlFile',
        'base64EncryptedElementSignature',
      ]);
      expect(
        root.getElement('base64EncryptedKey')!.innerText,
        info.base64RsaEncryptedSymmetricKey,
      );
      expect(root.getElement('orx:meta')!.innerText, _instanceId);
      expect(root.getElement('media')!.innerText, 'a.jpg.enc');
      expect(
        root.getElement('encryptedXmlFile')!.innerText,
        'submission.xml.enc',
      );
    });

    test("the element signature source follows Collect's order", () {
      final info = _info(formVersion: null);
      generateEncryptedSubmission(
        info,
        submissionXml: _bytes('<data/>'),
        mediaFiles: {'a.jpg': _bytes('Hello, world')},
      );
      expect(
        info.elementSignatureSource,
        'test-form\n'
        '${info.base64RsaEncryptedSymmetricKey}\n'
        '$_instanceId\n'
        // Collect's Md5Test value for "Hello, world".
        'a.jpg::bc6e6f16b8a077ef5fbc8d59d0b931b9\n'
        'submission.xml::${_md5('<data/>')}\n',
      );
    });

    test('MD5 hashes are zero-padded to 32 digits', () {
      final info = _info();
      // md5("jk8ssl") = 0000000018e6137ac2caab16074784a6
      info.appendFileSignatureSource('x', _bytes('jk8ssl'));
      expect(
        info.elementSignatureSource,
        endsWith('x::0000000018e6137ac2caab16074784a6\n'),
      );
    });
  });

  group('EncryptedFormInformation.fromMetadata', () {
    test('an unencrypted form gives null', () {
      expect(
        EncryptedFormInformation.fromMetadata(
          formId: 'f',
          formVersion: null,
          base64RsaPublicKey: null,
          instanceId: null,
        ),
        isNull,
      );
    });

    test('a missing form id throws, even without a key (as Collect)', () {
      for (final id in [null, '']) {
        expect(
          () => EncryptedFormInformation.fromMetadata(
            formId: id,
            formVersion: null,
            base64RsaPublicKey: null,
            instanceId: _instanceId,
          ),
          throwsA(
            isA<EncryptionException>().having(
              (e) => e.message,
              'message',
              'No FormId specified???',
            ),
          ),
        );
      }
    });

    test('an invalid key throws', () {
      for (final key in ['quux', 'AAAA', '', 'MIIB!!']) {
        expect(
          () => EncryptedFormInformation.fromMetadata(
            formId: 'f',
            formVersion: null,
            base64RsaPublicKey: key,
            instanceId: _instanceId,
          ),
          throwsA(
            isA<EncryptionException>().having(
              (e) => e.message,
              'message',
              'Invalid RSA public key.',
            ),
          ),
        );
      }
    });

    test('a missing instance ID throws', () {
      expect(
        () => EncryptedFormInformation.fromMetadata(
          formId: 'f',
          formVersion: null,
          base64RsaPublicKey: testPublicKeyBase64,
          instanceId: null,
        ),
        throwsA(
          isA<EncryptionException>().having(
            (e) => e.message,
            'message',
            'This form does not specify an instanceID. You must specify one '
                'to enable encryption.',
          ),
        ),
      );
    });

    test('accepts a key with whitespace and without padding', () {
      final wrapped = testPublicKeyBase64
          .replaceAllMapped(RegExp('.{64}'), (m) => '${m[0]}\n')
          .replaceAll('=', '');
      final info = EncryptedFormInformation.fromMetadata(
        formId: 'f',
        formVersion: null,
        base64RsaPublicKey: wrapped,
        instanceId: _instanceId,
      )!;
      expect(
        info.rsaPublicKey.modulus,
        BigInt.parse(testModulusHex, radix: 16),
      );
      expect(info.rsaPublicKey.exponent, BigInt.from(65537));
    });

    test('the symmetric key is 256 random bits', () {
      final info = _info(random: CounterRandom(0));
      expect(info.symmetricKey, List.generate(32, (i) => i));
    });
  });

  group("Collect's encrypted test forms", () {
    Future<FormSession> start(String xml) async =>
        (await FormDefinition.parse(xml)).createSession();

    test('encrypted.xml: finalize, encrypt, decrypt', () async {
      final definition = await FormDefinition.parse(
        _withTestKey(collectEncryptedForm),
      );
      final session = definition.createSession();
      final submission = (session.finalize() as FinalizeSuccess).submission;
      final xml = _bytes(submission.xml);
      final encrypted = encryptSubmission(xml, {
        'photo.jpg': _bytes('jpeg'),
      }, definition.formDef)!;
      final root = XmlDocument.parse(encrypted.manifest).rootElement;
      expect(root.getAttribute('id'), 'encrypted');
      expect(root.getAttribute('version'), isNull);
      expect(root.getElement('orx:meta')!.innerText, submission.instanceId);
      expect(submission.instanceId, startsWith('uuid:'));
      final decrypted = decryptor.decrypt(
        encrypted.manifest,
        encrypted.encryptedFiles,
      );
      expect(decrypted.submissionXml, xml);
      expect(decrypted.media, {'photo.jpg': _bytes('jpeg')});
    });

    test("encrypted.xml with Collect's own key", () async {
      final session = await start(collectEncryptedForm);
      final form = session.definition.formDef;
      final info = getEncryptedFormInformation(form)!;
      expect(info.formId, 'encrypted');
      expect(info.formVersion, isNull);
      expect(info.rsaPublicKey.modulusLength, 256);
      final result = generateEncryptedSubmission(
        info,
        submissionXml: _bytes('<encrypted/>'),
      );
      expect(result.encryptedFiles.keys, ['submission.xml.enc']);
      expect(
        base64.decode(info.base64RsaEncryptedSymmetricKey),
        hasLength(256),
      );
    });

    test('encrypted-no-instanceID.xml cannot be encrypted', () async {
      final session = await start(collectEncryptedNoInstanceIdForm);
      expect(
        () => getEncryptedFormInformation(session.definition.formDef),
        throwsA(isA<EncryptionException>()),
      );
    });

    test(
      'one-question-encrypted-unicode.xml: unicode id and version',
      () async {
        final definition = await FormDefinition.parse(
          _withTestKey(collectEncryptedUnicodeForm),
        );
        final session = definition.createSession();
        final submission = (session.finalize() as FinalizeSuccess).submission;
        final encrypted = encryptSubmission(
          _bytes(submission.xml),
          const {},
          definition.formDef,
        )!;
        expect(
          encrypted.manifest,
          startsWith(
            '<data id="one_questión_encrypted_unicode" version="versión 4" ',
          ),
        );
        final decrypted = decryptor.decrypt(
          encrypted.manifest,
          encrypted.encryptedFiles,
        );
        expect(utf8.decode(decrypted.submissionXml), submission.xml);
      },
    );

    test('an unencrypted form gives null', () async {
      final definition = await FormDefinition.parse(
        collectEncryptedForm.replaceFirst(RegExp('<submission [^>]*/>'), ''),
      );
      definition.createSession();
      expect(
        encryptSubmission(_bytes('<x/>'), const {}, definition.formDef),
        isNull,
      );
    });

    test("instanceId overrides the instance's", () async {
      final session = await start(_withTestKey(collectEncryptedForm));
      final info = getEncryptedFormInformation(
        session.definition.formDef,
        instanceId: 'uuid:override',
      )!;
      expect(info.instanceId, 'uuid:override');
    });
  });

  group('RsaPublicKey', () {
    test('rejects a non-RSA key', () {
      // An EC P-256 SubjectPublicKeyInfo.
      const ec =
          'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE7vOq6w2yYgZJ1kY4fS6Q3m4x0xmD'
          'yRk2pNw0bJz8GvjKMbH5V1QnD5XcI5sYv0dN1e6v9XfRj2bS0kq9xYvW1g==';
      expect(() => RsaPublicKey.fromBase64(ec), throwsFormatException);
    });
  });
}

String _md5(String s) => crypto.md5.convert(utf8.encode(s)).toString();
