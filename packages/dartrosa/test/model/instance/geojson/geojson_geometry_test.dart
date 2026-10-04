// Port of JavaRosa v6.0.0 GeojsonGeometryTest.
import 'package:dartrosa/src/model/instance/external/geojson_instance.dart';
import 'package:test/test.dart';

void main() {
  test('when a polygon has multiple rings, only the first is used', () {
    final geometry = GeojsonGeometry.parse(
      '{"type": "Polygon","coordinates": [[[1, 2], [1, 2]],[[3, 4], [3, 4]]]}',
    );
    expect(geometry.odkCoordinates, '2 1 0 0; 2 1 0 0');
  });

  test('when polygon coordinates are empty, ODK coordinates are empty', () {
    final geometry = GeojsonGeometry.parse(
      '{"type": "Polygon","coordinates": []}',
    );
    expect(geometry.odkCoordinates, '');
  });
}
