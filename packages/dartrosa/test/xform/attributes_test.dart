// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (AttributesTestCase), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

// Port of JavaRosa v6.0.0 AttributesTestCase. JavaRosa reads the attributes
// through FormEntryPrompt (Phase 4); here they are read from the parsed
// form directly.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

void main() {
  test('bind attributes', () async {
    final form = await parseForm('form_with_bind_attributes.xml');
    final text = form.mainInstance.resolveReference(getRef('/data/text'))!;
    expect(text.bindAttributes[0].name, 'requiredMsg');
    expect(text.bindAttributes[0].attributeValue, 'Custom required message');
    expect(text.bindAttributes[1].name, 'saveIncomplete');
    expect(text.bindAttributes[1].attributeValue, 'true()');
    final image = form.mainInstance.resolveReference(getRef('/data/image'))!;
    expect(image.bindAttributes[0].name, 'max-pixels');
    expect(image.bindAttributes[0].attributeValue, '1500');
  });

  test('additional attributes', () async {
    final form = await parseForm('form_with_additional_attributes.xml');
    final group = form.childAt(0)!;
    expect(
      group.additionalAttribute(null, 'intent'),
      "org.mycompany.myapp(my_text='Some text',uuid=/myform/meta/instanceID)",
    );
    final text = group.childAt(0)!;
    expect(text.additionalAttribute(null, 'rows'), '5');
    expect(text.additionalAttribute(null, 'autoplay'), 'audio');
    expect(text.additionalAttribute(null, 'playColor'), 'red');
    expect(
      group.childAt(1)!.additionalAttribute(null, 'accuracyThreshold'),
      '4',
    );
    expect(
      group.childAt(2)!.additionalAttribute(null, 'query'),
      "instance('counties')/root/item[state= /new_cascading_select/state ]",
    );
  });
}
