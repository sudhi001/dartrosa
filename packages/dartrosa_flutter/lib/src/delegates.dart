import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/widgets.dart';

import 'widgets/map_inputs.dart';

/// Captures data the renderer can't get on its own: photos, recordings,
/// files, locations, barcodes. Apps implement the ones their forms need
/// (for example with image_picker, geolocator, mobile_scanner); questions
/// without a delegate fall back to typing the value.
abstract class XFormDelegates {
  /// Creates delegates.
  const XFormDelegates();

  /// Captures or picks a file for an upload question of [mediaType]
  /// (`image/*`, `audio/*`, `video/*`, ...); returns its file name, or
  /// `null` if cancelled.
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) async => null;

  /// The device location as an ODK geopoint (`lat lon altitude
  /// accuracy`), or `null` if unavailable.
  Future<String?> currentLocation(BuildContext context) async => null;

  /// A scanned barcode, or `null` if cancelled.
  Future<String?> scanBarcode(BuildContext context) async => null;

  /// An image for a `jr://images/...` (or other `jr://`) URI in labels.
  ImageProvider? image(String uri) => null;

  /// The bytes of a `jr://` media file (e.g. the SVG of an `image-map`
  /// select), or `null` if unavailable.
  Future<Uint8List?> mediaBytes(String uri) async => null;

  /// Opens a link tapped in a label or hint (e.g. with url_launcher).
  Future<void> openLink(BuildContext context, Uri uri) async {}

  /// Lets the user pick one of [features] (the choices of [node] with a
  /// geometry) on a map, [selected] being the current answer; returns the
  /// picked choice, or `null` if cancelled. Used by select one questions
  /// with the `map` appearance when [canShowMaps].
  Future<SelectChoice?> selectFromMap(
    BuildContext context, {
    required QuestionNode node,
    required List<MapFeature> features,
    SelectChoice? selected,
  }) async => null;

  /// Lets the user capture [node]'s geopoint (`maps` or `placement-map`
  /// appearance), geotrace or geoshape on a map, starting from its
  /// current value; returns the ODK geo value (`lat lon alt acc`, `;`
  /// separated for traces and shapes), `''` to clear it, or `null` if
  /// cancelled. Used when [canShowMaps].
  Future<String?> geoFromMap(
    BuildContext context, {
    required QuestionNode node,
  }) async => null;

  /// Whether [captureMedia] is implemented.
  bool get canCaptureMedia => false;

  /// Whether [currentLocation] is implemented.
  bool get canLocate => false;

  /// Whether [scanBarcode] is implemented.
  bool get canScanBarcode => false;

  /// Whether [selectFromMap] and [geoFromMap] are implemented; otherwise
  /// `map` selects and geo questions get their default widgets.
  bool get canShowMaps => false;
}

/// No platform features: every capture falls back to manual entry.
class NoDelegates extends XFormDelegates {
  /// Creates the default delegates.
  const NoDelegates();
}
