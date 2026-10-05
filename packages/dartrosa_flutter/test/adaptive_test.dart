// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// XFormView across window size classes: layout, the form outline,
// keyboard navigation, focus on errors and right-to-left forms.

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _long = 'A rather long question label that has to wrap on phones';

/// Two plain questions, a field-list group (with a table-list group and
/// a short select), then a required question.
Future<FormSession> _form({String? language, String itext = ''}) => formSession(
  '<a/><b/><p><c/><d/><t><x/><y/></t></p><r/>',
  '<bind nodeset="/data/c" type="string"/>'
      '<bind nodeset="/data/p/d" type="string"/>'
      '<bind nodeset="/data/r" type="string" required="true()"/>',
  '<input ref="/data/a"><label ref="jr:itext(\'a\')"/></input>'
      '<input ref="/data/b"><label>$_long</label></input>'
      '<group ref="/data/p" appearance="field-list"><label>Visit</label>'
      '<input ref="/data/p/c"><label>C</label></input>'
      '<select1 ref="/data/p/d"><label>Short choices</label>'
      '${items(['Red', 'Green', 'Blue', 'Yellow', 'Black', 'White'])}'
      '</select1>'
      '<group ref="/data/p/t" appearance="table-list"><label>Grid</label>'
      '<select1 ref="/data/p/t/x"><label>X</label>'
      '${items(['Always', 'Sometimes', 'Never'])}</select1>'
      '<select1 ref="/data/p/t/y"><label>Y</label>'
      '${items(['Always', 'Sometimes', 'Never'])}</select1>'
      '</group></group>'
      '<input ref="/data/r"><label>Last</label></input>',
  itext: itext.isEmpty
      ? '<itext><translation lang="en"><text id="a">'
            '<value>First</value></text></translation></itext>'
      : itext,
  language: language,
);

