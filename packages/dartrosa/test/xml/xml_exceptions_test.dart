// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports): the messages of the XML structure exceptions
// follow JavaRosa 6.0.0's InvalidStructureException constructors and
// readableInvalidStructureException (KXmlParser positions become strings),
// and UnfullfilledRequirementsException's version strings.
import 'package:dartrosa/src/xml/xml_exceptions.dart';
import 'package:test/test.dart';

void main() {
  test('invalid structure messages', () {
    expect('${const InvalidStructureException('bad')}', 'bad');
    expect(
      '${InvalidStructureException.atPosition('bad', 'START_TAG @1:2')}',
      'Invalid XML Structure(START_TAG @1:2): bad',
    );
    expect(
      InvalidStructureException.inDocument('bad', 'f.xml', '@3:4').message,
      'Invalid XML Structure in document f.xml(@3:4): bad',
    );
    expect(
      InvalidStructureException.readable('bad', name: 'data').message,
      'bad. Source: <data>',
    );
    expect(
      InvalidStructureException.readable(
        'bad',
        name: 'data',
        prefix: 'h',
        namespace: 'urn:x',
      ).message,
      'bad. Source: <h:data> tag in namespace: urn:x',
    );
  });

  test('unfulfilled requirements', () {
    const plain = UnfullfilledRequirementsException('old', 2);
    expect('$plain', 'old');
    expect(plain.severity, 2);
    expect(plain.requirementCode, -1);
    expect(plain.isDuplicateException, isFalse);
    expect(plain.requiredVersionString, '-1.-1');
    const versioned = UnfullfilledRequirementsException(
      'version',
      1,
      requirementCode: 3,
      requiredMajor: 2,
      requiredMinor: 5,
      availableMajor: 1,
      availableMinor: 9,
    );
    expect(versioned.requiredVersionString, '2.5');
    expect(versioned.availableVersionString, '1.9');
  });
}
