// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The two `AppDelegates` classes of the docs/widgets/ catalog (README and
// select-one pages), each in its own library so both names compile.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'widgets_catalog_readme.dart' as readme;
import 'widgets_catalog_select_one.dart' as select_one;

void main() {
  test('the catalog AppDelegates compile and declare their features', () {
    expect(readme.AppDelegates().canLocate, isTrue);
    expect(
      select_one.AppDelegates(
        Directory.systemTemp,
      ).image('jr://images/mango.png'),
      isNotNull,
    );
  });
}
