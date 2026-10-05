/// CSV secondary instances (`jr://file-csv/…`).
///
/// Port of `CsvExternalInstance` and `SecondaryInstanceCSVParserBuilder`,
/// with a faithful port of the parts of Apache commons-csv 1.4
/// (`CSVFormat.DEFAULT.withFirstRecordAsHeader()`) JavaRosa relies on.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../data/answer_value.dart';
import '../tree_element.dart';
import 'external_instance_parser.dart';
import 'instance_format_exception.dart';

/// Parses CSV files into `root/item/<column>` instances.
///
/// The first line names the columns; the delimiter is `;` if that line
/// contains one, otherwise `,`. Values keep their whitespace; missing
/// trailing fields become `''`, extra fields are ignored.
final class CsvExternalInstance implements FileInstanceParser {
  /// Creates the parser.
  const CsvExternalInstance();

  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      instanceSrc.contains('file-csv');

  @override
  TreeElement parse(
    String instanceId,
    Uint8List bytes, {
    bool partial = false,
  }) => parseCsvInstance(instanceId, utf8.decode(bytes, allowMalformed: true));
}

/// Parses CSV [text] into an instance named [instanceId].
///
/// A leading UTF-8 byte-order mark is ignored (JavaRosa reads through
/// `BOMInputStream`). An empty file fails, as in JavaRosa (where reading
/// its missing header line throws a `NullPointerException`).
TreeElement parseCsvInstance(String instanceId, String text) {
  final delimiter = _delimiter(text);
  final content = text.startsWith('﻿') ? text.substring(1) : text;
  final records = CsvReader(content, delimiter).readAll();

  final root = TreeElement('root', 0)..instanceName = instanceId;
  if (records.isEmpty) return root;
  final fieldNames = _header(records.first);
  for (var m = 1; m < records.length; m++) {
    final record = records[m];
    final item = TreeElement('item', m - 1);
    for (var i = 0; i < fieldNames.length; i++) {
      item.addChild(
        TreeElement(fieldNames[i], 0)
          ..value = UncastValue(i < record.length ? record[i] : ''),
      );
    }
    root.addChild(item);
  }
  return root;
}

/// JavaRosa's delimiter detection: `;` if the first line contains one.
String _delimiter(String text) {
  if (text.isEmpty) {
    throw StateError('CSV secondary instance is empty (no header line)');
  }
  final end = text.indexOf(RegExp('[\r\n]'));
  final header = end < 0 ? text : text.substring(0, end);
  return header.contains(';') ? ';' : ',';
}

/// commons-csv's header map: names in order; a repeated name fails unless
/// it is blank (CSVFormat.DEFAULT doesn't allow missing column names, so
/// a repeated blank name fails too).
List<String> _header(List<String> record) {
  final names = <String>[];
  for (final name in record) {
    if (names.contains(name)) {
      throw ArgumentError(
        'The header contains a duplicate name: "$name" in '
        '[${record.join(', ')}]',
      );
    }
    names.add(name);
  }
  return names;
}

/// A CSV reader with commons-csv 1.4 `CSVFormat.DEFAULT` semantics:
/// `"` quoting with `""` escapes, `\r`, `\n` or `\r\n` record separators,
/// empty lines skipped, no comments, no trimming.
final class CsvReader {
  /// Reads [input] with [delimiter] (a single character).
  CsvReader(String input, String delimiter)
    : _input = input,
      _delimiter = delimiter.codeUnitAt(0);

  final String _input;
  final int _delimiter;
  int _position = 0;
  int _lastChar = _undefined;
  int _line = 1;

  static const _eof = -1;
  static const _undefined = -2;
  static const _cr = 0x0D;
  static const _lf = 0x0A;
  static const _quote = 0x22;

  /// All records, each a list of field values.
  List<List<String>> readAll() {
    final records = <List<String>>[];
    while (true) {
      final record = _nextRecord();
      if (record == null) return records;
      records.add(record);
    }
  }

  int _read() {
    if (_position >= _input.length) {
      _lastChar = _eof;
      return _eof;
    }
    final c = _input.codeUnitAt(_position++);
    if (c == _cr || (c == _lf && _lastChar != _cr)) _line++;
    _lastChar = c;
    return c;
  }

