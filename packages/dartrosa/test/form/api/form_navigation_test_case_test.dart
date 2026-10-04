// Port of JavaRosa v6.0.0 FormNavigationTestCase.
@TestOn('vm')
library;

import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:test/test.dart';

import '../../support/form_parse_init.dart';

/// Expected indices when increasing indexes until the end of the form.
/// An index of -1 indicates the start or end of a form.
const _data = <String, List<String>>{
  'repeatGroupWithTwoQuestions.xml': [
    '-1, ', '0_0, ', '0_0, 0, ', '0_0, 1, ', '0_1, ', '0_1, 0, ', //
    '0_1, 1, ', '0_2, ', '0_2, 0, ', '0_2, 1, ', '0_3, ', '-1, ',
  ],
  'repeatGroupWithQuestionAndRegularGroupInside.xml': [
    '-1, ', '0_0, ', '0_0, 0, ', '0_0, 1, ', '0_0, 1, 0, ', '0_0, 1, 1, ', //
    '0_1, ', '0_1, 0, ', '0_1, 1, ', '0_1, 1, 0, ', '0_1, 1, 1, ', '0_2, ',
    '0_2, 0, ', '0_2, 1, ', '0_2, 1, 0, ', '0_2, 1, 1, ', '0_3, ', '-1, ',
  ],
  'twoNestedRegularGroups.xml': [
    '-1, ', '0, ', '0, 0, ', '0, 0, 0, ', '0, 0, 1, ', '-1, ', //
  ],
  'twoNestedRepeatGroups.xml': [
    '-1, ', '0_0, ', '0_0, 0_0, ', '0_0, 0_0, 0, ', '0_0, 0_0, 1, ', //
    '0_0, 0_1, ', '0_0, 0_1, 0, ', '0_0, 0_1, 1, ', '0_0, 0_2, ', '0_1, ',
    '-1, ',
  ],
  'simpleFormWithThreeQuestions.xml': ['-1, ', '0, ', '1, ', '2, ', '-1, '],
};

void main() {
  // For each form, simulate increasing the index until the end of the
  // form and then decreasing until the beginning of the form.
  // Verify the expected indices before and after each operation.
  Future<void> testIndices(
    String formName,
    List<String> expectedIndices,
  ) async {
    final fpi = await FormParseInit.load(formName);
    final formEntryController = fpi.formEntryController;
    final formEntryModel = fpi.formEntryModel;

    var repeatCount = 0;
    for (var i = 0; i < expectedIndices.length - 1; i++) {
      // navigate forwards; check the current index
      expect(formEntryModel.formIndex.toString(), expectedIndices[i]);
      if (repeatCount < 3 &&
          formEntryController.model.event() == FormEntryEvent.promptNewRepeat) {
        formEntryController.newRepeat();
        repeatCount++;
      }
      formEntryModel.setQuestionIndex(
        formEntryModel.incrementIndex(formEntryModel.formIndex),
      );
      // check the index again after increasing the index
      expect(formEntryModel.formIndex.toString(), expectedIndices[i + 1]);
    }

    for (var i = expectedIndices.length - 1; i > 0; i--) {
      // navigate backwards; check the current index
      expect(formEntryModel.formIndex.toString(), expectedIndices[i]);
      formEntryModel.setQuestionIndex(
        formEntryModel.decrementIndex(formEntryModel.formIndex),
      );
      // check the index again after decreasing the index
      expect(formEntryModel.formIndex.toString(), expectedIndices[i - 1]);
    }
  }

  for (final MapEntry(key: formName, value: expected) in _data.entries) {
    group(formName, () {
      test('formNavigationTestCase', () => testIndices(formName, expected));
      test('testIndices', () => testIndices(formName, expected));
    });
  }
}
