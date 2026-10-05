// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (BufferedInputStreamTests), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 BufferedInputStreamTests.
import 'package:test/test.dart';

void main() {
  for (final name in ['testBuffered', 'testIndividual']) {
    test(
      name,
      () {},
      skip:
          'Externalizable binary format is not ported '
          '(FormDefCodec replaces it)',
    );
  }
}
