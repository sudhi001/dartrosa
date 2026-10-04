import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/widgets.dart';

import 'external_apps.dart';
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

  /// Launches the external app [intent] (an Android intent action or
  /// package name, from an `ex:` appearance or a group's `intent`
  /// attribute) with the evaluated [params] (Android intent extras; for
  /// `ex:` questions `value` is the current answer) and, from the
  /// `uri_data` parameter, [data]. Returns the app's results (`value` for
  /// `ex:` questions, question names for intent groups), or `null` if
  /// cancelled. Throws `ExternalAppNotFoundException` when no app handles
  /// it. Used when [canLaunchExternalApps].
  Future<Map<String, Object?>?> launchExternalApp(
    BuildContext context, {
    required String intent,
    required Map<String, Object?> params,
    String? data,
  }) async => throw const ExternalAppNotFoundException();

  /// The saved instance's id for the `instanceProviderID()` parameter of
  /// external apps (`null`: not saved yet, sent as `-1`).
  String? get instanceProviderId => null;

  /// Prints [content], the answer of a question with the `printer`
  /// appearance (ODK Collect parses it as HTML with `<qrcode>` and
  /// `<barcode>` elements). Used when [canPrint].
  Future<void> print(BuildContext context, String content) async {}

  /// The device's compass heading in degrees (0-360), for decimal
  /// questions with the `bearing` appearance, or `null` if cancelled.
  /// Used when [canReadBearing].
  Future<double?> compassBearing(BuildContext context) async => null;

  /// Whether [captureMedia] is implemented.
  bool get canCaptureMedia => false;

  /// Whether [currentLocation] is implemented.
  bool get canLocate => false;

  /// Whether [scanBarcode] is implemented.
  bool get canScanBarcode => false;

  /// Whether [compassBearing] is implemented; otherwise `bearing`
  /// questions are typed.
  bool get canReadBearing => false;

  /// Whether [launchExternalApp] is implemented; otherwise `ex:`
  /// questions and intent groups get their default widgets.
  bool get canLaunchExternalApps => false;

  /// Whether [print] is implemented; otherwise `printer` questions get
  /// their default widget.
  bool get canPrint => false;

  /// Whether [selectFromMap] and [geoFromMap] are implemented; otherwise
  /// `map` selects and geo questions get their default widgets.
  bool get canShowMaps => false;
}

/// No platform features: every capture falls back to manual entry.
class NoDelegates extends XFormDelegates {
  /// Creates the default delegates.
  const NoDelegates();
}
