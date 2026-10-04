import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _places =
    '<instance id="places"><root>'
    '<item><name>p</name><label>Point</label><geometry>1 2 3 4</geometry>'
    '<marker-color>#f00</marker-color><info>x</info></item>'
    '<item><name>l</name><label>Line</label>'
    '<geometry>1 2;3 4</geometry><stroke>#0f0</stroke></item>'
    '<item><name>s</name><label>Shape</label>'
    '<geometry>1 2;3 4;5 6;1 2</geometry><fill> </fill></item>'
    '<item><name>bad</name><label>Bad</label><geometry>1 2;</geometry></item>'
    '<item><name>far</name><label>Far</label><geometry>91 0</geometry></item>'
    '<item><name>none</name><label>None</label></item>'
    '</root></instance>';

Future<FormSession> _select(String appearance) => formSession(
  '<q/>',
  _places,
  '<select1 ref="/data/q" appearance="$appearance"><label>Q</label>'
      '<itemset nodeset="instance(\'places\')/root/item">'
      '<value ref="name"/><label ref="label"/></itemset></select1>',
);

class _MapDelegates extends XFormDelegates {
  _MapDelegates({this.pick, this.geo});

  final String? pick;
  final String? geo;
  List<MapFeature>? features;
  QuestionNode? geoNode;

  @override
  bool get canShowMaps => true;

  @override
  Future<SelectChoice?> selectFromMap(
    BuildContext context, {
    required QuestionNode node,
    required List<MapFeature> features,
    SelectChoice? selected,
  }) async {
    this.features = features;
    return features.where((f) => f.choice.value == pick).firstOrNull?.choice;
  }

  @override
  Future<String?> geoFromMap(
    BuildContext context, {
    required QuestionNode node,
  }) async {
    geoNode = node;
    return geo;
  }
}

Future<void> _pump(
  WidgetTester tester,
  FormSession s, [
  XFormDelegates delegates = const NoDelegates(),
]) => tester.pumpWidget(
  app(XFormView(session: s, mode: XFormMode.scroll, delegates: delegates)),
);

void main() {
  test('parseGeometry', () {
    expect(parseGeometry('1.0 2.0 3 4'), [const MapPoint(1, 2, 3, 4)]);
    expect(parseGeometry('1 2; 5 6 7'), [
      const MapPoint(1, 2),
      const MapPoint(5, 6, 7),
    ]);
    expect(parseGeometry('blah'), isEmpty);
    expect(parseGeometry('1 2 3 4; blah'), isEmpty);
    expect(parseGeometry(''), isEmpty);
    expect(parseGeometry(null), isEmpty);
  });

  testWidgets('map select: features, pick on the map', (tester) async {
    final s = await _select('map');
    final delegates = _MapDelegates(pick: 'l');
    await _pump(tester, s, delegates);
    expect(find.byType(Radio<String>), findsNothing);
    await tester.tap(find.text('Select place'));
    await tester.pump();
    final features = delegates.features!;
    expect([for (final f in features) f.choice.value], ['p', 'l', 's']);
    expect(
      [for (final f in features) f.kind],
      [MapFeatureKind.point, MapFeatureKind.line, MapFeatureKind.polygon],
    );
    expect(features[0].markerColor, '#f00');
    expect(features[0].label, 'Point');
    expect(features[0].properties, [('name', 'p'), ('info', 'x')]);
    expect(features[1].strokeColor, '#0f0');
    expect(features[2].fillColor, isNull);
    expect(question(s, 0).value!.displayText, 'l');
    expect(find.text('Line'), findsOneWidget);
  });

  testWidgets('map select without maps: radio buttons', (tester) async {
    await _pump(tester, await _select('map'));
    expect(find.byType(Radio<String>), findsNWidgets(6));
    expect(find.text('Select place'), findsNothing);
  });

  Future<FormSession> geo(String type, String appearance) => formSession(
    '<g/>',
    '<bind nodeset="/data/g" type="$type"/>',
    '<input ref="/data/g" appearance="$appearance"><label>G</label></input>',
  );

  testWidgets('geopoint maps / placement-map use the map', (tester) async {
    for (final appearance in ['maps', 'placement-map']) {
      final s = await geo('geopoint', appearance);
      final delegates = _MapDelegates(geo: '1.5 2.5 0 0');
      await _pump(tester, s, delegates);
      await tester.tap(find.text('Get point'));
      await tester.pump();
      expect(delegates.geoNode!.dataType, DataType.geopoint);
      expect(question(s, 0).value!.displayText, '1.5 2.5 0.0 0.0');
      expect(find.text('Change point'), findsOneWidget);
    }
  });

  testWidgets('geotrace and geoshape always use the map', (tester) async {
    final s = await geo('geoshape', '');
    final delegates = _MapDelegates(geo: '1 2 0 0;3 4 0 0;5 6 0 0;1 2 0 0');
    await _pump(tester, s, delegates);
    await tester.tap(find.text('Get shape'));
    await tester.pump();
    expect(question(s, 0).value, isA<GeoShapeValue>());
    expect(find.text('View or change shape'), findsOneWidget);
  });

  testWidgets('plain geopoint keeps the location button', (tester) async {
    await _pump(tester, await geo('geopoint', ''), _MapDelegates());
    expect(find.text('Get point'), findsNothing);
    // Without delegates, maps falls back to typing the value.
    await _pump(tester, await geo('geopoint', 'maps'));
    expect(find.byType(TextField), findsOneWidget);
  });
}
