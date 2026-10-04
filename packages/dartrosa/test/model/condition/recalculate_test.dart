// Port of JavaRosa v6.0.0 RecalculateTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_index.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';

void main() {
  late FormDef formDef;

  setUp(() async {
    formDef = await parseForm('calculate-now.xml');
    formDef.initialize(newInstance: true);
  });

  test('testComputedConstraintText', () {
    final nowNoteField = FormIndex(
      0,
      instanceIndex: 0,
      reference: formDef.mainInstance.root.getChild('now_note', 0)!.ref,
    );
    final actualQuestionText = FormEntryPrompt(
      formDef,
      nowNoteField,
    ).questionText();
    expect(actualQuestionText, '2018-01-01T10:20:30.400');
  });
}
