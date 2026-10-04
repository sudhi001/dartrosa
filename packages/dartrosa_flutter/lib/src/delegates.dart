import 'package:flutter/widgets.dart';

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

  /// Whether [captureMedia] is implemented.
  bool get canCaptureMedia => false;

  /// Whether [currentLocation] is implemented.
  bool get canLocate => false;

  /// Whether [scanBarcode] is implemented.
  bool get canScanBarcode => false;
}

/// No platform features: every capture falls back to manual entry.
class NoDelegates extends XFormDelegates {
  /// Creates the default delegates.
  const NoDelegates();
}
