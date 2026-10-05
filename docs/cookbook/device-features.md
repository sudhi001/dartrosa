# Connect the camera, location and barcode scanner

**Type:** recipe. **Package:** `dartrosa_flutter`.

ODK forms ask for photos, GPS points, barcodes, signatures and
recordings. `dartrosa_flutter` draws those questions but does not depend
on any device plugin: it calls an `XFormDelegates` object you provide, so
you keep the plugins your app already uses (image_picker, camera,
geolocator, mobile_scanner, ...) and their permission handling. Without
delegates, these questions let the person type the value.

This recipe connects location, barcodes and photos, using the following
steps:

1. Subclass `XFormDelegates`.
2. Return values in ODK's formats.
3. Pass the delegates to `XFormView`.

## 1. Subclass `XFormDelegates`

Every method has a default that does nothing, so override only what you
support, and turn on each feature with its `can...` getter (otherwise
the question keeps its typed fallback). To keep the class free of plugin imports (and easy to test),
this one receives the device calls as functions:

```dart
/// A geopoint from your location plugin.
typedef Fix = ({double lat, double lon, double altitude, double accuracy});

/// Device features from the plugins your app already uses, passed in as
/// functions so this class doesn't depend on any of them.
class AppDelegates extends XFormDelegates {
  const AppDelegates({
    required this.locate,
    required this.scan,
    required this.takePhoto,
  });

  /// For example geolocator's `Geolocator.getCurrentPosition`.
  final Future<Fix?> Function() locate;

  /// For example a mobile_scanner screen that returns the raw value.
  final Future<String?> Function(BuildContext context) scan;

  /// For example image_picker: saves the picture next to the draft and
  /// returns its file name.
  final Future<String?> Function(String mediaType) takePhoto;

  // Turn on the capture buttons of the features you implement.
  @override
  bool get canLocate => true;

  @override
  bool get canScanBarcode => true;

  @override
  bool get canCaptureMedia => true;

  @override
  Future<String?> currentLocation(BuildContext context) async {
    final fix = await locate();
    if (fix == null) return null;
    // ODK geopoints are "latitude longitude altitude accuracy".
    return '${fix.lat} ${fix.lon} ${fix.altitude} ${fix.accuracy}';
  }

  @override
  Future<String?> scanBarcode(BuildContext context) => scan(context);

  @override
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) => takePhoto(mediaType);
}
```

With geolocator, for example, `locate` would be:

```text
() async {
  final p = await Geolocator.getCurrentPosition();
  return (lat: p.latitude, lon: p.longitude,
          altitude: p.altitude, accuracy: p.accuracy);
}
```

## 2. Return values in ODK's formats

| Method | Turned on by | Called for | Return |
|---|---|---|---|
| `currentLocation` | `canLocate` | `geopoint` questions | `"lat lon altitude accuracy"`, or `null` |
| `scanBarcode` | `canScanBarcode` | `barcode` questions | the decoded text, or `null` if cancelled |
| `captureMedia` | `canCaptureMedia` | `image`, `audio`, `video`, `file` questions (`mediaType` is `image/*`, `audio/*`, ...; `appearance` is for example `signature`, `draw`, `annotate`, `new`) | the saved file's name, or `null` if cancelled |
| `image`, `mediaBytes` | (always used) | pictures and media in labels (`jr://images/...`) | an `ImageProvider`, or the bytes |
| `selectFromMap`, `geoFromMap` | `canShowMaps` | `map` appearances, geotrace and geoshape | the choice, or the points (`;` between them) |
| `launchExternalApp` | `canLaunchExternalApps` | `ex:` appearances and intent groups | the values the app returned |
| `print` | `canPrint` | `printer` appearances | |
| `compassBearing` | `canReadBearing` | `bearing` appearances | degrees |
| `openLink` | (always used) | links in labels and hints | |

`captureMedia` returns a **file name**, which becomes the answer. Save
the file where your app keeps the draft's files, under that name, so you
can attach it when uploading (see the
[tutorial's step 8](../tutorials/build-a-data-collection-app.md#8-finalize-and-encrypt)).
Respect `orx:max-pixels` (in `node.attributes`) when resizing photos.

## 3. Pass them to `XFormView`

```text
XFormView(session: session, delegates: AppDelegates(
  locate: ..., scan: ..., takePhoto: ...))
```

The capture buttons appear for the features whose `can...` getter
returns `true`.

## How it works

`XFormView` puts the delegates in the `XFormScope` it creates. A capture
widget calls the delegate, waits for the result and answers the question
with it, so the usual validation (required, constraints) applies to the
value you return. Because the engine never touches the device, the same
form works in widget tests with fake delegates like the ones in
`packages/dartrosa_flutter/test/docs/cookbook_test.dart`.

## Related

* [Show a form in Flutter, step 3](../guides/render-a-form-in-flutter.md#3-connect-the-device-features):
  images in labels from the media folder
* [Widget catalog](../widgets/README.md): what each capture question looks
  like
* `XFormDelegates` in the
  [API reference](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormDelegates-class.html)
