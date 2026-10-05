// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of the docs/widgets/ catalog pages, compiled and run so the
// catalog can't rot (doc_snippets.dart checks that every snippet is here).
// Names the snippets take from other packages (geolocator, image_picker,
// url_launcher) or from the app (MyMapPage, ...) are small stand-ins at the
// bottom of this file. The README's and select-one's `AppDelegates` are in
// widgets_catalog_delegates_test.dart.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// groups.md
final groupThemes = <ThemeData>[
  ThemeData(
    extensions: const [
      XFormTheme(cardElevation: 1, cardPadding: EdgeInsets.all(12)),
    ],
  ),
];

// image-maps-maps-and-csv.md: image maps.
class _MediaBytesDelegates extends XFormDelegates {
  final Directory mediaDir = Directory.systemTemp;

  @override
  Future<Uint8List?> mediaBytes(String uri) async {
    final file = File('${mediaDir.path}/${Uri.parse(uri).pathSegments.last}');
    return file.existsSync() ? file.readAsBytes() : null;
  }
}

// image-maps-maps-and-csv.md: map selects.
class _MapSelectDelegates extends XFormDelegates {
  @override
  bool get canShowMaps => true;

  @override
  Future<SelectChoice?> selectFromMap(
    BuildContext context, {
    required QuestionNode node,
    required List<MapFeature> features,
    SelectChoice? selected,
  }) => Navigator.push<SelectChoice>(
    context,
    MaterialPageRoute(builder: (_) => MyMapPage(features, selected)),
  );
}

// image-maps-maps-and-csv.md: search() over CSV media.
Future<FormDefinition> _parseWithCsv(String xml, Uint8List csvBytes) async {
  final definition = await FormDefinition.parse(
    xml,
    config: DartRosaConfig(
      resolver: MapResourceResolver({'jr://file/fruits.csv': csvBytes}),
      plugins: [
        ExternalDataPlugin(listMedia: (_) => ['fruits.csv']),
      ],
    ),
  );
  return definition;
}

// location.md: geopoint.
class _LocationDelegates extends XFormDelegates {
  @override
  bool get canLocate => true;

  @override
  Future<String?> currentLocation(BuildContext context) async {
    final p = await Geolocator.getCurrentPosition();
    return '${p.latitude} ${p.longitude} ${p.altitude} ${p.accuracy}';
  }
}

// location.md: geo questions on a map.
class _GeoMapDelegates extends XFormDelegates {
  @override
  bool get canShowMaps => true;

  @override
  Future<String?> geoFromMap(
    BuildContext context, {
    required QuestionNode node,
  }) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => MyGeoPage(
        type: node.dataType, // geopoint, geotrace or geoshape
        initial: parseGeometry(node.value?.displayText ?? ''),
      ),
    ),
  );
}

// media-and-barcodes.md: media capture.
class _MediaDelegates extends XFormDelegates {
  final Directory instanceDir = Directory.systemTemp;

  @override
  bool get canCaptureMedia => true;

  @override
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) async {
    final file = switch (mediaType) {
      'image/*' => await ImagePicker().pickImage(source: ImageSource.camera),
      'video/*' => await ImagePicker().pickVideo(source: ImageSource.camera),
      _ => null, // audio, files: a recorder or file picker
    };
    if (file == null) return null;
    final name = file.name;
    await file.saveTo('${instanceDir.path}/$name');
    return name;
  }
}

// media-and-barcodes.md: barcodes.
class _BarcodeDelegates extends XFormDelegates {
  @override
  bool get canScanBarcode => true;

  @override
  Future<String?> scanBarcode(BuildContext context) => Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const MyScannerPage()),
  );
}

// navigation-and-layout.md: the two modes.
List<Widget> _modes(FormSession session) => [
  XFormView(session: session, mode: XFormMode.pager),
  XFormView(session: session, mode: XFormMode.scroll),
];

// navigation-and-layout.md: the outline.
void showOutlineFromAppBar(FormSession session) {
  final formKey = GlobalKey<XFormViewState>();

  XFormView(
    key: formKey,
    session: session,
    outline: XFormOutlineMode.adaptive, // or onRequest, none
  );

  // From an app bar button:
  formKey.currentState!.showOutline();
}