Future<GlobalKey<XFormViewState>> _pump(
  WidgetTester tester,
  FormSession session, {
  required double width,
  double height = 800,
  double textScale = 1,
  XFormMode mode = XFormMode.pager,
  XFormOutlineMode outline = XFormOutlineMode.adaptive,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey<XFormViewState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: XFormView(
          key: key,
          session: session,
          mode: mode,
          outline: outline,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

/// The outline's title (side panel or sheet).
final _outline = find.text('Form outline');

/// The text field of the question labelled [label].
Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is QuestionWidget && w.node.label.text == label,
  ),
  matching: find.byType(EditableText),
);

/// The outline line of [label] (required ones end with a marker).
Finder _tile(String label) => find
    .ancestor(of: find.textContaining(label), matching: find.byType(ListTile))
    .first;

/// Whether the text field of [label] has keyboard focus.
bool _focused(WidgetTester tester, String label) =>
    tester.widget<EditableText>(_field(label)).focusNode.hasFocus;

/// Expects the question [label] (its label, hint, field and error)
/// inside the viewport of the scroll view around it.
void _expectWholeQuestionVisible(WidgetTester tester, String label) {
  final question = find.byWidgetPredicate(
    (w) => w is QuestionWidget && w.node.label.text == label,
  );
  final viewport = tester.getRect(
    find.ancestor(of: question, matching: find.byType(Scrollable)).first,
  );
  final labelRect = tester.getRect(
    find
        .descendant(
          of: question,
          matching: find.textContaining(label, findRichText: true),
        )
        .first,
  );
  final whole = tester.getRect(question);
  expect(labelRect.top, greaterThanOrEqualTo(viewport.top), reason: 'label');
  expect(whole.top, greaterThanOrEqualTo(viewport.top), reason: 'top');
  expect(whole.bottom, lessThanOrEqualTo(viewport.bottom), reason: 'bottom');
}

/// Taps Next (an icon button when the label doesn't fit).
Future<void> _next(WidgetTester tester) async {
  final label = find.text('Next');
  await tester.tap(label.evaluate().isEmpty ? find.byTooltip('Next') : label);
  await tester.pumpAndSettle();
}

/// The pager's position: its text, or the tooltip of the icon shown
/// instead when the text doesn't fit (narrow screens, large text; the
/// test font is wide).
String? _position(WidgetTester tester) {
  final pattern = RegExp(r'^(Form outline, )?(\d+ of \d+)$');
  for (final element
      in find.byWidgetPredicate((w) => w is Text || w is Tooltip).evaluate()) {
    final text = switch (element.widget) {
      Text(:final data) => data,
      Tooltip(:final message) => message,
      _ => null,
    };
    final match = pattern.firstMatch(text ?? '');
    if (match != null) return match[2];
  }
  return null;
}

/// Opens the outline from the pager's position button.
Future<void> _openFromPosition(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.toc).first);
  await tester.pumpAndSettle();
}

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool alt = false,
}) async {
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

void main() {
  test('window size classes follow Material 3', () {
    expect(XFormWindowSize.fromWidth(0), XFormWindowSize.compact);
    expect(XFormWindowSize.fromWidth(599), XFormWindowSize.compact);
    expect(XFormWindowSize.fromWidth(600), XFormWindowSize.medium);
    expect(XFormWindowSize.fromWidth(839), XFormWindowSize.medium);
    expect(XFormWindowSize.fromWidth(840), XFormWindowSize.expanded);
    expect(XFormWindowSize.fromWidth(1200), XFormWindowSize.large);
    expect(XFormWindowSize.fromWidth(1600), XFormWindowSize.extraLarge);
    expect(XFormWindowSize.large >= XFormWindowSize.expanded, isTrue);
    expect(XFormWindowSize.medium < XFormWindowSize.expanded, isTrue);
  });

  group('size classes', () {
    for (final width in [320.0, 360.0, 800.0, 1280.0, 1920.0]) {
      for (final scale in [1.0, 2.0]) {
        final name = '${width.round()}dp, text x$scale';
        final panel = width >= 840;

        testWidgets('pager: $name', (tester) async {
          final s = await _form();
          await _pump(tester, s, width: width, textScale: scale);
          expect(tester.takeException(), isNull);
          // The outline is a side panel on expanded windows only.
          expect(_outline, panel ? findsOneWidget : findsNothing);
          // Position in the bottom bar.
          expect(_position(tester), '1 of 4');

          // The field-list screen: groups, short choices, a table.
          await _next(tester);
          await _next(tester);
          expect(_position(tester), '3 of 4');
          expect(tester.takeException(), isNull);
          final red = tester.getRect(find.text('Red'));
          final green = tester.getRect(find.text('Green'));
          final content = tester.getRect(_field('C'));
          if (width >= 800 && scale == 1) {
            // Short choices in columns, in a centered readable column.
            expect(green.top, red.top);
            expect(content.width, lessThanOrEqualTo(720));
          } else if (width < 600) {
            expect(green.top, greaterThan(red.top));
          }
        });

        testWidgets('scroll: $name', (tester) async {
          final s = await _form();
          await _pump(
            tester,
            s,
            width: width,
            height: 2400,
            textScale: scale,
            mode: XFormMode.scroll,
          );
          expect(tester.takeException(), isNull);
          expect(_outline, panel ? findsOneWidget : findsNothing);
          expect(find.text('Finish'), findsOneWidget);
        });
      }
    }
  });

  group('outline', () {
    testWidgets('side panel lists groups and questions with their state', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 1280);
      expect(find.text('0 of 7 answered'), findsOneWidget);
      expect(find.text('1 required question unanswered'), findsOneWidget);
      // Groups and the questions in them.
      expect(find.widgetWithText(ListTile, 'Visit'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Grid'), findsOneWidget);
      // The first screen is current.
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'First'))
            .selected,
        isTrue,
      );
      await tester.enterText(_field('First'), 'x');
      await tester.pumpAndSettle();
      expect(find.text('1 of 7 answered'), findsOneWidget);
    });

    testWidgets('tapping a question jumps to its screen and focuses it', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 1280);
      await tester.tap(find.widgetWithText(ListTile, 'C'));
      await tester.pumpAndSettle();
      // C is on the field-list screen, shown whole.
      expect(_field('C'), findsOneWidget);
      expect(_position(tester), '3 of 4');
      expect(_focused(tester, 'C'), isTrue);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Visit'))
            .selected,
        isTrue,
      );
      await tester.tap(_tile('Last'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'Last'), isTrue);
    });

    testWidgets('the side panel can be hidden and shown again', (tester) async {
      final s = await _form();
      final view = await _pump(tester, s, width: 1280);
      expect(view.currentState!.isOutlinePanelVisible, isTrue);
      await tester.tap(find.byTooltip('Hide outline'));
      await tester.pumpAndSettle();
      expect(_outline, findsNothing);
      expect(view.currentState!.isOutlinePanelVisible, isFalse);
      // The position button and the collapsed rail bring it back.
      await tester.tap(find.text('1 of 4'));
      await tester.pumpAndSettle();
      expect(_outline, findsOneWidget);
      view.currentState!.hideOutline();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Form outline').first);
      await tester.pumpAndSettle();
      expect(_outline, findsOneWidget);
    });

    testWidgets('on phones it opens as a sheet from the position button', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 360);
      expect(_outline, findsNothing);
      await _openFromPosition(tester);
      expect(_outline, findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Last'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(_tile('Last'));
      await tester.pumpAndSettle();
      await tester.tap(_tile('Last'));
      await tester.pumpAndSettle();
      // The sheet closed on the chosen question.
      expect(_outline, findsNothing);
      expect(_position(tester), '4 of 4');
      expect(_focused(tester, 'Last'), isTrue);
    });

    testWidgets('apps open it with XFormViewState.showOutline', (tester) async {
      final s = await _form();
      final view = await _pump(tester, s, width: 360, mode: XFormMode.scroll);
      view.currentState!.showOutline();
      await tester.pumpAndSettle();
      expect(_outline, findsOneWidget);
      // Esc closes it.
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_outline, findsNothing);
    });

    testWidgets('onRequest: no side panel, the sheet still opens', (
      tester,
    ) async {
      final s = await _form();
      final view = await _pump(
        tester,
        s,
        width: 1280,
        outline: XFormOutlineMode.onRequest,
      );
      expect(_outline, findsNothing);
      view.currentState!.showOutline();
      await tester.pumpAndSettle();
      expect(_outline, findsOneWidget);
    });

    testWidgets('none: no outline at all', (tester) async {
      final s = await _form();
      final view = await _pump(
        tester,
        s,
        width: 1280,
        outline: XFormOutlineMode.none,
      );
      expect(_outline, findsNothing);
      // The position is shown, not as a button.
      expect(_position(tester), '1 of 4');
      expect(find.widgetWithText(TextButton, '1 of 4'), findsNothing);
      view.currentState!.showOutline();
      await tester.pumpAndSettle();
      expect(_outline, findsNothing);
    });

    testWidgets('scroll mode: jumping scrolls far down and focuses', (
      tester,
    ) async {
      // Sixty questions: the last one isn't built until scrolled to.
      final s = await formSession(
        [for (var i = 0; i < 60; i++) '<q$i/>'].join(),
        '',
        [
          for (var i = 0; i < 60; i++)
            '<input ref="/data/q$i"><label>Q$i</label></input>',
        ].join(),
      );
      final view = await _pump(
        tester,
        s,
        width: 1280,
        height: 600,
        mode: XFormMode.scroll,
      );
      expect(_field('Q59'), findsNothing);
      view.currentState!.jumpTo(s.root.children[59].index);
      await tester.pumpAndSettle();
      expect(_field('Q59'), findsOneWidget);
      expect(_focused(tester, 'Q59'), isTrue);
      // And back up.
      await tester.tap(find.widgetWithText(ListTile, 'Q2'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'Q2'), isTrue);
    });
  });

  group('pager', () {
    testWidgets('Back is disabled on the first screen', (tester) async {
      final s = await _form();
      await _pump(tester, s, width: 360);
      OutlinedButton back() =>
          tester.widget(find.widgetWithText(OutlinedButton, 'Back'));
      expect(back().onPressed, isNull);
      await _next(tester);
      expect(back().onPressed, isNotNull);
    });

    testWidgets('narrow screen with large text: icon buttons', (tester) async {
      final s = await _form();
      await _pump(tester, s, width: 320, textScale: 3);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Next'), findsOneWidget);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text(_long), findsWidgets);
    });

    testWidgets('the end page sums up the answers', (tester) async {
      final s = await _form();
      s.navigator.jumpToEnd();
      await _pump(tester, s, width: 360);
      expect(find.text('Finalize'), findsOneWidget);
      expect(find.text('0 of 7 answered'), findsOneWidget);
      expect(find.text('1 required question unanswered'), findsOneWidget);
      expect(_position(tester), '4 of 4');
    });
  });

  group('keyboard', () {
    testWidgets('Page Down / Page Up and Alt+arrows move between screens', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 1280, platform: TargetPlatform.macOS);
      expect(_position(tester), '1 of 4');
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_position(tester), '2 of 4');
      await _key(tester, LogicalKeyboardKey.arrowRight, alt: true);
      expect(_position(tester), '3 of 4');
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_position(tester), '2 of 4');
      await _key(tester, LogicalKeyboardKey.arrowLeft, alt: true);
      expect(_position(tester), '1 of 4');
    });

    testWidgets('in a text field Alt+arrows edit text, Page Down moves', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 1280);
      await tester.showKeyboard(_field('First'));
      await _key(tester, LogicalKeyboardKey.arrowRight, alt: true);
      expect(_position(tester), '1 of 4');
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_position(tester), '2 of 4');
    });

    testWidgets('Enter: next screen for a question alone on it', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 360);
      await tester.enterText(_field('First'), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_position(tester), '2 of 4');
    });

    testWidgets('Enter: next field on a field-list screen', (tester) async {
      final s = await formSession(
        '<p><a/><b/></p>',
        '',
        '<group ref="/data/p" appearance="field-list">'
            '<input ref="/data/p/a"><label>A</label></input>'
            '<input ref="/data/p/b"><label>B</label></input></group>',
      );
      await _pump(tester, s, width: 360);
      await tester.enterText(_field('A'), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_focused(tester, 'B'), isTrue);
    });

    testWidgets('Tab moves through the questions in form order', (
      tester,
    ) async {
      final s = await formSession(
        '<p><a/><b/></p>',
        '',
        '<group ref="/data/p" appearance="field-list">'
            '<input ref="/data/p/a"><label>A</label></input>'
            '<input ref="/data/p/b"><label>B</label></input></group>',
      );
      await _pump(tester, s, width: 360);
      await tester.showKeyboard(_field('A'));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(tester, 'B'), isTrue);
    });
  });

  group('errors', () {
    testWidgets('blocked Next focuses the first question in error', (
      tester,
    ) async {
      final s = await formSession(
        '<p><a/><b/></p>',
        '<bind nodeset="/data/p/a" type="string" required="true()"/>'
            '<bind nodeset="/data/p/b" type="string" required="true()"/>',
        '<group ref="/data/p" appearance="field-list">'
            '<input ref="/data/p/a"><label>A</label></input>'
            '<input ref="/data/p/b"><label>B</label></input></group>',
      );
      await _pump(tester, s, width: 360);
      await _next(tester);
      expect(find.text('Sorry, this response is required!'), findsNWidgets(2));
      expect(_focused(tester, 'A'), isTrue);
      // The field shows the error state too.
      final decoration = tester
          .widget<TextField>(
            find.ancestor(of: _field('A'), matching: find.byType(TextField)),
          )
          .decoration!;
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
        ThemeData().colorScheme.error,
      );
    });

    testWidgets('failed finalize in scroll mode reveals the question', (
      tester,
    ) async {
      final s = await formSession(
        '${[for (var i = 0; i < 40; i++) '<q$i/>'].join()}<last/>',
        '<bind nodeset="/data/last" type="string" required="true()"/>',
        '${[for (var i = 0; i < 40; i++) '<input ref="/data/q$i"><label>Q$i</label></input>'].join()}'
            '<input ref="/data/last"><label>Last</label></input>',
      );
      final view = await _pump(
        tester,
        s,
        width: 360,
        height: 640,
        mode: XFormMode.scroll,
      );
      // Finish is at the bottom: jump there, then back to the top.
      view.currentState!.jumpTo(s.root.children.last.index);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Finish'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Some answers need attention.'), findsOneWidget);
      expect(_focused(tester, 'Last'), isTrue);
      expect(find.text('Sorry, this response is required!'), findsOneWidget);
    });

    // The whole question in error is shown: label, hint, field and error,
    // not only the field the keyboard focus moved to.
    for (final (name, width, height, platform) in [
      ('phone', 360.0, 640.0, null),
      ('desktop', 1280.0, 800.0, TargetPlatform.linux),
    ]) {
      testWidgets('blocked Next shows the whole question ($name)', (
        tester,
      ) async {
        final s = await formSession(
          '<p>${[for (var i = 0; i < 30; i++) '<q$i/>'].join()}<last/></p>',
          '<bind nodeset="/data/p/last" type="string" required="true()"/>',
          '<group ref="/data/p" appearance="field-list">'
              '${[for (var i = 0; i < 30; i++) '<input ref="/data/p/q$i"><label>Q$i</label></input>'].join()}'
              '<input ref="/data/p/last"><label>Last</label>'
              '<hint>The last one</hint></input></group>',
        );
        await _pump(
          tester,
          s,
          width: width,
          height: height,
          platform: platform,
        );
        await _next(tester);
        expect(_focused(tester, 'Last'), isTrue);
        _expectWholeQuestionVisible(tester, 'Last');
      });

      // Far above Finish (not built yet), or just above the screen.
      for (final after in [30, 8]) {
        testWidgets('failed finalize shows the whole question ($name, $after)', (
          tester,
        ) async {
          final s = await formSession(
            '${[for (var i = 0; i < 30; i++) '<q$i/>'].join()}<mid/>'
                '${[for (var i = 0; i < after; i++) '<r$i/>'].join()}',
            '<bind nodeset="/data/mid" type="string" required="true()"/>',
            '${[for (var i = 0; i < 30; i++) '<input ref="/data/q$i"><label>Q$i</label></input>'].join()}'
                '<input ref="/data/mid"><label>Middle</label>'
                '<hint>In the middle</hint></input>'
                '${[for (var i = 0; i < after; i++) '<input ref="/data/r$i"><label>R$i</label></input>'].join()}',
          );
          await _pump(
            tester,
            s,
            width: width,
            height: height,
            mode: XFormMode.scroll,
            platform: platform,
          );
          // Finish is at the bottom.
          await tester.scrollUntilVisible(
            find.text('Finish'),
            300,
            scrollable: find
                .ancestor(
                  of: find.byType(QuestionWidget).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(find.text('Finish'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Finish'));
          await tester.pumpAndSettle();
          expect(_focused(tester, 'Middle'), isTrue);
          _expectWholeQuestionVisible(tester, 'Middle');
        });
      }
    }

    testWidgets('failed finalize in pager mode shows the field-list screen', (
      tester,
    ) async {
      final s = await formSession(
        '<a/><p><b/><c/></p>',
        '<bind nodeset="/data/p/c" type="string" required="true()"/>',
        '<input ref="/data/a"><label>A</label></input>'
            '<group ref="/data/p" appearance="field-list">'
            '<input ref="/data/p/b"><label>B</label></input>'
            '<input ref="/data/p/c"><label>C</label></input></group>',
      );
      s.navigator.jumpToEnd();
      await _pump(tester, s, width: 360);
      await tester.tap(find.text('Finalize'));
      await tester.pumpAndSettle();
      // The whole screen of C, with C focused.
      expect(_field('B'), findsOneWidget);
      expect(_focused(tester, 'C'), isTrue);
      expect(_position(tester), '2 of 2');
    });
  });

  group('right to left', () {
    const itext =
        '<itext><translation lang="Arabic (ar)"><text id="a">'
        '<value>الأول</value></text></translation></itext>';

    testWidgets('the outline panel is on the right; arrows flip', (
      tester,
    ) async {
      final s = await _form(language: 'Arabic (ar)', itext: itext);
      await _pump(tester, s, width: 1280, platform: TargetPlatform.windows);
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(ListView).first);
      expect(panel.left, greaterThan(640));
      expect(
        Directionality.of(tester.element(find.text('الأول').last)),
        TextDirection.rtl,
      );
      // Alt+Left is forward in a right-to-left form.
      await _key(tester, LogicalKeyboardKey.arrowLeft, alt: true);
      expect(_position(tester), '2 of 4');
    });

    testWidgets('lays out on a phone with large text', (tester) async {
      final s = await _form(language: 'Arabic (ar)', itext: itext);
      await _pump(tester, s, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
      await _next(tester);
      await _next(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('desktop', () {
    testWidgets('scroll bars stay visible and text can be selected', (
      tester,
    ) async {
      final s = await _form();
      await _pump(
        tester,
        s,
        width: 1280,
        height: 400,
        mode: XFormMode.scroll,
        platform: TargetPlatform.linux,
      );
      expect(
        tester
            .widgetList<Scrollbar>(find.byType(Scrollbar))
            .any((s) => s.thumbVisibility ?? false),
        isTrue,
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      // Choices still answer with a click.
      await tester.scrollUntilVisible(
        find.text('Green'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Green'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green'));
      await tester.pumpAndSettle();
      expect(s.root.children[2], isA<GroupNode>());
      final d = (s.root.children[2] as GroupNode).children[1] as QuestionNode;
      expect(d.value?.displayText, 'green');
    });

    testWidgets('phones: no selection area, no forced scroll bar', (
      tester,
    ) async {
      final s = await _form();
      await _pump(tester, s, width: 360, mode: XFormMode.scroll);
      expect(find.byType(SelectionArea), findsNothing);
    });
  });
}
