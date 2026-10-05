// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (Token, Lexer), Copyright (C) 2009 JavaRosa; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../util/java_lang.dart';
import 'exceptions.dart';
import 'qname.dart';

/// Token kinds produced by [lex]. Port of `org.javarosa.xpath.parser.Token`.
enum TokenType {
  /// `and`
  and,

  /// `@`
  at,

  /// `,`
  comma,

  /// `::`
  dblColon,

  /// `..`
  dblDot,

  /// `//`
  dblSlash,

  /// `div`
  div,

  /// `.`
  dot,

  /// `=`
  eq,

  /// `>`
  gt,

  /// `>=`
  gte,

  /// `[`
  lbrack,

  /// `(`
  lparen,

  /// `<`
  lt,

  /// `<=`
  lte,

  /// Binary `-`.
  minus,

  /// `mod`
  mod,

  /// `*` as multiplication.
  mult,

  /// `!=`
  neq,

  /// `prefix:*`
  nsWildcard,

  /// A number literal.
  num,

  /// `or`
  or,

  /// `+`
  plus,

  /// A (qualified) name.
  qname,

  /// `]`
  rbrack,

  /// `)`
  rparen,

  /// `/`
  slash,

  /// A string literal.
  str,

  /// Unary `-`.
  uminus,

  /// `|`
  union,

  /// `$name`
  variable,

  /// `*` as a name test.
  wildcard,
}

/// A lexical token with its optional value: a [double] for
/// [TokenType.num], a [String] for [TokenType.str] and
/// [TokenType.nsWildcard], an [XPathQName] for [TokenType.qname] and
/// [TokenType.variable].
final class Token {
  /// Creates a token of [type] with an optional [value].
  const Token(this.type, [this.value]);

  /// The kind of token.
  final TokenType type;

  /// The token's value, if any.
  final Object? value;

  @override
  String toString() => value == null ? type.name : '${type.name}($value)';
}

/// Tokens after which the lexer expects an operator rather than a value.
const _valueEndingTokens = {
  TokenType.wildcard, TokenType.nsWildcard, TokenType.qname, //
  TokenType.variable, TokenType.num, TokenType.str, TokenType.rbrack,
  TokenType.rparen, TokenType.dot, TokenType.dblDot,
};

const _contextLength = 15;

/// Splits an XPath expression into tokens.
///
/// Port of `org.javarosa.xpath.parser.Lexer.lex`, including its context
/// rules: `*` and `-` mean multiply/minus only where an operator is
/// expected, and `and`/`or`/`div`/`mod` are operators only there too.
List<Token> lex(String expr) {
  final tokens = <Token>[];
  var i = 0;
  var expectingValue = true;
  while (i < expr.length) {
    final c = expr.codeUnitAt(i);
    final d = _charAt(expr, i + 1);
    Token? token;
    var skip = 1;

    if (c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0C || c == 0x0D) {
      // whitespace
    } else if (c == _eq) {
      token = const Token(TokenType.eq);
    } else if (c == _bang && d == _eq) {
      token = const Token(TokenType.neq);
      skip = 2;
    } else if (c == _lt) {
      token = d == _eq ? const Token(TokenType.lte) : const Token(TokenType.lt);
      if (d == _eq) skip = 2;
    } else if (c == _gt) {
      token = d == _eq ? const Token(TokenType.gte) : const Token(TokenType.gt);
      if (d == _eq) skip = 2;
    } else if (c == _plus) {
      token = const Token(TokenType.plus);
    } else if (c == _minus) {
      token = expectingValue
          ? const Token(TokenType.uminus)
          : const Token(TokenType.minus);
    } else if (c == _star) {
      token = expectingValue
          ? const Token(TokenType.wildcard)
          : const Token(TokenType.mult);
    } else if (c == _pipe) {
      token = const Token(TokenType.union);
    } else if (c == _slash) {
      token = d == _slash
          ? const Token(TokenType.dblSlash)
          : const Token(TokenType.slash);
      if (d == _slash) skip = 2;
    } else if (c == _lbrack) {
      token = const Token(TokenType.lbrack);
    } else if (c == _rbrack) {
      token = const Token(TokenType.rbrack);
    } else if (c == _lparen) {
      token = const Token(TokenType.lparen);
    } else if (c == _rparen) {
      token = const Token(TokenType.rparen);
    } else if (c == _dot) {
      if (d == _dot) {
        token = const Token(TokenType.dblDot);
        skip = 2;
      } else if (_isDigit(d)) {
        skip = _matchNumeric(expr, i);
        token = Token(TokenType.num, _parseNumber(expr.substring(i, i + skip)));
      } else {
        token = const Token(TokenType.dot);
      }
    } else if (c == _at) {
      token = const Token(TokenType.at);
    } else if (c == _comma) {
      token = const Token(TokenType.comma);
    } else if (c == _colon && d == _colon) {
      token = const Token(TokenType.dblColon);
      skip = 2;
    } else if (!expectingValue && expr.startsWith('and', i)) {
      token = const Token(TokenType.and);
      skip = 3;
    } else if (!expectingValue && expr.startsWith('or', i)) {
      token = const Token(TokenType.or);
      skip = 2;
    } else if (!expectingValue && expr.startsWith('div', i)) {
      token = const Token(TokenType.div);
      skip = 3;
    } else if (!expectingValue && expr.startsWith('mod', i)) {
      token = const Token(TokenType.mod);
      skip = 3;
    } else if (c == _dollar) {
      final length = _matchQName(expr, i + 1);
      if (length == 0) _badParse(expr, i);
      token = Token(
        TokenType.variable,
        XPathQName.parse(expr.substring(i + 1, i + length + 1)),
      );
      skip = length + 1;
    } else if (c == _apostrophe || c == _quote) {
      final end = expr.indexOf(String.fromCharCode(c), i + 1);
      if (end == -1) _badParse(expr, i);
      token = Token(TokenType.str, expr.substring(i + 1, end));
      skip = end - i + 1;
    } else if (_isDigit(c)) {
      skip = _matchNumeric(expr, i);
      token = Token(TokenType.num, _parseNumber(expr.substring(i, i + skip)));
    } else if (expectingValue && (_isAlpha(c) || c == _underscore)) {
      final length = _matchQName(expr, i);
      final name = expr.substring(i, i + length);
      if (!name.contains(':') &&
          _charAt(expr, i + length) == _colon &&
          _charAt(expr, i + length + 1) == _star) {
        token = Token(TokenType.nsWildcard, name);
        skip = length + 2;
      } else {
        token = Token(TokenType.qname, XPathQName.parse(name));
        skip = length;
      }
    } else {
      _badParse(expr, i);
    }

    if (token != null) {
      expectingValue = !_valueEndingTokens.contains(token.type);
      tokens.add(token);
    }
    i += skip;
  }
  return tokens;
}

