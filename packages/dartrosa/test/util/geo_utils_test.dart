// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (GeoUtilsTest), Copyright (C) 2012-14 Dobility, Inc.;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 GeoUtilsTest.
import 'package:dartrosa/src/util/geo_utils.dart';
import 'package:test/test.dart';

List<LatLong> points(List<List<double>> raw) => [
  for (final p in raw) (latitude: p[0], longitude: p[1]),
];

void checkAreaAndDistance(List<List<double>> raw, int area, int length) {
  expect(areaOfPolygon(points(raw)), closeTo(area, 0.5), reason: 'Area');
  expect(distance(points(raw)), closeTo(length, 0.5), reason: 'Distance');
}

const polygon = [
  [38.253094215699576, 21.756382658677467],
  [38.25021274773806, 21.756382658677467],
  [38.25007793942195, 21.763892843919166],
  [38.25290886154963, 21.763935759263404],
  [38.25146813817506, 21.758421137528785],
  [38.253094215699576, 21.756382658677467], // last point matches first
];

void main() {
  test('area and distance for path 1', () {
    checkAreaAndDistance(polygon.sublist(0, 5), 151452, 1801);
  });

  test('area and distance for path 2', () {
    checkAreaAndDistance(
      [
        [38.25304740874071, 21.75644703234866],
        [38.25308110946615, 21.763377860443143],
        [38.25078942453431, 21.763399318115262],
        [38.25090738066984, 21.756640151397733],
        [38.25197740258244, 21.75892539347842],
      ],
      122755,
      1685,
    );
  });

  test('area and distance for path 3', () {
    checkAreaAndDistance(
      [
        [38.252845204059824, 21.763313487426785],
        [38.25303055837213, 21.755867675201443],
        [38.25072202094234, 21.755803302185086],
        [38.25062091543717, 21.76294870700076],
        [38.25183417221606, 21.75692982997134],
      ],
      93912,
      2076,
    );
  });

  test('one degree around at the equator', () {
    expect(
      distance(
        points([
          [0, 0],
          [0, 1],
        ]),
      ),
      closeTo(earthEquatorialCircumferenceMeters / 360, 1e-6),
    );
  });

  test('ninety degrees around at the equator', () {
    expect(
      distance(
        points([
          [0, 0],
          [0, 90],
        ]),
      ),
      closeTo(earthEquatorialCircumferenceMeters / 4, 1e-6),
    );
  });

  test('one degree of longitude at latitude 90', () {
    expect(
      distance(
        points([
          [90, 0],
          [90, 1],
        ]),
      ),
      closeTo(0, 1e-6),
    );
  });

  test('points in and out of a polygon', () {
    bool inside(double lat, double lon) =>
        isPointInPolygon((latitude: lat, longitude: lon), points(polygon));
    expect(inside(38.25081280703969, 21.760299116099116), isTrue);
    expect(inside(38.251790, 21.756845), isTrue);
    expect(inside(38.252062644683356, 21.758894013612437), isFalse);
  });
}
