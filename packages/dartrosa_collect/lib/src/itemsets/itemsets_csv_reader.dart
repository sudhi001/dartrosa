// Copyright 2026 The DartRosa Authors
// Derived from opencsv (CSVReader), Copyright 2005 Bytecode Pty Ltd., and ODK
//  Collect (FormLoaderTask); modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../util/read_lines.dart';

/// Thrown for a CSV that can't be read (an unterminated quoted field).
final class ItemsetsCsvException implements Exception {
  /// Creates the exception.
  const ItemsetsCsvException(this.message);

  /// What's wrong.
  final String message;

  @override
  String toString() => 'ItemsetsCsvException: $message';
}

/// Reads CSV records the way ODK Collect imports `itemsets.csv`.
///
/// Port of opencsv 5.12's default `CSVReader` (as `FormLoaderTask.readCSV`
/// creates it): separator `,`, quote `"`, escape `\\`, no strict quotes,
/// leading white space before quotes ignored, multi-line quoted fields,
/// and lines split like `BufferedReader.readLine` (`\n`, `\r` or
/// `\r\n`). Adapted from `CollectCsvReader` in `dartrosa_external_data`
/// (whose import uses the escape `\0`).
final class ItemsetsCsvReader {
  /// Creates a reader over the decoded file [text].
  ItemsetsCsvReader(String text) : _lines = readLines(text);

  static const _separator = 0x2C; // ,
  static const _quote = 0x22; // "
  static const _escape = 0x5C; // \\
  static const _beginningOfLine = 3;

  final List<String> _lines;
  var _nextLine = 0;
  String? _pending;
  var _inField = false;

  /// The next record, or `null` at the end of the input. Throws
  /// [ItemsetsCsvException] for an unterminated quoted field.
  List<String>? readNext() {
    List<String>? record;
    do {
      if (_nextLine >= _lines.length) {
        if (_pending != null) {
          final lost = _pending!;
          throw ItemsetsCsvException(
            'Unterminated quoted field at end of CSV line. Beginning of lost '
            'text: [${lost.length > 100 ? '${lost.substring(0, 97)}...' : lost}]',
          );
        }
        return record;
      }
      final tokens = _parseLine(_lines[_nextLine++]);
      if (tokens.isNotEmpty) (record ??= []).addAll(tokens);
    } while (_pending != null);
    return record;
  }

  /// `CSVParser.parseLine(nextLine, multi: true)`.
  List<String> _parseLine(String line) {
    final tokens = <String>[];
    final out = StringBuffer();
    var inQuotes = false;
    if (_pending != null) {
      out.write(_pending);
      _pending = null;
      inQuotes = true;
    }
    var i = 0;
    while (i < line.length) {
      final c = line.codeUnitAt(i++);
      if (c == _escape) {
        _inField = true;
        // handleEscapeCharacter
        if (_isNextCharacterEscapable(
          line,
          _inQuotesOrField(inQuotes),
          i - 1,
        )) {
          out.writeCharCode(line.codeUnitAt(i++));
        }
      } else if (c == _quote) {
        if (_isNextCharacterEscapedQuote(
          line,
          _inQuotesOrField(inQuotes),
          i - 1,
        )) {
          out.writeCharCode(line.codeUnitAt(i++));
        } else {
          inQuotes = !inQuotes;
          // handleQuoteCharButNotStrictQuotes: the tricky case of an
          // embedded quote in the middle: a,bc"d"ef,g
          if (i > _beginningOfLine &&
              line.codeUnitAt(i - 2) != _separator &&
              line.length > i &&
              line.codeUnitAt(i) != _separator) {
            if (out.isNotEmpty && _isWhitespace(out.toString())) {
              out.clear();
            } else {
              out.writeCharCode(c);
            }
          }
        }
        _inField = !_inField;
      } else if (c == _separator && !inQuotes) {
        tokens.add(out.toString());
        out.clear();
        _inField = false;
      } else {
        out.writeCharCode(c);
        _inField = true;
      }
    }
    if (inQuotes) {
      // Continuing a quoted section: re-append the newline.
      out.write('\n');
      _pending = out.toString();
      return tokens;
    }
    _inField = false;
    tokens.add(out.toString());
    return tokens;
  }

  bool _inQuotesOrField(bool inQuotes) => inQuotes || _inField;

  static bool _isNextCharacterEscapedQuote(String line, bool inQuotes, int i) =>
      inQuotes && line.length > i + 1 && line.codeUnitAt(i + 1) == _quote;

  static bool _isNextCharacterEscapable(String line, bool inQuotes, int i) {
    if (!inQuotes || line.length <= i + 1) return false;
    final next = line.codeUnitAt(i + 1);
    return next == _quote || next == _escape || next == _separator;
  }

  /// Commons Lang `StringUtils.isWhitespace` (Java `Character.isWhitespace`
  /// for every character).
  static bool _isWhitespace(String s) {
    for (final c in s.codeUnits) {
      final isJavaWhitespace =
          (c >= 0x09 && c <= 0x0D) ||
          (c >= 0x1C && c <= 0x20) ||
          c == 0x1680 ||
          (c >= 0x2000 && c <= 0x2006) ||
          (c >= 0x2008 && c <= 0x200A) ||
          c == 0x2028 ||
          c == 0x2029 ||
          c == 0x205F ||
          c == 0x3000;
      if (!isJavaWhitespace) return false;
    }
    return true;
  }
}
