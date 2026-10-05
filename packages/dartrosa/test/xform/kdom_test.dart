// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// kXML DOM and serializer behaviour that JavaRosa labels depend on. Each
// expectation was taken from JavaRosa v6.0.0 (kXML 2.3) with jshell.
import 'package:dartrosa/src/xform/kdom.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const _h = 'xmlns:n0="http://www.w3.org/1999/xhtml"';

/// The parsed inner text of `<label>[inner]</label>`.
Future<String?> label(String inner) async {
  final form = await XFormParser().parse(
    html(
      head([
        title('T'),
        model([
          mainInstance([
            t('data id="kdom"', [t('q')]),
          ]),
        ]),
      ]),
      body([
        t('input ref="/data/q"', [
          StringLiteralXFormsElement('label', const {}, inner),
        ]),
      ]),
    ).asXml(),
  );
  return form.childAt(0)!.labelInnerText;
}

void main() {
  group('DOM', () {
    test('text, CDATA and entities form one text node', () async {
      expect(await label('a &amp; <![CDATA[b <c>]]>'), 'a & b <c>');
    });

    test('a comment reads as "null" inside a label', () async {
      expect(await label('p<!-- note -->q'), 'pnullq');
    });

    test('a comment ends a text run (only the first is the title)', () async {
      final form = await XFormParser().parse(
        html(
          head([
            const StringLiteralXFormsElement(
              'h:title',
              {},
              'T &amp; U <!-- c --> V',
            ),
            model([
              mainInstance([
                t('data id="kdom"', [t('q')]),
              ]),
            ]),
          ]),
          body([input('/data/q')]),
        ).asXml(),
      );
      expect(form.title, 'T & U');
    });

    test('CRLF is normalized to LF', () {
      final root = parseKDocument('<r>a\r\nb</r>');
      expect(root.textAt(0), 'a\nb');
    });

    test('<a></a> has one empty child, <a/> none', () {
      final root = parseKDocument('<r><a></a><b/><c><!--x--></c></r>');
      final [a, b, c] = root.childElements.toList();
      expect(a.childCount, 1);
      expect(a.textAt(0), '');
      expect(b.childCount, 0);
      expect(c.childCount, 1);
      expect(c.textAt(0), isNull);
    });

    test('an empty label is the empty string', () async {
      expect(await label(''), '');
    });

    test('<output> becomes a \${n} placeholder', () async {
      expect(
        await label('out: <output value="/data/q"/> end'),
        'out: \${0} end',
      );
    });
  });

  group('serializer (HTML in labels)', () {
    test(
      'non-ASCII characters are numeric references per UTF-16 unit',
      () async {
        expect(
          await label('<h:b>é ü 中 😀</h:b>'),
          '<n0:b $_h>&#233; &#252; &#20013; &#55357;&#56832;</n0:b>',
        );
      },
    );

    test('@ and > are escaped, quotes and tabs are not in text', () async {
      expect(
        await label('<h:b>a@b ~ &gt; \' " \t tab</h:b>'),
        '<n0:b $_h>a&#64;b ~ &gt; \' " \t tab</n0:b>',
      );
    });

    test('newlines and tabs are escaped in attributes', () async {
      expect(
        await label('<h:span title="a&#10;b&#9;c" lang="x">t</h:span>'),
        '<n0:span title="a&#10;b&#9;c" lang="x" $_h>t</n0:span>',
      );
    });

    test('attributes containing " use single quotes', () async {
      expect(
        await label('<h:span title=\'it&apos;s "q"\'>t</h:span>'),
        '<n0:span title=\'it&apos;s "q"\' $_h>t</n0:span>',
      );
    });

    test('characters from 127 up are escaped', () async {
      expect(
        await label('<h:b>\u007f\u0080 </h:b>'),
        '<n0:b $_h>&#127;&#128;&#160;</n0:b>',
      );
    });

    test('plain label text is not escaped', () async {
      expect(await label('é 中 &amp; &lt;'), 'é 中 & <');
    });

    test('namespaced attributes use the generated prefix', () async {
      expect(
        await label('<h:span h:class="c">t</h:span>'),
        '<n0:span n0:class="c" $_h>t</n0:span>',
      );
    });

    test('non-HTML elements are dropped from labels', () async {
      expect(await label('a<b>bold</b>c'), 'ac');
    });
  });

  group('getXmlDocument', () {
    test('consolidates text and keeps the empty child of <a></a>', () {
      final root = getXmlDocument(
        '<r>\n  <a>x<!--c-->y</a>\n  <b></b><c/></r>',
      );
      expect(root.childCount, 3);
      expect(xmlText(root.elementAt(0)!, trim: true), 'x');
      expect(xmlText(root.elementAt(1)!, trim: true), '');
      expect(xmlText(root.elementAt(2)!, trim: true), isNull);
    });
  });
}
