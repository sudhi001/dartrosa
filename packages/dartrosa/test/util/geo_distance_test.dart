// Port of JavaRosa v6.0.0 GeoDistanceTest.
import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/util/geo_utils.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

const ninetyDegreesOnEquatorKm = earthEquatorialCircumferenceMeters / 4;

// http://www.mapdevelopers.com/area_finder.php?&points=%5B%5B38.253094215699576%2C21.756382658677467%5D%2C%5B38.25021274773806%2C21.756382658677467%5D%2C%5B38.25007793942195%2C21.763892843919166%5D%2C%5B38.25290886154963%2C21.763935759263404%5D%2C%5B38.25146813817506%2C21.758421137528785%5D%5D
const _points = [
  '38.253094215699576 21.756382658677467 0 0',
  '38.25021274773806 21.756382658677467 0 0',
  '38.25007793942195 21.763892843919166 0 0',
  '38.25290886154963 21.763935759263404 0 0',
  '38.25146813817506 21.758421137528785 0 0',
];

double _distance(Scenario scenario) =>
    double.parse(scenario.answerOf('/data/distance')!.displayText);

/// A form with geopoints `/data/point<n>` for each n in [points] and a
/// decimal `/data/distance` calculated by [calculate].
XFormsElement _pointsForm(
  String formTitle,
  Iterable<int> points,
  String calculate, {
  bool concat = false,
}) => html(
  head([
    title(formTitle),
    model([
      mainInstance([
        t('data id="string-distance"', [
          for (final i in points) tText('point$i', _points[i - 1]),
          if (concat) t('concat'),
          t('distance'),
        ]),
      ]),
      for (final i in points) bind('/data/point$i')..type('geopoint'),
      if (concat)
        bind('/data/concat')
          ..type('string')
          ..calculate(
            "concat(/data/point1, ';', /data/point2, ';', /data/point3, "
            "';', /data/point4, ';', /data/point5)",
          ),
      bind('/data/distance')
        ..type('decimal')
        ..calculate(calculate),
    ]),
  ]),
  body([input('/data/point${points.first}')]),
);

XFormsElement _singleValueForm(
  String formTitle,
  String id,
  String name,
  String type,
  String value,
) => html(
  head([
    title(formTitle),
    model([
      mainInstance([
        t('data id="$id"', [tText(name, value), t('distance')]),
      ]),
      bind('/data/$name')..type(type),
      bind('/data/distance')
        ..type('decimal')
        ..calculate('distance(/data/$name)'),
    ]),
  ]),
  body([input('/data/$name')]),
);

void main() {
  test('distance_isComputedForGeopointNodeset', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Geopoint nodeset distance'),
          model([
            mainInstance([
              t('data id="geopoint-distance"', [
                t('location', [tText('point', '0 1 0 0')]),
                t('location', [tText('point', '0 91 0 0')]),
                t('distance'),
              ]),
            ]),
            bind('/data/location/point')..type('geopoint'),
            bind('/data/distance')
              ..type('decimal')
              ..calculate('distance(/data/location/point)'),
          ]),
        ]),
        body([
          repeat('/data/location', [input('/data/location/point')]),
        ]),
      ),
    );

    expect(_distance(scenario), closeTo(ninetyDegreesOnEquatorKm, 1e-7));
  });

  test('distance_isComputedForGeotrace', () async {
    final scenario = await Scenario.init(
      _singleValueForm(
        'Geotrace distance',
        'geotrace-distance',
        'line',
        'geotrace',
        '0 1 0 0; 0 91 0 0;',
      ),
    );

    expect(_distance(scenario), closeTo(ninetyDegreesOnEquatorKm, 1e-7));
  });

  test('distance_isComputedForGeoshape', () async {
    final scenario = await Scenario.init(
      _singleValueForm(
        'Geoshape distance',
        'geoshape-distance',
        'polygon',
        'geoshape',
        '0 1 0 0; 0 91 0 0; 0 1 0 0;',
      ),
    );

    expect(_distance(scenario), closeTo(ninetyDegreesOnEquatorKm * 2, 1e-7));
  });

  test('distance_isComputedForString', () async {
    final scenario = await Scenario.init(
      _pointsForm(
        'String distance',
        [1, 2, 3, 4, 5],
        'distance(/data/concat)',
        concat: true,
      ),
    );

    expect(_distance(scenario), closeTo(1801, 0.5));
  });

  test('distance_isComputedForInlineString', () async {
    final scenario = await Scenario.init(
      _pointsForm(
        'String distance',
        [1, 2, 3, 4, 5],
        "distance(concat(/data/point1, ';', /data/point2, ';', /data/point3, "
            "';', /data/point4, ';', /data/point5))",
      ),
    );

    expect(_distance(scenario), closeTo(1801, 0.5));
  });

  test('distance_throwsForNonPoint', () async {
    await expectLater(
      Scenario.init(
        html(
          head([
            title('String distance'),
            model([
              mainInstance([
                t('data id="string-distance"', [t('distance')]),
              ]),
              bind('/data/distance')
                ..type('decimal')
                ..calculate("distance('foo')"),
            ]),
          ]),
          body([input('distance')]),
        ),
      ),
      throwsA(
        isA<TriggerableEvaluationException>()
            .having((e) => e.cause, 'cause', isA<XPathTypeMismatchException>())
            .having(
              (e) => e.message,
              'message',
              contains(
                "The function 'distance' received a value that does not "
                'represent GPS coordinates',
              ),
            ),
      ),
    );
  });

  test('distance_isComputedForMultiplePathArguments', () async {
    final scenario = await Scenario.init(
      _pointsForm(
        'Multi parameter distance',
        [1, 2, 3, 4, 5],
        'distance(/data/point1, /data/point2, /data/point3, /data/point4, '
            '/data/point5)',
      ),
    );

    expect(_distance(scenario), closeTo(1801, 0.5));
  });

  test('distance_isComputedForMixedPathAndStringArguments', () async {
    final scenario = await Scenario.init(
      _pointsForm(
        'Multi parameter distance',
        [2, 3, 5],
        "distance('${_points[0]}', /data/point2, /data/point3, "
            "'${_points[3]}', /data/point5)",
      ),
    );

    expect(_distance(scenario), closeTo(1801, 0.5));
  });

  test('distance_whenTraceHasFewerThanTwoPoints_isZero', () async {
    final scenario = await Scenario.init(
      _singleValueForm(
        'Geotrace distance',
        'geotrace-distance',
        'line',
        'geotrace',
        '0 1 0 0;',
      ),
    );

    expect(_distance(scenario), 0.0);
  });
}