// special-inputs.md: bearing.
class _BearingDelegates extends XFormDelegates {
  @override
  bool get canReadBearing => true;

  @override
  Future<double?> compassBearing(BuildContext context) =>
      Navigator.push<double>(
        context,
        MaterialPageRoute(builder: (_) => const MyCompassPage()),
      );
}

// special-inputs.md: url.
class _LinkDelegates extends XFormDelegates {
  @override
  Future<void> openLink(BuildContext context, Uri uri) async {
    await launchUrl(uri);
  }
}

// special-inputs.md: ex: and intent groups.
class _ExternalAppDelegates extends XFormDelegates {
  @override
  bool get canLaunchExternalApps => true;

  @override
  Future<Map<String, Object?>?> launchExternalApp(
    BuildContext context, {
    required String intent,
    required Map<String, Object?> params,
    String? data,
  }) async {
    // On Android, start the activity for a result (e.g. a platform
    // channel); throw ExternalAppNotFoundException when none is installed.
    return myIntentChannel.startForResult(intent, params, data);
  }
}

const _searchForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>Fruit</h:title><model>
    <instance><data id="fruit"><fruit/></data></instance>
    <bind nodeset="/data/fruit" type="string"/>
  </model></h:head>
  <h:body>
    <select1 ref="/data/fruit" appearance="search('fruits')">
      <label>Fruit</label>
      <item><label>name</label><value>name</value></item>
    </select1>
  </h:body>
</h:html>''';

void main() {
  test('the catalog delegates declare their features', () {
    expect(groupThemes.single.extension<XFormTheme>()!.cardElevation, 1);
    expect(_MediaBytesDelegates().mediaDir, isNotNull);
    expect(_MapSelectDelegates().canShowMaps, isTrue);
    expect(_LocationDelegates().canLocate, isTrue);
    expect(_GeoMapDelegates().canShowMaps, isTrue);
    expect(_MediaDelegates().canCaptureMedia, isTrue);
    expect(_BarcodeDelegates().canScanBarcode, isTrue);
    expect(_BearingDelegates().canReadBearing, isTrue);
    expect(_LinkDelegates(), isA<XFormDelegates>());
    expect(_ExternalAppDelegates().canLaunchExternalApps, isTrue);
  });

  test('search() forms get their CSV data', () async {
    final definition = await _parseWithCsv(
      _searchForm,
      utf8.encode('name,label\nmango,Mango\napple,Apple\n'),
    );
    // The plugin imported the CSV for the form's search() selects.
    expect(definition.formDef.extras.get<ExternalDataManager>(), isNotNull);
    expect(_modes(definition.createSession()), hasLength(2));
  });
}

// Stand-ins for names the snippets take from other packages or the app.

class Geolocator {
  static Future<Position> getCurrentPosition() async => const Position();
}

class Position {
  const Position();
  double get latitude => 0;
  double get longitude => 0;
  double get altitude => 0;
  double get accuracy => 0;
}

enum ImageSource { camera }

class ImagePicker {
  Future<PickedFile?> pickImage({required ImageSource source}) async => null;
  Future<PickedFile?> pickVideo({required ImageSource source}) async => null;
}

class PickedFile {
  String get name => 'photo.jpg';
  Future<void> saveTo(String path) async {}
}

Future<bool> launchUrl(Uri uri) async => true;

final myIntentChannel = IntentChannel();

class IntentChannel {
  Future<Map<String, Object?>?> startForResult(
    String intent,
    Map<String, Object?> params,
    String? data,
  ) async => const {};
}

Object? parseGeometry(String text) => text;

class MyMapPage extends StatelessWidget {
  const MyMapPage(this.features, this.selected, {super.key});
  final List<MapFeature> features;
  final SelectChoice? selected;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MyGeoPage extends StatelessWidget {
  const MyGeoPage({required this.type, required this.initial, super.key});
  final DataType type;
  final Object? initial;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MyScannerPage extends StatelessWidget {
  const MyScannerPage({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MyCompassPage extends StatelessWidget {
  const MyCompassPage({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}
