// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Shared by the screenshot, catalog and GIF tests in this directory:
// fonts, the demo delegates, the forms in forms/ and image capture.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone window, in logical pixels, and the docs' pixel ratio.
const phone = Size(360, 720);
const docsPixelRatio = 2.0;

/// The seed color of the screenshots' Material 3 theme.
const seedColor = Color(0xFF1A73E8);

/// Whether images are rendered: only with DARTROSA_SCREENSHOTS set (as
/// an environment variable or a `--dart-define`).
final bool screenshotsEnabled =
    Platform.environment.containsKey('DARTROSA_SCREENSHOTS') ||
    const bool.fromEnvironment('DARTROSA_SCREENSHOTS');

/// The repository's docs/images folder.
final Directory docsImages = Directory('../../docs/images');

/// The purpose-built forms of the widget catalog.
final Directory catalogForms = Directory('test/screenshots/forms');

/// The Flutter SDK's font cache (`bin/cache/artifacts/material_fonts`).
Directory _materialFonts() {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  return Directory('$root/bin/cache/artifacts/material_fonts');
}

/// Loads Roboto and Material Icons (the default test font draws boxes).
Future<void> loadScreenshotFonts() async {
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
  // Month names of the Bikram Sambat, Buddhist and Myanmar calendars,
  // from the macOS system fonts when present (Roboto has no Devanagari,
  // Thai or Myanmar letters).
  for (final MapEntry(key: family, value: path) in _scriptFonts.entries) {
    final file = File(path);
    if (!file.existsSync()) continue;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
        .load();
  }
}

/// Fallback fonts for scripts Roboto lacks, by family name.
const Map<String, String> _scriptFonts = {
  'ScriptDevanagari': '/System/Library/Fonts/Kohinoor.ttc',
  'ScriptThai': '/System/Library/Fonts/Supplemental/Thonburi.ttc',
  'ScriptMyanmar': '/System/Library/Fonts/NotoSansMyanmar.ttc',
};

/// The screenshots' theme.
ThemeData screenshotTheme(Brightness brightness, {XFormTheme? form}) =>
    ThemeData(
      brightness: brightness,
      colorSchemeSeed: seedColor,
      fontFamily: 'Roboto',
      fontFamilyFallback: _scriptFonts.keys.toList(),
      extensions: [?form],
    );

/// The icon and color of each generated choice image
/// (`jr://images/<name>.png`).
const Map<String, (IconData, Color)> _icons = {
  'walk': (Icons.directions_walk, Color(0xFF2E7D32)),
  'bike': (Icons.directions_bike, Color(0xFF00838F)),
  'bus': (Icons.directions_bus, Color(0xFFEF6C00)),
  'car': (Icons.directions_car, Color(0xFF5E35B1)),
  'happy': (Icons.sentiment_very_satisfied, Color(0xFF2E7D32)),
  'neutral': (Icons.sentiment_neutral, Color(0xFFF9A825)),
  'sad': (Icons.sentiment_very_dissatisfied, Color(0xFFC62828)),
  'water': (Icons.water_drop, Color(0xFF1565C0)),
  'house': (Icons.house, Color(0xFF6D4C41)),
};

/// Draws the choice images: a colored rounded square with an icon.
/// Runs outside the fake-async zone (in `setUpAll`).
Future<Map<String, Uint8List>> renderChoiceImages() async {
  final images = <String, Uint8List>{};
  for (final MapEntry(key: name, value: (icon, color)) in _icons.entries) {
    const size = 160.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, size, size),
          const Radius.circular(28),
        ),
        Paint()..color = color,
      );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: 104,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    painter.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    images['$name.png'] = data!.buffer.asUint8List();
  }
  return images;
}

/// Delegates with every platform feature, answering with fixed values:
/// what an app with a camera, GPS, maps, a scanner, external apps and a
/// printer shows. Images come from [images] (by file name), SVGs and
/// other media from forms/media/.
class DemoDelegates extends XFormDelegates {
  /// Creates the delegates.
  const DemoDelegates(this.images);

  /// Choice and label images by file name.
  final Map<String, Uint8List> images;

  @override
  ImageProvider? image(String uri) {
    final bytes = images[uri.split('/').last];
    return bytes == null ? null : MemoryImage(bytes);
  }

  @override
  Future<Uint8List?> mediaBytes(String uri) async {
    final file = File('${catalogForms.path}/media/${uri.split('/').last}');
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  @override
  bool get canCaptureMedia => true;

  @override
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) async => switch (mediaType) {
    'image/*' => 'photo-1730.jpg',
    'audio/*' => 'interview-1730.m4a',
    'video/*' => 'walkthrough-1730.mp4',
    _ => 'household-roster.pdf',
  };

  @override
  bool get canLocate => true;

  @override
  Future<String?> currentLocation(BuildContext context) async =>
      '-1.2864 36.8172 1661 4.5';

  @override
  bool get canScanBarcode => true;

  @override
  Future<String?> scanBarcode(BuildContext context) async => '9780201379624';