  int _lookAhead() =>
      _position < _input.length ? _input.codeUnitAt(_position) : _eof;

  bool _readEndOfLine(int c) {
    var ch = c;
    if (ch == _cr && _lookAhead() == _lf) ch = _read();
    return ch == _lf || ch == _cr;
  }

  static bool _isStartOfLine(int c) => c == _lf || c == _cr || c == _undefined;

  List<String>? _nextRecord() {
    final record = <String>[];
    while (true) {
      final token = _nextToken();
      switch (token.type) {
        case _TokenType.token:
          record.add(token.content);
          continue;
        case _TokenType.endOfRecord:
          record.add(token.content);
        case _TokenType.eof:
          if (token.isReady) record.add(token.content);
        case _TokenType.invalid:
          throw InstanceFormatException('(line $_line) invalid parse sequence');
      }
      break;
    }
    return record.isEmpty ? null : record;
  }

  _Token _nextToken() {
    final token = _Token();
    var lastChar = _lastChar;
    var c = _read();
    var eol = _readEndOfLine(c);

    // Skip empty lines.
    while (eol && _isStartOfLine(lastChar)) {
      lastChar = c;
      c = _read();
      eol = _readEndOfLine(c);
      if (c == _eof) {
        token.type = _TokenType.eof;
        return token;
      }
    }

    if (lastChar == _eof || (lastChar != _delimiter && c == _eof)) {
      token.type = _TokenType.eof;
      return token;
    }

    while (token.type == _TokenType.invalid) {
      if (c == _delimiter) {
        token.type = _TokenType.token;
      } else if (eol) {
        token.type = _TokenType.endOfRecord;
      } else if (c == _quote) {
        _parseEncapsulated(token);
      } else if (c == _eof) {
        token
          ..type = _TokenType.eof
          ..isReady = true;
      } else {
        _parseSimple(token, c);
      }
    }
    return token;
  }

  void _parseSimple(_Token token, int first) {
    final content = StringBuffer();
    var c = first;
    while (true) {
      if (_readEndOfLine(c)) {
        token.type = _TokenType.endOfRecord;
        break;
      } else if (c == _eof) {
        token
          ..type = _TokenType.eof
          ..isReady = true;
        break;
      } else if (c == _delimiter) {
        token.type = _TokenType.token;
        break;
      }
      content.writeCharCode(c);
      c = _read();
    }
    token.content = content.toString();
  }

  void _parseEncapsulated(_Token token) {
    final startLine = _line;
    final content = StringBuffer();
    while (true) {
      var c = _read();
      if (c == _quote) {
        if (_lookAhead() == _quote) {
          c = _read();
          content.writeCharCode(c);
        } else {
          while (true) {
            c = _read();
            if (c == _delimiter) {
              token.type = _TokenType.token;
            } else if (c == _eof) {
              token
                ..type = _TokenType.eof
                ..isReady = true;
            } else if (_readEndOfLine(c)) {
              token.type = _TokenType.endOfRecord;
            } else if (_isJavaWhitespace(c)) {
              continue;
            } else {
              throw InstanceFormatException(
                '(line $_line) invalid char between encapsulated token and '
                'delimiter',
              );
            }
            token.content = content.toString();
            return;
          }
        }
      } else if (c == _eof) {
        throw InstanceFormatException(
          '(startline $startLine) EOF reached before encapsulated token '
          'finished',
        );
      } else {
        content.writeCharCode(c);
      }
    }
  }

  /// Java `Character.isWhitespace` for the characters that can appear here.
  static bool _isJavaWhitespace(int c) =>
      (c >= 0x09 && c <= 0x0D) ||
      (c >= 0x1C && c <= 0x20) ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x2006) ||
      (c >= 0x2008 && c <= 0x200A) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x205F ||
      c == 0x3000;
}

enum _TokenType { invalid, token, endOfRecord, eof }

final class _Token {
  _TokenType type = _TokenType.invalid;
  String content = '';
  bool isReady = false;
}
