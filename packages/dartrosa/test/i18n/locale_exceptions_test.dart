// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports): locale exceptions carry JavaRosa 6.0.0's
// message and missing-key details and print just the message.
import 'package:dartrosa/src/i18n/locale_exceptions.dart';
import 'package:test/test.dart';

void main() {
  test('locale exceptions print their message', () {
    expect('${const UnregisteredLocaleException('no locale')}', 'no locale');
    expect('${const LocaleTextException('bad text')}', 'bad text');
    const missing = NoLocalizedTextException('missing', 'a;b', 'fr');
    expect('$missing', 'missing');
    expect(missing.missingKeyNames, 'a;b');
    expect(missing.localeMissingKey, 'fr');
  });
}
