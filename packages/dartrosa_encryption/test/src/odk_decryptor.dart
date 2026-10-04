import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:xml/xml.dart';

/// A decrypted submission.
final class DecryptedSubmission {
  DecryptedSubmission(this.submissionXml, this.media);

  /// The decrypted `submission.xml`.
  final Uint8List submissionXml;

  /// The decrypted media files by (unencrypted) name, in manifest order.
  final Map<String, Uint8List> media;
}

/// The documented ODK decryption procedure (ODK Briefcase's
/// `CryptoUtils`/`FileSystemUtils.decryptFile` and ODK Central's
/// `lib/util/crypto.js`), written independently of the code under test:
/// textbook RSA with the private key, hand-written OAEP (SHA-256, MGF1
/// SHA-256) decoding and CFB-128 mode over a raw AES block, PKCS#5 padding
/// removal, and Briefcase's element signature check.
final class OdkDecryptor {
  OdkDecryptor(this.modulus, this.privateExponent);

  /// From hex strings.
  OdkDecryptor.fromHex(String modulus, String privateExponent)
    : this(
        BigInt.parse(modulus, radix: 16),
        BigInt.parse(privateExponent, radix: 16),
      );

  final BigInt modulus;
  final BigInt privateExponent;

  int get _k => (modulus.bitLength + 7) ~/ 8;

  /// Decrypts a submission given its [manifest] and the encrypted [files]
  /// by name. Throws a [StateError] if anything doesn't check out.
  DecryptedSubmission decrypt(String manifest, Map<String, Uint8List> files) {
    final data = XmlDocument.parse(manifest).rootElement;
    const ns = 'http://www.opendatakit.org/xforms/encrypted';
    _check(data.name.local == 'data' && data.namespaceUri == ns, 'root');
    _check(data.getAttribute('encrypted') == 'yes', 'encrypted="yes"');
    final formId = data.getAttribute('id')!;
    final version = data.getAttribute('version');
    String text(String name) =>
        data.findElements(name, namespace: ns).single.innerText;
    final encryptedKey = text('base64EncryptedKey');
    final instanceId = data
        .findElements('meta', namespace: 'http://openrosa.org/xforms')
        .single
        .findElements('instanceID', namespace: 'http://openrosa.org/xforms')
        .single
        .innerText;
    final mediaNames = [
      for (final media in data.findElements('media', namespace: ns))
        media.findElements('file', namespace: ns).single.innerText,
    ];
    final xmlName = text('encryptedXmlFile');
    final signature = text('base64EncryptedElementSignature');

    final aesKey = rsaOaepDecrypt(base64.decode(encryptedKey));
    _check(aesKey.length == 32, 'AES key length');

    // IVs: md5(instanceId utf-8 || key), byte (i % 16) incremented before
    // file i, cumulatively.
    final iv = Uint8List.fromList(
      md5.convert([...utf8.encode(instanceId), ...aesKey]).bytes,
    );
    var counter = 0;
    Uint8List decryptNext(String name) {
      iv[counter % 16] = (iv[counter % 16] + 1) & 0xFF;
      counter++;
      final encrypted = files[name];
      _check(encrypted != null, 'missing $name');
      return aesCfbDecryptUnpad(aesKey, iv, encrypted!);
    }

    final media = <String, Uint8List>{};
    for (final name in mediaNames) {
      _check(name.endsWith('.enc'), 'media name');
      media[name.substring(0, name.length - 4)] = decryptNext(name);
    }
    final xml = decryptNext(xmlName);

    // Briefcase's signature verification.
    final source = StringBuffer()
      ..write('$formId\n')
      ..write(version == null ? '' : '$version\n')
      ..write('$encryptedKey\n')
      ..write('$instanceId\n');
    for (final MapEntry(:key, :value) in media.entries) {
      source.write('$key::${md5.convert(value)}\n');
    }
    source.write(
      '${xmlName.substring(0, xmlName.length - 4)}::${md5.convert(xml)}\n',
    );
    final expected = md5.convert(utf8.encode(source.toString())).bytes;
    final actual = rsaOaepDecrypt(base64.decode(signature));
    _check(_equal(expected, actual), 'element signature');
    return DecryptedSubmission(xml, media);
  }

  /// RSAES-OAEP decryption, SHA-256 and MGF1-SHA-256, empty label.
  Uint8List rsaOaepDecrypt(List<int> ciphertext) {
    _check(ciphertext.length == _k, 'RSA ciphertext length');
    final c = _toBigInt(ciphertext);
    final em = _fromBigInt(c.modPow(privateExponent, modulus), _k);
    const hLen = 32;
    _check(em[0] == 0, 'OAEP leading byte');
    final maskedSeed = em.sublist(1, 1 + hLen);
    final maskedDb = em.sublist(1 + hLen);
    final seed = _xor(maskedSeed, _mgf1(maskedDb, hLen));
    final db = _xor(maskedDb, _mgf1(seed, maskedDb.length));
    _check(
      _equal(db.sublist(0, hLen), sha256.convert(const []).bytes),
      'OAEP label hash',
    );
    var i = hLen;
    while (db[i] == 0) {
      i++;
    }
    _check(db[i] == 1, 'OAEP separator');
    return Uint8List.fromList(db.sublist(i + 1));
  }

  /// AES-256 in CFB-128 mode (decryption) followed by PKCS#5 unpadding.
  static Uint8List aesCfbDecryptUnpad(
    List<int> key,
    List<int> iv,
    Uint8List encrypted,
  ) {
    _check(encrypted.isNotEmpty && encrypted.length % 16 == 0, 'AES length');
    final aes = AESEngine()..init(true, KeyParameter(Uint8List.fromList(key)));
    final out = Uint8List(encrypted.length);
    var feedback = Uint8List.fromList(iv);
    for (var off = 0; off < encrypted.length; off += 16) {
      final stream = Uint8List(16);
      aes.processBlock(feedback, 0, stream, 0);
      for (var j = 0; j < 16; j++) {
        out[off + j] = encrypted[off + j] ^ stream[j];
      }
      feedback = Uint8List.fromList(encrypted.sublist(off, off + 16));
    }
    final pad = out.last;
    _check(pad >= 1 && pad <= 16, 'padding');
    for (var j = out.length - pad; j < out.length; j++) {
      _check(out[j] == pad, 'padding bytes');
    }
    return Uint8List.sublistView(out, 0, out.length - pad);
  }

  static Uint8List _mgf1(List<int> seed, int length) {
    final out = <int>[];
    for (var counter = 0; out.length < length; counter++) {
      out.addAll(
        sha256.convert([
          ...seed,
          counter >> 24 & 0xFF,
          counter >> 16 & 0xFF,
          counter >> 8 & 0xFF,
          counter & 0xFF,
        ]).bytes,
      );
    }
    return Uint8List.fromList(out.sublist(0, length));
  }

  static Uint8List _xor(List<int> a, List<int> b) =>
      Uint8List.fromList([for (var i = 0; i < a.length; i++) a[i] ^ b[i]]);

  static BigInt _toBigInt(List<int> bytes) {
    var v = BigInt.zero;
    for (final b in bytes) {
      v = (v << 8) | BigInt.from(b);
    }
    return v;
  }

  static Uint8List _fromBigInt(BigInt v, int length) {
    final out = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      out[i] = (v & BigInt.from(0xFF)).toInt();
      v >>= 8;
    }
    return out;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static void _check(bool ok, String what) {
    if (!ok) throw StateError('Decryption failed: $what');
  }
}
