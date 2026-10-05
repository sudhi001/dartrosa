// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Records the animations in docs/images/gifs/: each test drives a form
// from test/screenshots/forms/ like a person would (taps, typing) and
// captures a frame after each pump, with a circle where the finger is.
// The frames go to build/gif_frames/<name>/ with their durations;
// make_gifs.py turns them into GIFs.
//
// Skipped unless DARTROSA_SCREENSHOTS is set; macOS only. From
// packages/dartrosa_flutter:
//
//   DARTROSA_SCREENSHOTS=1 flutter test test/screenshots/gifs_test.dart
//   python3 test/screenshots/make_gifs.py build/gif_frames ../../docs/images/gifs
@Tags(['screenshots'])
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final Directory _framesRoot = Directory('build/gif_frames');

/// Choice images, drawn in `setUpAll`.
Map<String, Uint8List> _images = const {};

/// Frames of one recording and how long each is shown.
class _Recorder {
  _Recorder(
    this.tester,
    this.boundary,
    this.touchPoint, {
    required this.pixelRatio,
  });

  final WidgetTester tester;

  /// Where the finger is shown.
  final ValueNotifier<Offset?> touchPoint;
  final GlobalKey boundary;
  final double pixelRatio;
  final List<(Uint8List, int)> _frames = [];

  /// Captures the screen, shown for [ms] milliseconds.
  Future<void> frame([int ms = 70]) async {
    _frames.add((
      await capturePng(tester, boundary, pixelRatio: pixelRatio),
      ms,
    ));
  }

  /// Pumps [steps] frames of [ms] each, capturing each (animations).
  Future<void> animate({int steps = 6, int ms = 70}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(Duration(milliseconds: ms));
      await frame(ms);
    }
    await tester.pumpAndSettle();
  }

  /// Shows a touch on [finder], taps it and records what follows.
  Future<void> tap(Finder finder, {int steps = 6}) async {
    touchPoint.value = tester.getCenter(finder.first);
    await tester.pump();
    await frame(220);
    await tester.tap(finder.first);
    await tester.pump();
    await frame(90);
    touchPoint.value = null;
    await animate(steps: steps);
    await frame(500);
  }

  /// Types [text] into [field] a letter at a time.
  Future<void> type(Finder field, String text, {String initial = ''}) async {
    touchPoint.value = tester.getCenter(field.first);
    await tester.pump();
    await frame(220);
    touchPoint.value = null;
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(field.first, initial + text.substring(0, i));
      await tester.pump();
      await frame(110);
    }
    await frame(500);
  }

  /// Writes the frames and their durations to build/gif_frames/[name].
  void save(String name) {
    final directory = Directory('${_framesRoot.path}/$name');
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    final durations = <int>[];
    for (final (i, (bytes, ms)) in _frames.indexed) {
      File(
        '${directory.path}/${i.toString().padLeft(4, '0')}.png',
      ).writeAsBytesSync(bytes);
      durations.add(ms);
    }
    File(
      '${directory.path}/durations.json',
    ).writeAsStringSync(jsonEncode(durations));
  }
}

