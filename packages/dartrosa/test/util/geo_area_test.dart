// Port of JavaRosa v6.0.0 GeoAreaTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

// http://www.mapdevelopers.com/area_finder.php?&points=%5B%5B38.253094215699576%2C21.756382658677467%5D%2C%5B38.25021274773806%2C21.756382658677467%5D%2C%5B38.25007793942195%2C21.763892843919166%5D%2C%5B38.25290886154963%2C21.763935759263404%5D%2C%5B38.25146813817506%2C21.758421137528785%5D%5D
const _points = [
  '38.253094215699576 21.756382658677467 0 0',
  '38.25021274773806 21.756382658677467 0 0',
  '38.25007793942195 21.763892843919166 0 0',
  '38.25290886154963 21.763935759263404 0 0',
  '38.25146813817506 21.758421137528785 0 0',
];

double _decimalAnswer(Scenario scenario, String xPath) =>
    double.parse(scenario.answerOf(xPath)!.displayText);

void main() {
  test('area_isComputedForGeoshape', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Geoshape area'),
          model([
            mainInstance([
              t('data id="geoshape-area"', [
                tText('polygon', '${_points.join('; ')};'),
                t('area'),
              ]),
            ]),
            bind('/data/polygon')..type('geoshape'),
            bind('/data/area')
              ..type('decimal')
              ..calculate('area(/data/polygon)'),
          ]),
        ]),
        body([input('/data/polygon')]),
      ),
    );

    expect(_decimalAnswer(scenario, '/data/area'), closeTo(151452, 0.5));
  });

  test('area_isComputedForGeopointNodeset', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Geopoint nodeset area'),
          model([
            mainInstance([
              t('data id="geopoint-area"', [
                for (final point in _points)
                  t('location', [tText('point', point)]),
                t('area'),
              ]),
            ]),
            bind('/data/location/point')..type('geopoint'),
            bind('/data/area')
              ..type('decimal')
              ..calculate('area(/data/location/point)'),
          ]),
        ]),
        body([
          repeat('/data/location', [input('/data/location/point')]),
        ]),
      ),
    );

    expect(_decimalAnswer(scenario, '/data/area'), closeTo(151452, 0.5));
  });

  test('area_isComputedForString', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('String area'),
          model([
            mainInstance([
              t('data id="string-area"', [
                for (final (i, point) in _points.indexed)
                  tText('point${i + 1}', point),
                t('concat'),
                t('area'),
              ]),
            ]),
            for (var i = 1; i <= 5; i++)
              bind('/data/point$i')..type('geopoint'),
            bind('/data/concat')
              ..type('string')
              ..calculate(
                "concat(/data/point1, ';', /data/point2, ';', /data/point3, "
                "';', /data/point4, ';', /data/point5)",
              ),
            bind('/data/area')
              ..type('decimal')
              ..calculate('area(/data/concat)'),
          ]),
        ]),
        body([input('/data/point1')]),
      ),
    );

    expect(_decimalAnswer(scenario, '/data/area'), closeTo(151452, 0.5));
  });

  test('area_whenShapeHasFewerThanThreePoints_isZero', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Geoshape area'),
          model([
            mainInstance([
              t('data id="geoshape-area"', [
                tText('polygon1', '${_points[0]};'),
                tText('polygon2', '${_points[0]}; ${_points[1]};'),
                t('area1'),
                t('area2'),
              ]),
            ]),
            bind('/data/polygon1')..type('geoshape'),
            bind('/data/polygon2')..type('geoshape'),
            bind('/data/area1')
              ..type('decimal')
              ..calculate('area(/data/polygon1)'),
            bind('/data/area2')
              ..type('decimal')
              ..calculate('area(/data/polygon2)'),
          ]),
        ]),
        body([input('/data/polygon1'), input('/data/polygon2')]),
      ),
    );

    expect(_decimalAnswer(scenario, '/data/area1'), 0.0);
    expect(_decimalAnswer(scenario, '/data/area2'), 0.0);
  });
}
