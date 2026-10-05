// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormIndexSerializationTest), Copyright (C) 2009
//  JavaRosa and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 FormIndexSerializationTest.
//
// JavaRosa round trips FormIndex through Java serialization; DartRosa
// round trips it through FormIndex.toPathString / FormIndex.parse.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:test/test.dart';

import '../support/form_parse_init.dart';

FormIndex _roundTrip(FormIndex index) => FormIndex.parse(index.toPathString());

// Fails if expected FormIndex is not equal to actual FormIndex.
void _assertFormIndex(FormIndex expected, FormIndex actual) {
  expect(actual, expected);
  expect(actual.reference, expected.reference);
}

void main() {
  test('testBeginningOfForm', () {
    final formIndexToSerialize = FormIndex.beginningOfForm();
    _assertFormIndex(formIndexToSerialize, _roundTrip(formIndexToSerialize));
  });

  test('testEndOfForm', () {
    final formIndexToSerialize = FormIndex.endOfForm();
    _assertFormIndex(formIndexToSerialize, _roundTrip(formIndexToSerialize));
  });

  test('testLocalAndInstanceNullReference', () {
    final formIndexToSerialize = FormIndex(1, instanceIndex: 2);
    _assertFormIndex(formIndexToSerialize, _roundTrip(formIndexToSerialize));
  });

  test('testLocalAndInstanceNonNullReference', () {
    const treeReference = TreeReference.root();
    final formIndexToSerialize = FormIndex(
      1,
      instanceIndex: 2,
      reference: treeReference,
    );
    _assertFormIndex(formIndexToSerialize, _roundTrip(formIndexToSerialize));
  });

  test('testOnFormController', () async {
    final formParseInit = await FormParseInit.load(
      'formindex-serialization.xml',
    );
    final formEntryController = formParseInit.formEntryController;

    var formIndex = formEntryController.model.formIndex;
    _assertFormIndex(formIndex, _roundTrip(formIndex));

    do {
      formIndex = formEntryController.model.incrementIndex(formIndex);
      _assertFormIndex(formIndex, _roundTrip(formIndex));
    } while (!formIndex.isEndOfFormIndex);
  });
}
