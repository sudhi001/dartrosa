/// The lines of [text] as Java's `BufferedReader.readLine` returns them:
/// split at `\n`, `\r` or `\r\n`, without a trailing empty line.
List<String> readLines(String text) {
  final lines = <String>[];
  var start = 0;
  var i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x0A || c == 0x0D) {
      lines.add(text.substring(start, i));
      i++;
      if (c == 0x0D && i < text.length && text.codeUnitAt(i) == 0x0A) i++;
      start = i;
    } else {
      i++;
    }
  }
  if (start < text.length) lines.add(text.substring(start));
  return lines;
}
