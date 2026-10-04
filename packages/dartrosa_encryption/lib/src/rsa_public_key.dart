import 'dart:convert';
import 'dart:typed_data';

/// An RSA public key, as read from a form's
/// `<submission base64RsaPublicKey="...">`.
///
/// Replaces Collect's use of `X509EncodedKeySpec` and
/// `KeyFactory.getInstance("RSA").generatePublic` in
/// `EncryptionUtils.getEncryptedFormInformation`.
final class RsaPublicKey {
  /// A key with [modulus] and public [exponent].
  RsaPublicKey(this.modulus, this.exponent);

  /// Decodes a base64 DER X.509 `SubjectPublicKeyInfo` holding an
  /// `rsaEncryption` key. Whitespace in [base64Key] is ignored and padding
  /// is optional, as with Android's `Base64.decode`.
  ///
  /// Throws a [FormatException] if [base64Key] is not such a key.
  factory RsaPublicKey.fromBase64(String base64Key) {
    final compact = base64Key.replaceAll(RegExp(r'[ \t\r\n]'), '');
    return RsaPublicKey.fromDer(base64.decode(base64.normalize(compact)));
  }

  /// Decodes a DER X.509 `SubjectPublicKeyInfo` holding an `rsaEncryption`
  /// key.
  ///
  /// Throws a [FormatException] if [der] is not such a key.
  factory RsaPublicKey.fromDer(Uint8List der) {
    final spki = _DerReader(der).read(_sequence);
    final algorithm = spki.read(_sequence);
    final oid = algorithm.readBytes(_objectIdentifier);
    if (!_listEquals(oid, _rsaEncryption)) {
      throw const FormatException('Not an RSA public key');
    }
    final bits = spki.readBytes(_bitString);
    if (bits.isEmpty || bits[0] != 0) {
      throw const FormatException('Malformed public key bit string');
    }
    final rsaKey = _DerReader(Uint8List.sublistView(bits, 1)).read(_sequence);
    final modulus = rsaKey.readInteger();
    final exponent = rsaKey.readInteger();
    if (modulus <= BigInt.zero || exponent <= BigInt.zero) {
      throw const FormatException('Invalid RSA key values');
    }
    return RsaPublicKey(modulus, exponent);
  }

  /// The modulus `n`.
  final BigInt modulus;

  /// The public exponent `e`.
  final BigInt exponent;

  /// The modulus size in bytes.
  int get modulusLength => (modulus.bitLength + 7) ~/ 8;

  static const _sequence = 0x30;
  static const _integer = 0x02;
  static const _bitString = 0x03;
  static const _objectIdentifier = 0x06;

  /// 1.2.840.113549.1.1.1
  static const _rsaEncryption = [
    0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, //
  ];

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Reads DER TLVs from a buffer.
final class _DerReader {
  _DerReader(this._bytes);

  final Uint8List _bytes;
  var _offset = 0;

  int _next() {
    if (_offset >= _bytes.length) {
      throw const FormatException('Truncated DER data');
    }
    return _bytes[_offset++];
  }

  Uint8List readBytes(int tag) {
    if (_next() != tag) throw const FormatException('Unexpected DER tag');
    var length = _next();
    if (length & 0x80 != 0) {
      final count = length & 0x7F;
      if (count == 0 || count > 4) {
        throw const FormatException('Unsupported DER length');
      }
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _next();
      }
    }
    if (_offset + length > _bytes.length) {
      throw const FormatException('Truncated DER data');
    }
    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }

  _DerReader read(int tag) => _DerReader(readBytes(tag));

  BigInt readInteger() {
    final bytes = readBytes(RsaPublicKey._integer);
    if (bytes.isEmpty) throw const FormatException('Empty DER integer');
    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }
    if (bytes[0] & 0x80 != 0) {
      value -= BigInt.one << (bytes.length * 8);
    }
    return value;
  }
}
