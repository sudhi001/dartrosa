// Every Dart snippet of every guide (docs/*.md and docs/guides/*.md) must
// be in a doc test, so the guides can't rot.
@TestOn('vm')
library;

import 'package:test/test.dart';

import 'doc_snippets.dart';

void main() {
  final guides = guidesWithDartCode();

  test('the guides are found', () {
    expect(guides, contains('docs/GETTING_STARTED.md'));
    expect(guides.where((g) => g.startsWith('docs/guides/')), isNotEmpty);
  });

  guides.forEach(expectSnippetsTested);
}
