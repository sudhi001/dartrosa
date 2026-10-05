// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/src/xpath/parser.dart';
import 'package:test/test.dart';

/// Expected results captured from JavaRosa 6.0.0 (jshell).
void main() {
  group('syntax error messages match JavaRosa', () {
    const messages = {
      "'unterminated string...":
          "Couldn't understand the expression starting at this point: "
          "͎'unterminated s...",
      'inv#lid_N~AME':
          "Couldn't understand the expression starting at this point: "
          'inv͎#lid_N~AME',
      r'$':
          "Couldn't understand the expression starting at this point: "
          '͎\$',
      '/data/a # 1 and some long tail here':
          "Couldn't understand the expression starting at this point: "
          '/data/a͎#1 and some lo...',
      '/data/名前':
          "Couldn't understand the expression starting at this point: "
          '/data/͎名前',
      "concat('a', 'b'": 'Mismatched brackets or parentheses',
    };
    messages.forEach((expr, message) {
      test(expr, () {
        expect(
          () => parseXPath(expr),
          throwsA(
            isA<XPathSyntaxException>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      });
    });

    test('dangling operator is a bad node', () {
      expect(
        () => parseXPath('a+'),
        throwsA(
          isA<XPathSyntaxException>().having(
            (e) => e.message,
            'message',
            startsWith('Bad node: '),
          ),
        ),
      );
    });
  });

  group('names use Java letter rules', () {
    test('cased non-ASCII letters and Unicode digits are accepted', () {
      expect(
        parseXPath('/data/ñame').toString(),
        '{path-expr:abs,{{step:child,data},{step:child,ñame}}}',
      );
      expect(
        parseXPath('/data/Δx').toString(),
        '{path-expr:abs,{{step:child,data},{step:child,Δx}}}',
      );
      expect(
        parseXPath('/data/x٣').toString(),
        '{path-expr:abs,{{step:child,data},{step:child,x٣}}}',
      );
    });

    test('a number made of non-ASCII digits is rejected', () {
      // JavaRosa crashes with NumberFormatException; see DEVIATIONS.md.
      expect(() => parseXPath('٣'), throwsA(isA<XPathSyntaxException>()));
    });
  });
}