/// Shows forms/[form].xml at [size] and returns a recorder of it.
Future<(_Recorder, FormSession)> _start(
  WidgetTester tester,
  String form, {
  Size size = phone,
  double pixelRatio = 1,
  XFormMode mode = XFormMode.pager,
  void Function(FormSession session)? prepare,
}) async {
  tester.view
    ..physicalSize = size * pixelRatio
    ..devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  final touches = ValueNotifier<Offset?>(null);
  addTearDown(touches.dispose);
  final session = (await tester.runAsync(() => loadCatalogForm(form)))!;
  prepare?.call(session);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    screenshotApp(
      boundary: boundary,
      touches: touches,
      home: Scaffold(
        appBar: AppBar(title: Text(session.definition.title ?? '')),
        body: XFormView(
          session: session,
          mode: mode,
          delegates: DemoDelegates(_images),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await precacheScreenImages(tester);
  await tester.pumpAndSettle();
  final recorder = _Recorder(tester, boundary, touches, pixelRatio: pixelRatio);
  await recorder.frame(800);
  return (recorder, session);
}

/// Jumps the pager to the node named [name].
void Function(FormSession) _at(String name) =>
    (s) => s.navigator.jumpTo(nodeNamed<FormNode>(s.root, name).index);

Finder get _field => find.byType(TextField);
Finder get _next => find.text('Next');

/// The recordings, by GIF name.
final Map<String, Future<void> Function(WidgetTester tester)> _recordings = {
  // The pager: answering screen after screen, the progress bar filling.
  'pager_navigation': (tester) async {
    final (r, _) = await _start(tester, 'survey');
    await r.type(_field, 'Amina');
    await r.tap(_next);
    await r.type(_field, '34');
    await r.tap(_next);
    await r.tap(find.text('No'));
    await r.tap(_next);
    await r.tap(_next);
    await r.tap(find.text('Back'));
    await r.frame(1200);
    r.save('pager_navigation');
  },
  // Relevance: "Yes" shows the follow-up questions, "No" hides them.
  'relevance': (tester) async {
    final (r, _) = await _start(tester, 'survey', prepare: _at('children'));
    await r.tap(find.text('Yes'));
    await r.tap(find.byTooltip('Increase'));
    await r.tap(find.byTooltip('Increase'));
    await r.tap(find.text('Primary'));
    await r.tap(find.text('No'));
    await r.frame(1200);
    r.save('relevance');
  },
  // A constraint error as the answer is typed, then fixed.
  'constraint_error': (tester) async {
    final (r, session) = await _start(
      tester,
      'survey',
      prepare: (s) {
        s.answer(
          nodeNamed<QuestionNode>(s.root, 'name').index,
          const StringValue('Amina'),
        );
        _at('age')(s);
      },
    );
    await r.type(_field, '150');
    await r.frame(1000);
    await tester.enterText(_field, '');
    await tester.pump();
    await r.frame(300);
    await r.type(_field, '34');
    await r.tap(_next);
    await r.frame(1000);
    r.save('constraint_error');
  },
  // Next on a long screen with required answers missing: the first one
  // is scrolled into view and focused.
  'focus_first_error': (tester) async {
    final (r, _) = await _start(tester, 'survey', prepare: _at('contact'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await r.animate(steps: 4);
    await r.tap(find.text('Yes'));
    await r.tap(_next, steps: 10);
    await r.frame(1500);
    r.save('focus_first_error');
  },
  // The outline side panel on a desktop window: jumping to a question.
  'outline_jump': (tester) async {
    final (r, _) = await _start(
      tester,
      'survey',
      size: const Size(960, 600),
      pixelRatio: 0.75,
      prepare: (s) => s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      ),
    );
    await r.tap(find.text('Contact details').first);
    await r.tap(find.text('Date of the visit').first);
    await r.tap(find.textContaining('children under 18').last);
    await r.frame(1200);
    r.save('outline_jump');
  },
  // The same screen as the window grows from a phone to a desktop.
  'adaptive_resize': (tester) async {
    const ratio = 0.5625;
    final (r, _) = await _start(
      tester,
      'survey',
      size: const Size(360, 800),
      pixelRatio: ratio,
      prepare: _at('contact'),
    );
    for (var width = 360.0; width <= 1280; width += 40) {
      tester.view.physicalSize = Size(width, 800) * ratio;
      await tester.pumpAndSettle();
      await r.frame(width == 600 || width == 840 ? 900 : 90);
    }
    await r.frame(1500);
    r.save('adaptive_resize');
  },
  // Adding a repeat instance from the pager's prompt.
  'repeat_add': (tester) async {
    final (r, _) = await _start(
      tester,
      'repeats',
      prepare: (s) {
        final members = nodeNamed<RepeatNode>(s.root, 'member');
        s.navigator.jumpTo(questionsUnder(members.instances.last).last.index);
      },
    );
    await r.tap(_next);
    await r.tap(find.text('Add group'));
    await r.type(_field, 'Baraka');
    await r.tap(_next);
    await r.type(_field, '4');
    await r.tap(_next);
    await r.frame(1200);
    r.save('repeat_add');
  },
  // An Ethiopian-calendar date: the calendar's own months and years.
  'calendar_picker': (tester) async {
    final (r, _) = await _start(tester, 'date_time', prepare: _at('ethiopian'));
    await r.tap(find.text('Select date'));
    await r.tap(find.byKey(const ValueKey('calendar-month')));
    await r.tap(find.text('Miazia').last);
    await r.tap(find.byKey(const ValueKey('calendar-day')));
    await r.tap(find.text('14').last);
    await r.tap(find.text('OK'));
    await r.frame(1500);
    r.save('calendar_picker');
  },
};

void main() {
  setUpAll(() async {
    if (!screenshotsEnabled) return;
    await loadScreenshotFonts();
    _images = await renderChoiceImages();
  });

  for (final MapEntry(key: name, value: record) in _recordings.entries) {
    testWidgets(
      name,
      record,
      skip: !screenshotsEnabled,
      experimentalLeakTesting: screenshotLeakTesting,
    );
  }
}
