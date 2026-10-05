// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _styles = OdkMarkdownStyles(
  headers: [TextStyle(fontSize: 30), TextStyle(fontSize: 20)],
  link: TextStyle(decoration: TextDecoration.underline),
);

TextSpan _root(String md, {GestureRecognizer Function(String)? onLink}) =>
    TextSpan(children: parseOdkMarkdown(md, _styles, onLink: onLink));

/// The style applying to the first character of [text] in [root].
TextStyle? styleOf(TextSpan root, String text) {
  TextStyle? found;
  void visit(InlineSpan span, TextStyle inherited) {
    if (found != null || span is! TextSpan) return;
    final style = inherited.merge(span.style);
    if (span.text != null && span.text!.contains(text)) {
      found = style;
      return;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(root, const TextStyle());
  return found;
}

void main() {
  group('parseOdkMarkdown', () {
    test('em, strong, nested, escapes', () {
      final root = _root(r'a *em* **strong** __b *c*__ \*lit\* _u_');
      expect(root.toPlainText(), 'a em strong b c *lit* u');
      expect(styleOf(root, 'em')!.fontStyle, FontStyle.italic);
      expect(styleOf(root, 'strong')!.fontWeight, FontWeight.bold);
      expect(styleOf(root, 'c')!.fontStyle, FontStyle.italic);
      expect(styleOf(root, 'c')!.fontWeight, FontWeight.bold);
      expect(styleOf(root, 'u')!.fontStyle, FontStyle.italic);
      expect(styleOf(root, '*lit*')!.fontStyle, isNull);
    });

    test('unclosed or spaced delimiters stay literal', () {
      expect(_root('2 * 3 * 4').toPlainText(), '2 * 3 * 4');
      expect(_root('*open').toPlainText(), '*open');
    });

    test('headers at line start', () {
      final root = _root('# Big\n## Small\nnot # header');
      expect(root.toPlainText(), 'Big\nSmall\nnot # header');
      expect(styleOf(root, 'Big')!.fontSize, 30);
      expect(styleOf(root, 'Small')!.fontSize, 20);
      expect(styleOf(root, 'not')!.fontSize, isNull);
    });

    test('links get recognizers', () {
      final urls = <String>[];
      final root = _root(
        'see [the *docs*](https://getodk.org) now',
        onLink: (url) {
          urls.add(url);
          return TapGestureRecognizer();
        },
      );
      expect(root.toPlainText(), 'see the docs now');
      expect(urls, ['https://getodk.org']);
      expect(styleOf(root, 'the')!.decoration, TextDecoration.underline);
      expect(styleOf(root, 'docs')!.fontStyle, FontStyle.italic);
    });

    test('span color and font-family, nested spans, entities, br', () {
      final root = _root(
        '<span style="color:#f00; font-family: \'Serif\', x">red '
        '<span style="color: blue">blue</span></span> &lt;3<br/>end',
      );
      expect(root.toPlainText(), 'red blue <3\nend');
      expect(styleOf(root, 'red')!.color, const Color(0xFFFF0000));
      expect(styleOf(root, 'red')!.fontFamily, 'Serif');
      expect(styleOf(root, 'blue')!.color, const Color(0xFF0000FF));
    });

    test('parseCssColor', () {
      expect(parseCssColor('#336699'), const Color(0xFF336699));
      expect(parseCssColor('rgb(1, 2, 3)'), const Color(0xFF010203));
      expect(parseCssColor('Green'), const Color(0xFF008000));
      expect(parseCssColor('nope'), isNull);
    });
  });

  testWidgets('labels, hints and guidance render markdown', (tester) async {
    final opened = <Uri>[];
    final s = await formSession(
      '<q/>',
      '<bind nodeset="/data/q" type="string"/>',
      '<input ref="/data/q"><label>**Name** of [site](https://x.org)</label>'
          '<hint ref="jr:itext(\'h\')"/></input>',
      itext:
          '<itext><translation lang="en"><text id="h"><value>A *hint*</value>'
          '<value form="guidance">Ask _twice_</value></text></translation>'
          '</itext>',
    );
    await tester.pumpWidget(
      app(
        XFormView(
          session: s,
          mode: XFormMode.scroll,
          delegates: _LinkDelegates(opened),
        ),
      ),
    );
    expect(find.text('Name of site'), findsOneWidget);
    expect(find.text('A hint'), findsOneWidget);
    expect(find.text('Ask twice'), findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring('site'));
    expect(opened, [Uri.parse('https://x.org')]);

    await tester.pumpWidget(
      app(
        XFormView(
          session: s,
          mode: XFormMode.scroll,
          guidanceHints: GuidanceHintMode.collapsed,
        ),
      ),
    );
    expect(find.text('Ask twice'), findsNothing);
    await tester.tap(find.text('Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('Ask twice'), findsOneWidget);
  });
}

class _LinkDelegates extends XFormDelegates {
  const _LinkDelegates(this.opened);

  final List<Uri> opened;

  @override
  Future<void> openLink(BuildContext context, Uri uri) async => opened.add(uri);
}
