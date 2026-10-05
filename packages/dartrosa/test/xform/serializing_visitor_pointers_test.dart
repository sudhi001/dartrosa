// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports): attachments (pointer answers) in the XML,
// SMS and compact serializers, and the SMS serializer's legacy
// `delimeter`/prefix/tag attributes. Expectations were captured from
// JavaRosa 6.0.0 (jshell, XFormSerializingVisitor / SMSSerializingVisitor
// with BasicDataPointer answers on the same instance).
import 'dart:convert';

import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/xform/compact_serializing_visitor.dart';
import 'package:dartrosa/src/xform/sms_serializing_visitor.dart';
import 'package:dartrosa/src/xform/xform_parser.dart' show namespaceOdk;
import 'package:dartrosa/src/xform/xform_serializing_visitor.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

final class FilePointer implements DataPointer {
  const FilePointer(this.displayText);

  @override
  final String displayText;

  @override
  String toString() => displayText;
}

TreeElement leaf(String name, AnswerValue? value, [String? tag]) {
  final e = TreeElement(name, 0)..value = value;
  if (tag != null) e.setAttribute(null, 'tag', tag);
  return e;
}

/// `/data` with a photo (one attachment), a name and an empty node, using
/// the misspelled `delimeter` attribute JavaRosa also accepts.
FormInstance buildInstance() => FormInstance(
  TreeElement('data', 0)
    ..addChild(leaf('photo', const PointerValue(FilePointer('a.jpg')), 'p'))
    ..addChild(leaf('name', const StringValue('Ann Lee'), 'n'))
    ..addChild(leaf('empty', null))
    ..setAttribute(null, 'delimeter', '#')
    ..setAttribute(null, 'prefix', 'PRE'),
);

void addFiles(FormInstance instance) => instance.root.addChild(
  leaf(
    'files',
    MultiPointerValue(const [FilePointer('b.jpg'), FilePointer('c.jpg')]),
  ),
);

void main() {
  test('XML: attachments are collected, several become <data> children', () {
    final instance = buildInstance();
    final visitor = XFormSerializingVisitor();
    expect(
      utf8.decode(visitor.serializeInstance(instance)),
      "<?xml version='1.0' encoding='UTF-8' ?><data delimeter=\"#\" "
      'prefix="PRE"><photo tag="p">a.jpg</photo><name tag="n">Ann Lee</name>'
      '<empty /></data>',
    );
    expect(visitor.dataPointers.map((p) => '$p'), ['a.jpg']);

    addFiles(instance);
    expect(
      visitor.serializeInstanceToString(instance),
      endsWith(
        '<empty /><files><data>b.jpg</data><data>c.jpg</data></files></data>',
      ),
    );
    expect(visitor.dataPointers.map((p) => '$p'), ['a.jpg', 'b.jpg', 'c.jpg']);
  });

  test('XML: serializing from a sub-node', () {
    expect(
      XFormSerializingVisitor().serializeInstanceToString(
        buildInstance(),
        root: getRef('/data/name'),
      ),
      "<?xml version='1.0' encoding='UTF-8' ?><name tag=\"n\">Ann Lee</name>",
    );
  });

  test('SMS: tags, delimiter, prefix and attachments', () {
    final instance = buildInstance();
    final visitor = SMSSerializingVisitor();
    final root = getRef('/data');
    expect(
      visitor.serializeInstanceToString(instance, root: root),
      'PREp#a.jpg#n#Ann Lee#',
    );
    expect(visitor.dataPointers.map((p) => '$p'), ['a.jpg']);
    // Java's getBytes("UTF-16BE"): two bytes a char.
    expect(visitor.serializeInstance(instance, root: root), hasLength(42));
    // The payload is getBytes("UTF-16"), with a byte order mark.
    expect(
      visitor.createSerializedPayload(instance, root: root),
      hasLength(44),
    );
  });

  test('SMS: several attachments can not be sent', () {
    final instance = buildInstance();
    addFiles(instance);
    expect(
      () => SMSSerializingVisitor().serializeInstanceToString(
        instance,
        root: getRef('/data'),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          startsWith("Can't handle serialized output for"),
        ),
      ),
    );
  });

  test('compact: odk tags, escaped delimiters and attachments', () {
    TreeElement tagged(String name, AnswerValue value, String tag) =>
        leaf(name, value)..setAttribute(namespaceOdk, 'tag', tag);
    final instance = FormInstance(
      TreeElement('data', 0)
        ..addChild(
          tagged('photo', const PointerValue(FilePointer('a.jpg')), 'p'),
        )
        ..addChild(tagged('name', const StringValue('Ann#Lee'), 'n'))
        ..setAttribute(namespaceOdk, 'delimiter', '#')
        ..setAttribute(namespaceOdk, 'prefix', 'PRE'),
    );
    expect(
      CompactSerializingVisitor().serializeInstanceToString(instance),
      r'PRE#p#a.jpg#n#Ann\#Lee#',
    );
    // Java's getBytes("UTF-16"): a byte order mark and two bytes a char.
    expect(
      CompactSerializingVisitor().serializeInstance(instance),
      hasLength(46),
    );
    instance.root.addChild(
      tagged(
        'files',
        MultiPointerValue(const [FilePointer('b.jpg'), FilePointer('c.jpg')]),
        'f',
      ),
    );
    expect(
      () => CompactSerializingVisitor().serializeInstanceToString(instance),
      throwsStateError,
    );
  });
}
