import 'dart:math' as math;

/// A random (version 4) UUID such as `0f8fad5b-d9cb-469f-a165-70867728950e`.
///
/// Port of JavaRosa's `PropertyUtils.genUUID` (`UUID.randomUUID()`).
String randomUuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // IETF variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
