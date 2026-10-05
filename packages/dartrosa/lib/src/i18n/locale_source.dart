/// Sources of localized text for a [Localizer].
///
/// @docImport 'localizer.dart';
library;

import '../util/java_lang.dart';

/// A source of text mappings (text id → text) for one locale.
///
/// Port of `org.javarosa.core.services.locale.LocaleDataSource`.
abstract interface class LocaleDataSource {
  /// The mappings, in insertion order.
  Map<String, String> get localizedText;
}

/// An in-memory table of text mappings; the XForm parser fills one per
/// `<translation>`.
///
/// Port of `org.javarosa.core.services.locale.TableLocaleSource`.
final class TableLocaleSource implements LocaleDataSource {
  /// Creates a table, optionally starting from [data] (used as is).
  TableLocaleSource([Map<String, String>? data]) : _data = data ?? {};

  final Map<String, String> _data;

  /// Maps [textId] to [text]; a `null` [text] removes the mapping.
  void setLocaleMapping(String textId, String? text) {
    if (text == null) {
      _data.remove(textId);
    } else {
      _data[textId] = text;
    }
  }

  /// Whether [textId] has a mapping (`false` for `null`).
  bool hasMapping(String? textId) => textId != null && _data[textId] != null;

  @override
  Map<String, String> get localizedText => _data;
}

/// Parses a `key=value` locale file: one mapping per line, `#` starts a
/// comment, blank and malformed lines are skipped, a key with nothing after
/// `=` is skipped.
///
/// Port of `LocalizationUtils.parseLocaleInput` (from a string instead of a
/// stream). JavaRosa reads 100-character chunks and treats `\r` as a line
/// break only in a chunk that contains no `\n`; that is reproduced here.
Map<String, String> parseLocaleInput(String input) {
  final locale = <String, String>{};
  const chunk = 100;
  final line = StringBuffer();
  for (var offset = 0; offset < input.length; offset += chunk) {
    final end = offset + chunk < input.length ? offset + chunk : input.length;
    final piece = input.substring(offset, end);
    var index = 0;
    while (true) {
      var next = piece.indexOf('\n', index);
      if (next == -1) next = piece.indexOf('\r', index);
      if (next == -1) {
        line.write(piece.substring(index));
        break;
      }
      line.write(piece.substring(index, next));
      _parseAndAdd(locale, line.toString());
      line.clear();
      index = next + 1;
    }
  }
  if (line.isNotEmpty) _parseAndAdd(locale, line.toString());
  return locale;
}

void _parseAndAdd(Map<String, String> locale, String rawLine) {
  var line = javaTrim(rawLine);
  final hash = line.indexOf('#');
  if (hash != -1) line = line.substring(0, hash);
  final equals = line.indexOf('=');
  if (equals == -1 || equals == line.length - 1) return;
  locale[line.substring(0, equals)] = line.substring(equals + 1);
}
