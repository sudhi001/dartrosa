import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Two 100×100 areas side by side, in a 200×100 user space drawn at 2x.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">'
    '<rect id="a" x="0" y="0" width="100" height="100" fill="#ccc"/>'
    '<g id="b" transform="translate(100 0)">'
    '<path d="M0 0 H100 V100 H0 Z" fill="#ddd"/></g>'
    '<circle id="other" cx="10" cy="10" r="5"/>'
    '</svg>';

class _SvgDelegates extends XFormDelegates {
  const _SvgDelegates();

  @override
  Future<Uint8List?> mediaBytes(String uri) async =>
      uri == 'jr://images/map.svg' ? utf8.encode(_svg) : null;
}

Future<FormSession> _form(String control, {String image = 'map.svg'}) =>
    formSession(
      '<q/>',
      '',
      '<$control ref="/data/q" appearance="image-map">'
          '<label ref="jr:itext(\'q\')"/>${items(['A', 'B'])}</$control>',
      itext:
          '<itext><translation lang="en"><text id="q">'
          '<value>Q</value><value form="image">jr://images/$image</value>'
          '</text></translation></itext>',
    );

Future<void> _pump(WidgetTester tester, FormSession s) async {
  await tester.pumpWidget(
    app(
      SizedBox(
        width: 400,
        child: XFormView(
          session: s,
          mode: XFormMode.scroll,
          delegates: const _SvgDelegates(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAt(WidgetTester tester, double fx, double fy) async {
  final box = find.byKey(const ValueKey('image-map'));
  final rect = tester.getRect(box);
  await tester.tapAt(
    Offset(rect.left + rect.width * fx, rect.top + rect.height * fy),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SvgImageMap', () {
    test('areas, transforms, hit testing', () {
      final map = SvgImageMap.parse(_svg, ['a', 'b']);
      expect(map.viewBox, const Rect.fromLTWH(0, 0, 200, 100));
      expect(map.areaIds, ['a', 'b']);
      expect(map.areaAt(const Offset(50, 50)), 'a');
      expect(map.areaAt(const Offset(150, 50)), 'b');
      expect(map.areaAt(const Offset(250, 50)), isNull);
    });

    test('highlights selected areas', () {
      final map = SvgImageMap.parse(_svg, ['a', 'b']);
      final svg = map.highlighted({'b'});
      expect(
        svg,
        contains(
          '<path d="M0 0 H100 V100 H0 Z" fill="#ddd" '
          'style="fill: $imageMapSelectedColor"/>',
        ),
      );
      expect(
        svg,
        isNot(
          contains(
            '<rect id="a" x="0" y="0" width="100" '
            'height="100" fill="#ccc" style',
          ),
        ),
      );
    });

    test('default size, other shapes', () {
      final map = SvgImageMap.parse(
        '<svg><ellipse id="e" cx="500" cy="500" rx="100" ry="50"/>'
        '<polygon id="p" points="0,0 10,0 10,10"/></svg>',
        ['e', 'p'],
      );
      expect(map.viewBox, const Rect.fromLTWH(0, 0, 1000, 1000));
      expect(map.areaAt(const Offset(590, 500)), 'e');
      expect(map.areaAt(const Offset(500, 560)), isNull);
      expect(map.areaAt(const Offset(9, 1)), 'p');
    });

    test('rejects non-SVG documents', () {
      expect(
        () => SvgImageMap.parse('<html/>', const []),
        throwsFormatException,
      );
    });
  });

  testWidgets('select one: tap areas to select', (tester) async {
    final s = await _form('select1');
    await _pump(tester, s);
    await _tapAt(tester, 0.25, 0.5);
    expect(question(s, 0).value, isA<SelectOneValue>());
    expect(question(s, 0).value!.displayText, 'a');
    expect(find.text('Selected: A', findRichText: true), findsOneWidget);
    await _tapAt(tester, 0.75, 0.5);
    expect(question(s, 0).value!.displayText, 'b');
  });

  testWidgets('select multiple: taps toggle', (tester) async {
    final s = await _form('select');
    await _pump(tester, s);
    await _tapAt(tester, 0.25, 0.5);
    await _tapAt(tester, 0.75, 0.5);
    expect(question(s, 0).value!.displayText, 'a, b');
    expect(find.text('Selected: A, B', findRichText: true), findsOneWidget);
    await _tapAt(tester, 0.25, 0.5);
    expect(question(s, 0).value!.displayText, 'b');
  });

  testWidgets('screen readers see and select areas', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await _form('select1');
    await _pump(tester, s);
    final area = find.semantics.byLabel('B');
    expect(area, findsOne);
    final map = tester.getRect(find.byKey(const ValueKey('image-map')));
    final node = area.evaluate().single;
    // The right half of the map (b is 100..200 of a 200-wide space).
    expect(node.rect.width, closeTo(map.width / 2, 0.01));
    expect(node, containsSemantics(isSelected: false, hasTapAction: true));
    tester.semantics.tap(area);
    await tester.pumpAndSettle();
    expect(question(s, 0).value!.displayText, 'b');
    expect(
      find.semantics.byLabel('B').evaluate().single,
      containsSemantics(isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('missing SVG shows a message', (tester) async {
    final s = await _form('select1', image: 'missing.svg');
    await _pump(tester, s);
    expect(find.text('SVG file does not exist!'), findsOneWidget);
  });
}
