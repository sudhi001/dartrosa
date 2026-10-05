// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EncryptionUtils, CipherOutputStream), Copyright (C)
//  2011 University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartrosa/javarosa.dart';

import 'crypto_primitives.dart';
import 'encryption_exception.dart';
import 'rsa_public_key.dart';

/// The `<submission>` attribute holding the form's public key.
const base64RsaPublicKeyAttribute = 'base64RsaPublicKey';

/// The per-submission encryption state: the random AES key, its RSA
/// encryption, the IV sequence and the element signature being built.
///
/// One instance encrypts one submission, its files in order (the IV changes
/// with each file), as Collect's state does. Create it with
/// [getEncryptedFormInformation] or [EncryptedFormInformation.fromMetadata].
///
/// Port of `org.odk.collect.android.utilities.EncryptionUtils
/// .EncryptedFormInformation`. BouncyCastle availability
/// (`isNotBouncyCastle`) has no equivalent: the ciphers are always
/// pointycastle's.
final class EncryptedFormInformation {
  EncryptedFormInformation._(
    this.formId,
    this.formVersion,
    this.instanceId,
    this.rsaPublicKey,
    this._random,
  ) {
    // generate the symmetric key from random bits...
    _symmetricKey = randomBytes(_random, symmetricKeyLength ~/ 8);

    // construct the fixed portion of the iv -- the ivSeedArray
    // this is the md5 hash of the instanceID and the symmetric key
    _ivSeedArray = md5Bytes([...utf8.encode(instanceId), ..._symmetricKey]);

    // construct the base64-encoded RSA-encrypted symmetric key
    base64RsaEncryptedSymmetricKey = base64.encode(
      rsaOaepSha256Encrypt(rsaPublicKey, _symmetricKey, _random),
    );

    // start building elementSignatureSource...
    appendElementSignatureSource(formId);
    if (formVersion != null) appendElementSignatureSource(formVersion!);
    appendElementSignatureSource(base64RsaEncryptedSymmetricKey);
    appendElementSignatureSource(instanceId);
  }

  /// The encryption information for a form with [formId], [formVersion]
  /// and public key [base64RsaPublicKey], for the instance [instanceId]
  /// (the instance's `meta/instanceID`).
  ///
  /// Returns `null` when [base64RsaPublicKey] is `null`: the form is
  /// legitimately not encrypted. Throws an [EncryptionException] when
  /// [formId] is missing (checked first, as in Collect, even for an
  /// unencrypted form), the key is invalid, or [instanceId] is `null`.
  ///
  /// [random] supplies the AES key and the OAEP seeds; it defaults to
  /// [Random.secure].
  ///
  /// Port of the checks in `EncryptionUtils.getEncryptedFormInformation`.
  static EncryptedFormInformation? fromMetadata({
    required String? formId,
    required String? formVersion,
    required String? base64RsaPublicKey,
    required String? instanceId,
    Random? random,
  }) {
    if (formId == null || formId.isEmpty) {
      throw const EncryptionException('No FormId specified???');
    }
    if (base64RsaPublicKey == null) {
      return null; // this is legitimately not an encrypted form
    }
    final RsaPublicKey key;
    try {
      key = RsaPublicKey.fromBase64(base64RsaPublicKey);
    } on FormatException catch (e) {
      throw EncryptionException('Invalid RSA public key.', e);
    }
    // submission must have an OpenRosa metadata block with a non-null
    // instanceID
    if (instanceId == null) {
      throw const EncryptionException(
        'This form does not specify an instanceID. You must specify one to '
        'enable encryption.',
      );
    }
    if (key.modulusLength < symmetricKeyLength ~/ 8 + 2 * 32 + 2) {
      throw const EncryptionException('Invalid RSA public key.');
    }
    return EncryptedFormInformation._(
      formId,
      formVersion,
      instanceId,
      key,
      random ?? Random.secure(),
    );
  }

  /// Collect's `SYMMETRIC_KEY_LENGTH`, in bits.
  static const symmetricKeyLength = 256;

  /// The form id (`id` attribute of the primary instance root).
  final String formId;

  /// The form version, or `null` if the form has none.
  final String? formVersion;

