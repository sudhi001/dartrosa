// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (BindAttributeProcessorTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 BindAttributeProcessorTest.
import 'package:dartrosa/src/model/data_binding.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

final class RecordingBindAttributeProcessor implements BindAttributeProcessor {
  RecordingBindAttributeProcessor(this.bindAttributes);

  @override
  final Set<(String, String)> bindAttributes;

  bool processCalled = false;

  @override
  void processBindAttribute(String name, String value, DataBinding binding) {
    processCalled = true;
  }
}

String formXml() => html(
  head([
    title('Form'),
    model([
      mainInstance([
        t('data id="form"', [t('name')]),
      ]),
      bind('/data/name')
        ..type('string')
        ..withAttribute('notBlah', 'name', 'value'),
    ]),
  ]),
  body([input('/data/name')]),
  additionalNamespaces: const {'blah': 'blah', 'notBlah': 'notBlah'},
).asXml();

void main() {
  test('does not process attribute with incorrect namespace', () async {
    final processor = RecordingBindAttributeProcessor({('blah', 'name')});
    await (XFormParser()..addProcessor(processor)).parse(formXml());
    expect(processor.processCalled, isFalse);
  });

  test('does not remove attribute with incorrect namespace', () async {
    final processor = RecordingBindAttributeProcessor({('blah', 'name')});
    final form = await (XFormParser()..addProcessor(processor)).parse(
      formXml(),
    );
    final question = form.mainInstance.resolveReference(getRef('/data/name'))!;
    expect(question.bindAttributes, hasLength(1));
  });

  test('processes and removes attribute with matching namespace', () async {
    final processor = RecordingBindAttributeProcessor({('notBlah', 'name')});
    final form = await (XFormParser()..addProcessor(processor)).parse(
      formXml(),
    );
    expect(processor.processCalled, isTrue);
    final question = form.mainInstance.resolveReference(getRef('/data/name'))!;
    expect(question.bindAttributes, isEmpty);
  });
}
