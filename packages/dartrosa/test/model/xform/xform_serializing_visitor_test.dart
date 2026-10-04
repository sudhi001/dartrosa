// Port of JavaRosa v6.0.0 XFormSerializingVisitorTest.
import 'dart:convert';

import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('serializeInstance_preservesUnicodeCharacters', () async {
    final formDef = html(
      head([
        title('Some form'),
        model([
          mainInstance([
            t('data id="some-form"', [t('text')]),
          ]),
          bind('/data/text')..type('string'),
        ]),
      ]),
      body([input('/data/text')]),
    );

    final scenario = await Scenario.init(formDef);
    scenario
      ..next()
      ..answerCurrent('\u{1F9DB}');

    final visitor = XFormSerializingVisitor();
    final serializedInstance = visitor.serializeInstance(
      scenario.formDef.mainInstance,
    );
    expect(utf8.decode(serializedInstance), contains('<text>\u{1F9DB}</text>'));
  });
}
