/// Appends [params] to the query of [url], as Collect's `String.toUri(vararg
/// Pair)` extension does with Android's `Uri.Builder.appendQueryParameter`:
/// keys and values are percent-encoded like `Uri.encode` and a `null` value
/// is written `null`. The rest of [url] is kept as it is.
///
/// Port of `org.odk.collect.entities.javarosa.parse.toUri`.
String appendQueryParameters(String url, List<(String, String?)> params) {
  final hash = url.indexOf('#');
  final fragment = hash == -1 ? '' : url.substring(hash);
  final beforeFragment = hash == -1 ? url : url.substring(0, hash);
  final question = beforeFragment.indexOf('?');
  final base = question == -1
      ? beforeFragment
      : beforeFragment.substring(0, question);
  var query = question == -1 ? '' : beforeFragment.substring(question + 1);
  for (final (key, value) in params) {
    final parameter = '${androidUriEncode(key)}=${androidUriEncode('$value')}';
    query = query.isEmpty ? parameter : '$query&$parameter';
  }
  return '$base?$query$fragment';
}

/// Percent-encodes [s] as UTF-8 except letters, digits and `_-!.~'()*`,
/// as Android's `Uri.encode` does.
String androidUriEncode(String s) {
  const allowed = "_-!.~'()*";
  final out = StringBuffer();
  for (final rune in s.runes) {
    if ((rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune < 0x80 && allowed.contains(String.fromCharCode(rune)))) {
      out.writeCharCode(rune);
    } else {
      for (final byte in _utf8(rune)) {
        out
          ..write('%')
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
  }
  return out.toString();
}

List<int> _utf8(int rune) {
  if (rune < 0x80) return [rune];
  if (rune < 0x800) return [0xC0 | (rune >> 6), 0x80 | (rune & 0x3F)];
  if (rune < 0x10000) {
    return [
      0xE0 | (rune >> 12),
      0x80 | ((rune >> 6) & 0x3F),
      0x80 | (rune & 0x3F),
    ];
  }
  return [
    0xF0 | (rune >> 18),
    0x80 | ((rune >> 12) & 0x3F),
    0x80 | ((rune >> 6) & 0x3F),
    0x80 | (rune & 0x3F),
  ];
}

/// Whether `java.net.URI` accepts [url]'s characters: no spaces, control
/// characters, `"<>\\^`{|}` or `%` not starting an escape.
bool hasValidJavaUriCharacters(String url) =>
    !_illegalJavaUriCharacter.hasMatch(url) && !_percentNotEscape.hasMatch(url);

final _illegalJavaUriCharacter = RegExp(r'[\x00-\x20"<>\\^`{|}\x7F]');
final _percentNotEscape = RegExp(r'%(?![0-9A-Fa-f]{2})');