Never _badParse(String expr, int i) {
  final c = expr[i];
  final preStart = i - _contextLength < 0 ? 0 : i - _contextLength;
  final preContext =
      (preStart != 0 ? '...' : '') + javaTrim(expr.substring(preStart, i));
  final postEnd = i + _contextLength < expr.length
      ? i + _contextLength
      : expr.length;
  final postContext = i == expr.length - 1
      ? ''
      : javaTrim(
              expr.substring(
                i + 1 < expr.length - 1 ? i + 1 : expr.length - 1,
                postEnd,
              ),
            ) +
            (postEnd != expr.length ? '...' : '');
  throw XPathSyntaxException(
    "Couldn't understand the expression starting at this point: "
    '$preContext͎$c$postContext',
  );
}

/// Java's `Double.valueOf` accepts only ASCII digits; a number containing
/// another Unicode digit fails to parse.
double _parseNumber(String text) {
  final value = double.tryParse(text);
  if (value == null || text.codeUnits.any((u) => u > 0x7F)) {
    throw XPathSyntaxException('Invalid number: $text');
  }
  return value;
}

int _matchNumeric(String expr, int start) {
  var seenDecimalPoint = false;
  var i = start;
  for (; i < expr.length; i++) {
    final c = expr.codeUnitAt(i);
    if (!(_isDigit(c) || (!seenDecimalPoint && c == _dot))) break;
    if (c == _dot) seenDecimalPoint = true;
  }
  return i - start;
}

int _matchQName(String expr, int i) {
  var length = _matchNCName(expr, i);
  if (length > 0 && _charAt(expr, i + length) == _colon) {
    final localLength = _matchNCName(expr, i + length + 1);
    if (localLength > 0) length += localLength + 1;
  }
  return length;
}

int _matchNCName(String expr, int start) {
  var i = start;
  for (; i < expr.length; i++) {
    final c = expr.codeUnitAt(i);
    if (!(_isAlpha(c) ||
        c == _underscore ||
        (i > start && (_isDigit(c) || c == _dot || c == _minus)))) {
      break;
    }
  }
  return i - start;
}

int _charAt(String expr, int i) => i < expr.length ? expr.codeUnitAt(i) : -1;

final _unicodeDigit = RegExp(r'^\p{Nd}$', unicode: true);
final _unicodeCased = RegExp(r'^[\p{Lowercase}\p{Uppercase}]$', unicode: true);

/// Java `Character.isDigit(char)`: Unicode decimal digits (category Nd).
bool _isDigit(int c) {
  if (c < 0) return false;
  if (c < 0x80) return c >= 0x30 && c <= 0x39;
  return _unicodeDigit.hasMatch(String.fromCharCode(c));
}

/// Java `Character.isLowerCase(char) || Character.isUpperCase(char)`.
/// Letters without case (CJK, Arabic, …) are not accepted, as in JavaRosa.
bool _isAlpha(int c) {
  if (c < 0) return false;
  if (c < 0x80) return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  return _unicodeCased.hasMatch(String.fromCharCode(c));
}

const _eq = 0x3D, _bang = 0x21, _lt = 0x3C, _gt = 0x3E, _plus = 0x2B; //
const _minus = 0x2D, _star = 0x2A, _pipe = 0x7C, _slash = 0x2F;
const _lbrack = 0x5B, _rbrack = 0x5D, _lparen = 0x28, _rparen = 0x29;
const _dot = 0x2E, _at = 0x40, _comma = 0x2C, _colon = 0x3A, _dollar = 0x24;
const _apostrophe = 0x27, _quote = 0x22, _underscore = 0x5F;
