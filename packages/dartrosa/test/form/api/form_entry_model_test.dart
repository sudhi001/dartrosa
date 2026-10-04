// Port of JavaRosa v6.0.0 FormEntryModelTest.
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('isIndexRelevant_respectsRelevanceOfOutermostGroup', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Nested relevance'),
          model([
            mainInstance([
              t('data id="nested_relevance"', [
                t('outer', [
                  t('inner', [t('q1')]),
                ]),
                tText('innerYesNo', 'no'),
                tText('outerYesNo', 'no'),
              ]),
            ]),
            bind('/data/outer')..relevant("/data/outerYesNo = 'yes'"),
            bind('/data/outer/inner')..relevant("/data/innerYesNo = 'yes'"),
          ]),
        ]),
        body([
          formGroup('/data/outer', [
            formGroup('/data/outer/inner', [input('/data/outer/inner/q1')]),
          ]),
          input('/data/outerYesNo'),
          input('/data/innerYesNo'),
        ]),
      ),
    );
    final formDef = scenario.formDef;
    final formEntryModel = FormEntryModel(formDef);

    final q1Index = scenario.indexOf('/data/outer/inner/q1');
    expect(formEntryModel.isIndexRelevant(q1Index), isFalse);

    scenario.answer('/data/innerYesNo', 'yes');
    expect(formEntryModel.isIndexRelevant(q1Index), isFalse);

    scenario.answer('/data/outerYesNo', 'yes');
    expect(formEntryModel.isIndexRelevant(q1Index), isTrue);
  });
}
