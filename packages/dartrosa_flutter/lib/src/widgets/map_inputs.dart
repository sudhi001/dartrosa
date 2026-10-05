// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (GeoPolyUtils, MappableItem, MappableItemsParser),
//  Copyright University of Washington, Nafundi and contributors; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../localizations.dart';
import '../xform_scope.dart';
import 'common.dart';

/// A point of an ODK geometry: latitude, longitude, altitude, accuracy.
@immutable
class MapPoint {
  /// Creates a point.
  const MapPoint(
    this.latitude,
    this.longitude, [
    this.altitude = 0,
    this.accuracy = 0,
  ]);

  /// Degrees north.
  final double latitude;

  /// Degrees east.
  final double longitude;

  /// Meters.
  final double altitude;

  /// Meters.
  final double accuracy;

  @override
  bool operator ==(Object other) =>
      other is MapPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.altitude == altitude &&
      other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude, accuracy);

  @override
  String toString() => '$latitude $longitude $altitude $accuracy';
}

/// The points of an ODK geometry (`lat lon [alt [acc]]; ...`), or none if
/// any vertex is invalid. Port of ODK Collect's `GeoPolyUtils
/// .parseGeometry`.
List<MapPoint> parseGeometry(String? geometry) {
  final points = <MapPoint>[];
  for (final vertex in (geometry ?? '').split(';')) {
    if (vertex.isEmpty) return const [];
    final parts = vertex.trim().split(' ');
    final numbers = [for (final p in parts) double.tryParse(p)];
    if (numbers.contains(null)) return const [];
    double at(int i) => i < numbers.length ? numbers[i]! : 0;
    points.add(MapPoint(at(0), at(1), at(2), at(3)));
  }
  return points;
}

/// The kind of a [MapFeature].
enum MapFeatureKind {
  /// One point (a marker).
  point,

  /// An open line.
  line,

  /// A closed shape (first point = last point).
  polygon,
}

/// A choice with a geometry, for a select with the `map` appearance.
/// Port of ODK Collect's `MappableItem`.
@immutable
class MapFeature {
  /// Creates a feature.
  const MapFeature({
    required this.choice,
    required this.label,
    required this.kind,
    required this.points,
    this.properties = const [],
    this.markerColor,
    this.markerSymbol,
    this.strokeColor,
    this.strokeWidth,
    this.fillColor,
  });

  /// The choice.
  final SelectChoice choice;

  /// The choice's label.
  final String label;

  /// Point, line or polygon.
  final MapFeatureKind kind;

  /// The geometry.
  final List<MapPoint> points;

  /// The choice's other itemset columns, as `(name, value)`.
  final List<(String, String)> properties;

  /// `marker-color` (points).
  final String? markerColor;

  /// `marker-symbol` (points).
  final String? markerSymbol;

  /// `stroke` (lines and polygons).
  final String? strokeColor;

  /// `stroke-width` (lines and polygons).
  final String? strokeWidth;

  /// `fill` (polygons).
  final String? fillColor;
}

const _styleColumns = {
  'geometry', 'marker-color', 'marker-symbol', 'stroke', 'stroke-width', //
  'fill', '__version', '__trunkVersion', '__branchId',
};

/// The [choices] of [node] that have a valid `geometry` within the map's
/// bounds, as map features. Port of ODK Collect's `MappableItemsParser`.
List<MapFeature> mapFeatures(QuestionNode node, List<SelectChoice> choices) => [
  for (final choice in choices)
    ?() {
      final points = parseGeometry(choice.child('geometry'));
      if (points.isEmpty ||
          !points.every(
            (p) => p.latitude.abs() <= 90 && p.longitude.abs() <= 180,
          )) {
        return null;
      }
      final columns = choice.additionalChildren;
      String? column(String name) => columns
          .where((c) => c.$1 == name)
          .map((c) => c.$2)
          .where((v) => v.trim().isNotEmpty)
          .firstOrNull;
      return MapFeature(
        choice: choice,
        label: node.choiceLabel(choice) ?? choice.value,
        kind: points.length == 1
            ? MapFeatureKind.point
            : points.first == points.last
            ? MapFeatureKind.polygon
            : MapFeatureKind.line,
        points: points,
        properties: [
          for (final c in columns)
            if (!_styleColumns.contains(c.$1)) c,
        ],
        markerColor: column('marker-color'),
        markerSymbol: column('marker-symbol'),
        strokeColor: column('stroke'),
        strokeWidth: column('stroke-width'),
        fillColor: column('fill'),
      );
    }(),
];

/// A select one with the `map` appearance: a "Select place" button
/// opening the app's map (`XFormDelegates.selectFromMap`) and the
/// selected choice's label, like ODK Collect's `SelectOneFromMapWidget`.
class SelectFromMapInput extends StatelessWidget {
  /// Creates the input for [node].
  const SelectFromMapInput(this.node, {super.key});

  /// The select question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    final selected = selectedValues(node).firstOrNull;
    final choices = choicesOf(context, node);
    final choice = choices.where((c) => c.value == selected).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.map_outlined),
          label: Text(XFormLocalizations.of(context).selectPlace),
          onPressed: () async {
            final picked = await delegates.selectFromMap(
              context,
              node: node,
              features: mapFeatures(node, choices),
              selected: choice,
            );
            if (picked == null || !context.mounted || node.isReadonly) return;
            answerQuestion(
              context,
              node,
              SelectOneValue(Selection.ofChoice(picked)),
            );
          },
        ),
        if (choice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(node.choiceLabel(choice) ?? choice.value),
          ),
      ],
    );
  }
}

/// A geopoint (`maps`, `placement-map`), geotrace or geoshape captured
/// on the app's map (`XFormDelegates.geoFromMap`), like ODK Collect's
/// `GeoPointMapWidget`, `GeoTraceWidget` and `GeoShapeWidget`.
class GeoMapInput extends StatelessWidget {
  /// Creates the input for [node].
  const GeoMapInput(this.node, {super.key});

  /// The geo question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    final strings = XFormLocalizations.of(context);
    final value = node.value?.displayText;
    final hasValue = value != null && value.isNotEmpty;
    final hidden = Appearance.parse(node.appearance).has('hidden-answer');
    return AnswerWithActions(
      answer: hidden ? const SizedBox.shrink() : Text(value ?? '—'),
      actions: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.map_outlined),
          label: Text(strings.geoMapButton(node.dataType, hasValue: hasValue)),
          onPressed: () async {
            final result = await delegates.geoFromMap(context, node: node);
            if (result == null || !context.mounted || node.isReadonly) return;
            answerQuestion(
              context,
              node,
              result.isEmpty ? null : typedAnswer(node, result),
            );
          },
        ),
      ],
    );
  }
}
