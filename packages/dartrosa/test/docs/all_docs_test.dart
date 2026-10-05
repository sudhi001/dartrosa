// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Every Dart snippet of every guide (docs/*.md and docs/{guides,tutorials,
// cookbook}/*.md) must
// be in a doc test, so the guides can't rot.
@TestOn('vm')
library;

import 'package:test/test.dart';

import 'doc_snippets.dart';

void main() {
  final guides = guidesWithDartCode();

  test('the guides are found', () {
    expect(guides, contains('docs/GETTING_STARTED.md'));
    for (final folder in docFolders.skip(1)) {
      expect(guides.where((g) => g.startsWith('$folder/')), isNotEmpty);
    }
  });

  guides.forEach(expectSnippetsTested);
}
