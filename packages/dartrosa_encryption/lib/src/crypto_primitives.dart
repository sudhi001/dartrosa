import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart' as pc;
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cfb.dart';

import 'rsa_public_key.dart';

/// The block (and IV) size of AES, Collect's `IV_BYTE_LENGTH`.
const aesBlockSize = 16;

/// Raw MD5 of [data].
Uint8List md5Bytes(List<int> data) =>
    Uint8List.fromList(crypto.md5.convert(data).bytes);

/// MD5 of [data] as 32 lowercase hex digits (zero-padded), as Collect's
/// `Md5.getMd5Hash`.
String md5Hex(List<int> data) => crypto.md5.convert(data).toString();

/// Collect's `ASYMMETRIC_ALGORITHM`, `RSA/NONE/OAEPWithSHA256AndMGF1Padding`:
/// RSAES-OAEP with SHA-256 as both the label hash and the MGF1 hash and an
/// empty label. The OAEP seed comes from [random].
Uint8List rsaOaepSha256Encrypt(
  RsaPublicKey key,
  Uint8List message,
  Random random,
) {
  final cipher = OAEPEncoding.withSHA256(RSAEngine())
    ..init(
      true,
      pc.ParametersWithRandom(
        pc.PublicKeyParameter<pc.RSAPublicKey>(
          pc.RSAPublicKey(key.modulus, key.exponent),
        ),
        _RandomAdapter(random),
      ),
    );
  if (message.length > cipher.inputBlockSize) {
    throw ArgumentError('RSA key too small for OAEP with SHA-256');
  }
  return cipher.process(message);
}

/// Collect's `SYMMETRIC_ALGORITHM`, `AES/CFB/PKCS5Padding` (BouncyCastle):
/// [data] padded PKCS#7-style to a multiple of 16 bytes (a whole padding
/// block when already aligned), then encrypted with AES in 128-bit CFB mode
/// under [key] and [iv].
Uint8List aesCfbPkcs5Encrypt(Uint8List key, Uint8List iv, Uint8List data) {
  final pad = aesBlockSize - data.length % aesBlockSize;
  final padded = Uint8List(data.length + pad)
    ..setAll(0, data)
    ..fillRange(data.length, data.length + pad, pad);
  final cipher = CFBBlockCipher(AESEngine(), aesBlockSize)
    ..init(true, pc.ParametersWithIV(pc.KeyParameter(key), iv));
  final out = Uint8List(padded.length);
  for (var offset = 0; offset < padded.length; offset += aesBlockSize) {
    cipher.processBlock(padded, offset, out, offset);
  }
  return out;
}

/// Fills a new list of [length] bytes from [random].
Uint8List randomBytes(Random random, int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// A pointycastle [pc.SecureRandom] drawing bytes from a [Random] (one
/// `nextInt(256)` per byte), so that tests can inject the randomness.
final class _RandomAdapter implements pc.SecureRandom {
  _RandomAdapter(this._random);

  final Random _random;

  @override
  String get algorithmName => 'dart:math Random';

  @override
  void seed(pc.CipherParameters params) {}

  @override
  int nextUint8() => _random.nextInt(256);

  @override
  int nextUint16() => (nextUint8() << 8) | nextUint8();

  @override
  int nextUint32() => (nextUint16() << 16) | nextUint16();

  @override
  BigInt nextBigInteger(int bitLength) {
    var value = BigInt.zero;
    for (final b in nextBytes((bitLength + 7) ~/ 8)) {
      value = (value << 8) | BigInt.from(b);
    }
    return value & ((BigInt.one << bitLength) - BigInt.one);
  }

  @override
  Uint8List nextBytes(int count) => randomBytes(_random, count);
}
