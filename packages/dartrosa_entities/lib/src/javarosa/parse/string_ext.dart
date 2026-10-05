/// Port of `org.odk.collect.entities.javarosa.parse.StringExt`.
library;

/// Whether [value] is a version 4 UUID, as Java's
/// `UUID.fromString(value).version() == 4` (so with Java's lenient
/// parsing: five `-`-separated hex groups of any length, at most 36
/// characters).
bool isV4Uuid(String? value) {
  if (value == null || value.length > 36) return false;
  final parts = value.split('-');
  if (parts.length != 5) return false;
  final groups = <int>[];
  for (final part in parts) {
    final parsed = _parseJavaHexLong(part);
    if (parsed == null) return false;
    groups.add(parsed);
  }
  // version() is bits 12-15 of the third group (its low 16 bits).
  return ((groups[2] & 0xffff) >> 12) & 0xf == 4;
}

final _javaHexLong = RegExp(r'^[+-]?[0-9a-fA-F]+$');
final _sign = RegExp('^[+-]');
final _maxLong = BigInt.parse('7fffffffffffffff', radix: 16);
final _minLong = -_maxLong - BigInt.one;

/// Java's `Long.parseLong(s, 16)`: an optional sign and hex digits.
int? _parseJavaHexLong(String s) {
  if (!_javaHexLong.hasMatch(s)) return null;
  final negative = s.startsWith('-');
  final digits = s.replaceFirst(_sign, '');
  final magnitude = BigInt.parse(digits, radix: 16);
  final signed = negative ? -magnitude : magnitude;
  if (signed > _maxLong || signed < _minLong) return null;
  // Masking to 16 bits only needs the low bits, which BigInt keeps
  // exactly (two's complement) on every platform.
  return (signed & BigInt.from(0xffffffff)).toInt();
}

/// [url] with the query parameters [params] appended (a `null` value is
/// written as `null`), as Collect's Android `String.toUri(params)`.
Uri toUriWithParams(String url, List<(String, String?)> params) {
  final uri = Uri.parse(url);
  final added = [
    for (final (key, value) in params)
      '${Uri.encodeComponent(key)}='
          '${Uri.encodeComponent(value ?? 'null')}',
  ].join('&');
  final query = uri.hasQuery && uri.query.isNotEmpty
      ? '${uri.query}&$added'
      : added;
  return uri.replace(query: query);
}
