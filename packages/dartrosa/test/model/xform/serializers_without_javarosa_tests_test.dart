// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests for SMSSerializingVisitor and DataModelSerializer, which
// have no JavaRosa tests (expected output follows the JavaRosa sources).
import 'package:dartrosa/src/xform/data_model_serializer.dart';
import 'package:dartrosa/src/xform/sms_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

Future<Scenario> _scenario() => Scenario.init(
  html(
    head([
      title('Serializers'),
      model([
        mainInstance([
          t('data id="x" prefix="P" delimiter=";"', [
            tText('a foo="bar" tag="A"', '1'),
            tText('b tag="B"', '2'),
            t('g', [tText('c', 'x&y')]),
          ]),
        ]),
        bind('/data/b')..relevant('false()'),
      ]),
    ]),
    body([input('/data/a'), input('/data/b'), input('/data/g/c')]),
  ),
);

void main() {
  test(
    'DataModelSerializer skips non-relevant nodes and root attributes',
    () async {
      final scenario = await _scenario();
      expect(
        const DataModelSerializer().serialize(scenario.formDef.mainInstance),
        '<data><a foo="bar" tag="A">1</a><g><c>x&amp;y</c></g></data>',
      );
    },
  );

  test(
    'SMSSerializingVisitor writes tagged answers of the root children',
    () async {
      final scenario = await _scenario();
      expect(
        SMSSerializingVisitor().serializeInstanceToString(
          scenario.formDef.mainInstance,
          root: getRef('/data'),
        ),
        'PA;1;',
      );
    },
  );

  test(
    'SMSSerializingVisitor fails for the default root, as in JavaRosa',
    () async {
      final scenario = await _scenario();
      expect(
        () => SMSSerializingVisitor().serializeInstanceToString(
          scenario.formDef.mainInstance,
        ),
        throwsStateError,
      );
    },
  );
}