  @override
  bool get canReadBearing => true;

  @override
  Future<double?> compassBearing(BuildContext context) async => 274.5;

  @override
  bool get canLaunchExternalApps => true;

  @override
  Future<Map<String, Object?>?> launchExternalApp(
    BuildContext context, {
    required String intent,
    required Map<String, Object?> params,
    String? data,
  }) async => {'value': 37};

  @override
  bool get canPrint => true;

  @override
  bool get canShowMaps => true;

  @override
  Future<String?> geoFromMap(
    BuildContext context, {
    required QuestionNode node,
  }) async => '-1.2864 36.8172 1661 4.5';

  @override
  Future<SelectChoice?> selectFromMap(
    BuildContext context, {
    required QuestionNode node,
    required List<MapFeature> features,
    SelectChoice? selected,
  }) async => features.firstOrNull?.choice;
}

/// Parses the catalog form forms/[name].xml, with the CSV files of
/// forms/media/ as form media (for `search()` selects).
Future<FormSession> loadCatalogForm(String name) async {
  final xml = File('${catalogForms.path}/$name.xml').readAsStringSync();
  final media = Directory('${catalogForms.path}/media');
  final csv = {
    for (final file in media.listSync().whereType<File>())
      if (file.path.endsWith('.csv'))
        file.uri.pathSegments.last: file.readAsBytesSync(),
  };
  final definition = await FormDefinition.parse(
    xml,
    config: DartRosaConfig(
      resolver: MapResourceResolver({
        for (final MapEntry(:key, :value) in csv.entries)
          'jr://file/$key': value,
      }),
      plugins: [ExternalDataPlugin(listMedia: (_) => csv.keys.toList())],
    ),
  );
  return definition.createSession();
}

/// The first node (depth first) whose reference, without positions such
/// as `[1]`, ends with `/`[name].
T nodeNamed<T extends FormNode>(FormNode node, String name) {
  T? find(FormNode n) {
    final reference = n.index.reference.toString().replaceAll(
      RegExp(r'\[\d+\]'),
      '',
    );
    if (n is T && reference.endsWith('/$name')) return n;
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

/// The questions under [node], depth first.
Iterable<QuestionNode> questionsUnder(FormNode node) sync* {
  if (node is QuestionNode) yield node;
  if (node is ContainerNode) {
    for (final child in node.children) {
      yield* questionsUnder(child);
    }
  }
  if (node is RepeatNode) {
    for (final instance in node.instances) {
      yield* questionsUnder(instance);
    }
  }
}

/// A material app showing [home] in the screenshots' theme, inside a
/// repaint boundary with [boundary] as its key; [touches] (for
/// recordings) draws a translucent circle where a finger is.
Widget screenshotApp({
  required GlobalKey boundary,
  required Widget home,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  XFormTheme? form,
  ValueListenable<Offset?>? touches,
}) => RepaintBoundary(
  key: boundary,
  child: Stack(
    textDirection: TextDirection.ltr,
    children: [
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(brightness, form: form),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
      if (touches != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: touches,
              builder: (context, point, _) =>
                  CustomPaint(painter: _TouchPainter(point)),
            ),
          ),
        ),
    ],
  ),
);

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.point);

  final Offset? point;

  @override
  void paint(Canvas canvas, Size size) {
    final point = this.point;
    if (point == null) return;
    canvas
      ..drawCircle(point, 22, Paint()..color = const Color(0x55000000))
      ..drawCircle(
        point,
        22,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_TouchPainter oldDelegate) => oldDelegate.point != point;
}

/// Decodes the images on screen outside the fake-async zone, so they
/// are painted.
Future<void> precacheScreenImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
}

/// The [region] (logical pixels; all of it by default) of the repaint
/// boundary [boundary], as PNG bytes at [pixelRatio].
Future<Uint8List> capturePng(
  WidgetTester tester,
  GlobalKey boundary, {
  required double pixelRatio,
  Rect? region,
}) async {
  final bytes = await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image;
    if (region == null) {
      image = await render.toImage(pixelRatio: pixelRatio);
    } else {
      final layer = render.debugLayer! as OffsetLayer;
      image = await layer.toImage(region, pixelRatio: pixelRatio);
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Writes [bytes] to [file], creating its folder.
void writeImage(File file, Uint8List bytes) {
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

/// The rectangle of [finder] relative to the repaint boundary
/// [boundary].
Rect rectIn(WidgetTester tester, GlobalKey boundary, Finder finder) {
  final origin = tester.getTopLeft(find.byKey(boundary));
  return tester.getRect(finder).shift(-origin);
}

/// The union of [rects], widened to [width] and padded vertically by
/// [padding].
Rect spanOf(Iterable<Rect> rects, {required double width, double padding = 8}) {
  var top = double.infinity;
  var bottom = 0.0;
  for (final rect in rects) {
    top = math.min(top, rect.top);
    bottom = math.max(bottom, rect.bottom);
  }
  return Rect.fromLTRB(0, math.max(0, top - padding), width, bottom + padding);
}
