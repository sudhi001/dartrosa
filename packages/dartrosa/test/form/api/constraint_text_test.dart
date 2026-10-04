// Port of JavaRosa v6.0.0 ConstraintTextTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:test/test.dart';

import '../../support/form_parse_init.dart';

void main() {
  test('checkConstraintTexts', () async {
    final fpi = await FormParseInit.load('constraint-message-error.xml');
    final formEntryModel = fpi.formEntryModel;
    final formDef = fpi.formDef;
    formDef.localizer!.locale = 'English';

    for (final expectedText in [
      'Your message',
      'Message',
      'Your message',
      'Message',
    ]) {
      formEntryModel.setQuestionIndex(
        formEntryModel.incrementIndex(formEntryModel.formIndex),
      );
      final formEntryPrompt = FormEntryPrompt(
        formDef,
        formEntryModel.formIndex,
      );
      expect(formEntryPrompt.constraintText(), expectedText);
    }
  });
}