  /// The instance's `meta/instanceID`.
  final String instanceId;

  /// The form's public key.
  final RsaPublicKey rsaPublicKey;

  final Random _random;
  late final Uint8List _symmetricKey;
  late final Uint8List _ivSeedArray;
  var _ivCounter = 0;
  final _elementSignatureSource = StringBuffer();

  /// The AES key, RSA-encrypted and base64-encoded (`base64EncryptedKey`).
  late final String base64RsaEncryptedSymmetricKey;

  /// A copy of the 256-bit AES key.
  Uint8List get symmetricKey => Uint8List.fromList(_symmetricKey);

  /// The element signature source built so far: one line per element.
  String get elementSignatureSource => _elementSignatureSource.toString();

  /// Appends [value] and a newline to the element signature source.
  void appendElementSignatureSource(String value) {
    _elementSignatureSource
      ..write(value)
      ..write('\n');
  }

  /// Appends `name::md5` for the (unencrypted) file [name] with [content].
  void appendFileSignatureSource(String name, List<int> content) =>
      appendElementSignatureSource('$name::${md5Hex(content)}');

  /// The element signature: the MD5 of [elementSignatureSource],
  /// RSA-encrypted and base64-encoded
  /// (`base64EncryptedElementSignature`). Each call draws a fresh OAEP seed.
  ///
  /// The source is, one per line: formId, version (omitted if null),
  /// base64RsaEncryptedSymmetricKey, instanceId, `filename::md5` for each
  /// media file, `submission.xml::md5`.
  String getBase64EncryptedElementSignature() {
    final digest = md5Bytes(utf8.encode(_elementSignatureSource.toString()));
    return base64.encode(rsaOaepSha256Encrypt(rsaPublicKey, digest, _random));
  }

  /// Encrypts the next file's [content] with the AES key and the next IV.
  ///
  /// The IVs: the seed is the MD5 of the instance ID's UTF-8 bytes followed
  /// by the AES key; before each file, byte `counter % 16` of the seed is
  /// incremented (wrapping) and the counter advances, so the changes
  /// accumulate from file to file.
  ///
  /// Port of `getCipher` (with the `CipherOutputStream` use in
  /// `EncryptionUtils.encryptFile`).
  Uint8List encryptNextFile(Uint8List content) {
    final i = _ivCounter % _ivSeedArray.length;
    _ivSeedArray[i] = (_ivSeedArray[i] + 1) & 0xFF;
    ++_ivCounter;
    return aesCfbPkcs5Encrypt(
      _symmetricKey,
      Uint8List.fromList(_ivSeedArray),
      content,
    );
  }
}

/// The encryption information for submitting [form]'s current primary
/// instance, or `null` if the form isn't encrypted (its `<submission>` has
/// no `base64RsaPublicKey`).
///
/// The form id and version are the primary instance root's `id` and
/// `version` attributes (a blank version counts as none) and the instance
/// ID is the value of the root's `meta` child's single `instanceID` child,
/// as Collect's `FormMetadataParser` and
/// `JavaRosaFormController.getSubmissionMetadata` read them. [instanceId]
/// overrides the latter.
///
/// Throws an [EncryptionException] as
/// [EncryptedFormInformation.fromMetadata] does.
///
/// Port of `EncryptionUtils.getEncryptedFormInformation`.
EncryptedFormInformation? getEncryptedFormInformation(
  FormDef form, {
  String? instanceId,
  Random? random,
}) {
  final root = form.mainInstance.root;
  final version = root.getAttributeValue(null, 'version');
  return EncryptedFormInformation.fromMetadata(
    formId: root.getAttributeValue(null, 'id'),
    formVersion: version == null || version.trim().isEmpty ? null : version,
    base64RsaPublicKey: form.defaultSubmission?.attribute(
      base64RsaPublicKeyAttribute,
    ),
    instanceId: instanceId ?? _submissionInstanceId(root),
    random: random,
  );
}

String? _submissionInstanceId(TreeElement root) {
  final ids = root.firstChild('meta')?.childrenWithName('instanceID');
  if (ids == null || ids.length != 1) return null;
  return ids.single.value?.displayText;
}
