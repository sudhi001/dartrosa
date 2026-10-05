// Renders the screenshots in docs/images/screenshots/: XFormView showing
// conformance-corpus forms at phone size, in light and dark themes, with
// the real Roboto and Material Icons fonts (the default test font draws
// boxes).
//
// It never runs in CI or a plain `flutter test`: it is skipped unless
// DARTROSA_SCREENSHOTS is set, and runs on macOS only (text rasterization
// differs between platforms). From packages/dartrosa_flutter:
//
//   DARTROSA_SCREENSHOTS=1 flutter test test/screenshots --tags screenshots
//
// then shrink the PNGs (lossless palette quantization keeps them small):
//
//   python3 test/screenshots/optimize_pngs.py ../../docs/images/screenshots
@Tags(['screenshots'])
@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone screen, in logical pixels, and its pixel ratio.
const _phone = Size(360, 720);
const _pixelRatio = 2.0;

final _enabled =
    Platform.environment.containsKey('DARTROSA_SCREENSHOTS') ||
    const bool.fromEnvironment('DARTROSA_SCREENSHOTS');

final _corpus = Directory('../../conformance/forms');
final _out = Directory('../../docs/images/screenshots');

/// The Flutter SDK's font cache (`bin/cache/artifacts/material_fonts`).
Directory _materialFonts() {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  return Directory('$root/bin/cache/artifacts/material_fonts');
}

Future<void> _loadFonts() async {
  final fonts = _materialFonts();
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf'))
        ..addFont(read('Roboto-Bold.ttf'))
        ..addFont(read('Roboto-Italic.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

/// Serves `jr://images/<name>` from the form's folder.
class _CorpusImages extends XFormDelegates {
  const _CorpusImages(this.images);

  final Map<String, Uint8List> images;

  @override
  ImageProvider? image(String uri) {
    final bytes = images[uri.split('/').last];
    return bytes == null ? null : MemoryImage(bytes);
  }
}

/// One screenshot: a corpus form, how it is shown and how to prepare it.
class _Shot {
  const _Shot(
    this.name,
    this.form, {
    this.mode = XFormMode.pager,
    this.prepare,
    this.afterPump,
    this.images = const [],
  });

  final String name;
  final String form;
  final XFormMode mode;
  final void Function(FormSession session)? prepare;
  final Future<void> Function(WidgetTester tester)? afterPump;
  final List<String> images;
}

/// The first node (depth first) whose reference, without positions such
/// as `[1]`, ends with [name].
T _node<T extends FormNode>(FormNode node, String name) {
  T? find(FormNode n) {
    final reference = n.index.reference.toString().replaceAll(
      RegExp(r'\[\d+\]'),
      '',
    );
    if (n is T && reference.endsWith(name)) return n;
    final children = [
      if (n is ContainerNode) ...n.children,
      if (n is RepeatNode) ...n.instances,
    ];
    for (final child in children) {
      final found = find(child);
      if (found != null) return found;
    }
    return null;
  }

  return find(node) ?? (throw StateError('No node $name'));
}

final _shots = [
  // A group of number inputs with hints, some answered.
  _Shot(
    'text_number',
    'collect/all-widgets.xml',
    prepare: (s) {
      final integer = _node<QuestionNode>(s.root, '/integer_widget');
      s.answer(integer.index, const IntegerValue(42));
      final grouped = _node<QuestionNode>(
        s.root,
        '/integer_thousands_sep_widget',
      );
      s.answer(grouped.index, const IntegerValue(1234567));
      s.navigator.jumpTo(_node<GroupNode>(s.root, '/number_widgets').index);
    },
  ),
  // A select whose choices have images, one chosen.
  _Shot(
    'select_images',
    'webforms/select/3-images-choice.xml',
    images: ['tiger.jpg', 'camel.jpg'],
    prepare: (s) => s.answer(
      s.root.children.first.index,
      const SelectOneValue(Selection('tiger')),
    ),
  ),
  // A field-list group with nested groups: several questions on one
  // screen.
  _Shot(
    'field_list',
    'collect/form8.xml',
    prepare: (s) {
      final first = _node<QuestionNode>(s.root, '/T1');
      s.answer(first.index, const StringValue('Amina'));
    },
  ),
  // A repeat (the form starts with several instances), in scroll mode.
  const _Shot('repeat', 'collect/repeat_groups.xml', mode: XFormMode.scroll),
  // A date question with Collect's Ethiopian calendar appearance.
  _Shot(
    'date_ethiopian',
    'collect/all-widgets.xml',
    prepare: (s) {
      final date = _node<QuestionNode>(s.root, '/ethiopian_date_widget');
      s.answer(date.index, DateValue(DateTime(2024, 3, 20)));
      s.navigator.jumpTo(date.index);
    },
    // Open the Ethiopian calendar's spinners.
    afterPump: (tester) async {
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
    },
  ),
  // Required questions left empty: tapping Next shows the errors.
  _Shot(
    'validation_error',
    'collect/requiredQuestionInFieldList.xml',
    afterPump: (tester) async {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    },
  ),
];

Future<void> _render(
  WidgetTester tester,
  _Shot shot,
  Brightness brightness,
) async {
  tester.view.physicalSize = _phone * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);

  final formFile = File('${_corpus.path}/${shot.form}');
  final images = {
    for (final name in shot.images)
      name: File('${formFile.parent.path}/$name').readAsBytesSync(),
  };
  final session = await tester.runAsync(() async {
    final definition = await FormDefinition.parse(formFile.readAsStringSync());
    return definition.createSession();
  });
  shot.prepare?.call(session!);

  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          colorSchemeSeed: const Color(0xFF1A73E8),
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          appBar: AppBar(title: Text(session!.definition.title ?? '')),
          body: XFormView(
            session: session,
            mode: shot.mode,
            delegates: _CorpusImages(images),
          ),
        ),
      ),
    ),
  );
  // Decode the choice images outside the fake-async zone.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
  await shot.afterPump?.call(tester);

  final bytes = await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final theme = brightness == Brightness.light ? 'light' : 'dark';
  _out.createSync(recursive: true);
  File('${_out.path}/${shot.name}_$theme.png').writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  for (final shot in _shots) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${shot.name} ${brightness.name}',
        (tester) => _render(tester, shot, brightness),
        skip: !_enabled,
      );
    }
  }
}
