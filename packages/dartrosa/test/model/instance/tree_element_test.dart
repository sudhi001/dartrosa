// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (TreeElementTests), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 TreeElementTests.
@TestOn('vm')
library;

import 'package:dartrosa/src/xform/instance_loading.dart';
import 'package:dartrosa/src/xform/instance_structure.dart';
import 'package:dartrosa/src/xform/kdom.dart';
import 'package:test/test.dart';

import '../../support/form_parse_init.dart';
import '../../support/forms.dart';

void main() {
  test('testPopulate_withNodesAttributes', () async {
    // Given
    final formParseInit = await FormParseInit.load(
      'populate-nodes-attributes.xml',
    );

    final formEntryController = formParseInit.formEntryController;

    final formInstanceAsString = formFile(
      'populate-nodes-attributes-instance.xml',
    ).readAsStringSync();
    final savedRoot = restoreDataModel(
      parseKDocument(formInstanceAsString),
    ).root;
    final formDef = formEntryController.model.form;
    final dataRootNode = formDef.mainInstance.root.deepCopy(
      includeTemplates: true,
    );

    // When
    dataRootNode.populate(savedRoot, formDef);

    // Then
    expect(dataRootNode.numChildren, 2);
    final freeText1Question = dataRootNode.childAt(0);
    final regularGroup = dataRootNode.childAt(1);

    expect(regularGroup.numChildren, 1);
    final freeText2Question = regularGroup.childAt(0);

    expect(freeText1Question.name, 'free_text_1');
    expect(freeText1Question.attributeCount, 1);
    var customAttr1 = freeText1Question.getAttribute(null, 'custom_attr_1');
    expect(customAttr1, isNotNull);
    expect(customAttr1!.name, 'custom_attr_1');
    expect(customAttr1.namespace, '');
    expect(customAttr1.attributeValue, 'xyz1');

    expect(regularGroup.name, 'regular_group');
    expect(regularGroup.attributeCount, 1);
    customAttr1 = regularGroup.getAttribute(null, 'custom_attr_1');
    expect(customAttr1, isNotNull);
    expect(customAttr1!.name, 'custom_attr_1');
    expect(customAttr1.namespace, 'custom_name_space');
    expect(customAttr1.attributeValue, 'xyz2');

    expect(freeText2Question.name, 'free_text_2');
    expect(freeText1Question.attributeCount, 1);
    final customAttr2 = freeText2Question.getAttribute(null, 'custom_attr_2');
    expect(customAttr2, isNotNull);
    expect(customAttr2!.name, 'custom_attr_2');
    expect(customAttr2.namespace, '');
    expect(customAttr2.attributeValue, 'xyz3');
  });
}
