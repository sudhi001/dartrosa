/// Geodesic helpers for `area()`, `distance()` and `geofence()`.
///
/// Port of `org.javarosa.core.util.GeoUtils`, keeping its formulas and
/// earth radius so results match JavaRosa.
library;

import 'dart:math' as math;

/// A latitude/longitude pair in degrees.
typedef LatLong = ({double latitude, double longitude});

/// JavaRosa's earth radius (equatorial), in meters.
const earthEquatorialRadiusMeters = 6378100.0;

/// JavaRosa's equatorial circumference, in meters.
const earthEquatorialCircumferenceMeters =
    2 * earthEquatorialRadiusMeters * math.pi;

/// Java `Math.toRadians` (multiplication by the degrees-to-radians
/// constant).
double _toRadians(double degrees) => degrees * 0.017453292519943295;

/// Area of the polygon [points] in square meters (0 for fewer than three
/// points), using JavaRosa's planar approximation.
double areaOfPolygon(List<LatLong> points) {
  if (points.length < 3) return 0;
  final ys = <double>[];
  final xs = <double>[];
  final latitudeRef = points.first.latitude;
  final longitudeRef = points.first.longitude;
  for (var i = 1; i < points.length; i++) {
    final latitude = points[i].latitude;
    final longitude = points[i].longitude;
    ys.add(
      (latitude - latitudeRef) * earthEquatorialCircumferenceMeters / 360.0,
    );
    xs.add(
      (longitude - longitudeRef) *
          earthEquatorialCircumferenceMeters *
          math.cos(_toRadians(latitude)) /
          360.0,
    );
  }
  var sum = 0.0;
  for (var i = 1; i < xs.length; i++) {
    sum += (ys[i - 1] * xs[i] - xs[i - 1] * ys[i]) / 2;
  }
  return sum.abs();
}

/// Total length in meters of the path through [points] (spherical law of
/// cosines).
double distance(List<LatLong> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _distanceBetween(points[i - 1], points[i]);
  }
  return total;
}

double _distanceBetween(LatLong p1, LatLong p2) {
  final deltaLambda = _toRadians(p1.longitude - p2.longitude);
  final phi1 = _toRadians(p1.latitude);
  final phi2 = _toRadians(p2.latitude);
  return math.acos(
        math.sin(phi1) * math.sin(phi2) +
            math.cos(phi1) * math.cos(phi2) * math.cos(deltaLambda),
      ) *
      earthEquatorialRadiusMeters;
}

/// Whether [point] lies inside [polygon] (ray casting). Geoshapes repeat
/// the first point at the end, so the polygon isn't wrapped.
bool isPointInPolygon(LatLong point, List<LatLong> polygon) {
  final x = point.longitude;
  final y = point.latitude;
  var inside = false;
  for (var i = 1; i < polygon.length; i++) {
    final p1 = polygon[i - 1];
    final p2 = polygon[i];
    if ((p2.latitude > y) != (p1.latitude > y) &&
        x <
            (p1.longitude - p2.longitude) *
                    (y - p2.latitude) /
                    (p1.latitude - p2.latitude) +
                p2.longitude) {
      inside = !inside;
    }
  }
  return inside;
}
