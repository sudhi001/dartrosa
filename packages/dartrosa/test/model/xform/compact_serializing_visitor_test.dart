// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (CompactSerializingVisitorTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 CompactSerializingVisitorTest.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/xform/compact_serializing_visitor.dart';
import 'package:dartrosa/src/xform/xform_parser.dart' show namespaceOdk;
import 'package:test/test.dart';

import '../../support/form_parse_init.dart';

void main() {
  late String text;
  late FormInstance formInstance;

  setUp(() async {
    final formParser = await FormParseInit.load('sms_form.xml');
    final formEntryController = formParser.formEntryController;
    formInstance = formEntryController.model.form.mainInstance;

    final serializer = CompactSerializingVisitor();

    final payload = serializer.createSerializedPayload(formInstance);

    text = utf8.decode(payload).replaceAll(r'\', '').replaceAll(r'\\', r'\');
  });

  test('ensurePrefixIsPresent', () {
    final root = formInstance.root;
    final prefix = root.getAttributeValue(namespaceOdk, 'prefix');
    expect(text, contains(prefix));
  });

  test('SmsNotNull', () {
    expect(text, isNotNull);
  });

  test('ensureCorrectSerialization', () {
    expect(
      text,
      'FORM232;FN;John;LN;Doe;DOB;2015-08-05;CN;Mary Doe;CN;Sara Doe;CN;'
      'Jim Doe;PIC;test_image.jpg;',
      reason: 'Serialized form',
    );
  });

  /// Ensures that the answer for maiden_name, which doesn’t have the “tag”
  /// attribute, is not present
  test('ensureAnswerInNonTaggedElementNotPresent', () {
    expect(text.contains('Placeholder'), isFalse);
  });

  /// Ensures that “CTY”, which does have the “tag” attribute, but has no
  /// answer, is not present
  test('ensureTagWithNoAnswerNotPresent', () {
    expect(text.contains('CTY'), isFalse);
  });

  test('ensureThatFormWithNoSmsTagsIsEmpty', () async {
    final formParser = await FormParseInit.load('simple-form.xml');
    final formEntryController = formParser.formEntryController;
    formInstance = formEntryController.model.form.mainInstance;

    final serializer = CompactSerializingVisitor();

    final payload = serializer.createSerializedPayload(formInstance);

    expect(utf8.decode(payload), '');
  });
}
