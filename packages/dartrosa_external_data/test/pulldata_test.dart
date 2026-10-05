// pulldata(): Collect's DynamicPreLoadedDataPullTest (instrumented; the
// engine-level assertions), DartRosa tests of ExternalDataHandlerPull, and
// a port of the entities module's PullDataFunctionHandlerTest.
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_external_data/testing.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

String pullForm(String calculate, {String type = 'string'}) => html(
  head([
    title('Pull data form'),
    model([
      mainInstance([
        t('data id="pull-data-form"', [t('question'), t('calculate')]),
      ]),
      bind('/data/question')..type('string'),
      bind('/data/calculate')
        ..type(type)
        ..calculate(calculate),
    ]),
  ]),
  body([input('/data/question'), input('/data/calculate')]),
).asXml();

void main() {
  group('DynamicPreLoadedDataPullTest', () {
    test('canUsePullDataFunctionToPullDataFromCSV', () async {
      final scenario = await externalDataScenario(
        forms['pull_data.xml']!,
        media: {'fruits.csv': media['fruits.csv']!},
      );
      expect(scenario.answerOf('/data/fruit')!.displayText, 'Mango');
      expect(
        FormEntryPrompt(
          scenario.formDef,
          scenario.indexOf('/data/note_country')!,
        ).longText,
        contains('The fruit Mango is pulled csv data.'),
      );
    });

    test('canUsePullDataFunctionToPullDataFromLocalEntities', () async {
      final scenario = await externalDataScenario(
        pullForm("pulldata('people', 'name', 'label', 'Logan Roy')"),
        instanceAdapter: InMemoryPullDataInstanceAdapter({
          'people': [
            {'name': 'logan', 'label': 'Logan Roy'},
          ],
        }),
      );
      expect(scenario.answerOf('/data/calculate')!.displayText, 'logan');
    });
  });

  group('ExternalDataHandlerPull', () {
    Future<Scenario> pull(
      String calculate, {
      Map<String, String>? files,
      bool listMedia = true,
    }) => externalDataScenario(
      pullForm(calculate),
      media: files ?? {'Fruits.csv': media['fruits.csv']!},
      listMedia: listMedia,
    );

    String? valueOf(Scenario s) => s.answerOf('/data/calculate')?.displayText;

    test('matches keys case-insensitively (COLLATE NOCASE)', () async {
      expect(
        valueOf(await pull("pulldata('fruits', 'name', 'name_key', 'MANGO')")),
        'Mango',
      );
    });

    test('normalizes the data set name (SCTO-545)', () async {
      expect(
        valueOf(
          await pull("pulldata('FRUITS.csv', 'name', 'name_key', 'oranges')"),
        ),
        'Oranges',
      );
    });

    test('reads the referenced CSV without a media list', () async {
      expect(
        valueOf(
          await pull(
            "pulldata('fruits', 'name', 'name_key', 'mango')",
            files: {'fruits.csv': media['fruits.csv']!},
            listMedia: false,
          ),
        ),
        'Mango',
      );
    });

    test('returns the first match', () async {
      expect(
        valueOf(
          await pull(
            "pulldata('d', 'v', 'k', 'x')",
            files: {'d.csv': 'k,v\ny,0\nx,1\nX,2'},
          ),
        ),
        '1',
      );
    });

    test('is empty when nothing matches', () async {
      expect(
        valueOf(await pull("pulldata('fruits', 'name', 'name_key', 'kiwi')")),
        isNull,
      );
    });

    test('is empty for unknown columns and data sets', () async {
      expect(
        valueOf(await pull("pulldata('fruits', 'wat', 'name_key', 'mango')")),
        isNull,
      );
      expect(
        valueOf(await pull("pulldata('veg', 'name', 'name_key', 'mango')")),
        isNull,
      );
    });

    test('is empty without 4 arguments', () async {
      expect(
        valueOf(await pull("pulldata('fruits', 'name', 'name_key')")),
        isNull,
      );
    });

    test('reads arguments from the form', () async {
      final scenario = await pull(
        "pulldata('fruits', 'name', 'name_key', /data/question)",
      );
      scenario.answer('/data/question', 'strawberries');
      expect(valueOf(scenario), 'Strawberries');
    });

    test('can read the generated sort column', () async {
      expect(
        valueOf(
          await pull("pulldata('fruits', 'sortby', 'name_key', 'oranges')"),
        ),
        '2.0',
      );
    });
  });

  group('PullDataFunctionHandlerTest', () {
    Future<Scenario> pull(
      String calculate,
      Map<String, List<Map<String, String>>> lists,
    ) => externalDataScenario(
      pullForm(calculate),
      instanceAdapter: InMemoryPullDataInstanceAdapter(lists),
    );

    test('returns empty string when there are no matching results', () async {
      final scenario = await pull(
        "pulldata('things', 'label', 'name', 'blah')",
        {'things': []},
      );
      expect(scenario.answerOf('/data/calculate'), isNull);
    });

    test('returns first match when there are multiple', () async {
      final scenario = await pull(
        "pulldata('things', 'label', 'property', 'value')",
        {
          'things': [
            {'name': 'one', 'label': 'One', 'property': 'value'},
            {'name': 'two', 'label': 'Two', 'property': 'value'},
          ],
        },
      );
      expect(scenario.answerOf('/data/calculate')!.displayText, 'One');
    });

    test('returns empty string when uses not existing property', () async {
      final scenario = await pull(
        "pulldata('things', 'label', 'property', 'value')",
        {
          'things': [
            {'name': 'one', 'label': 'One'},
          ],
        },
      );
      expect(scenario.answerOf('/data/calculate'), isNull);
    });

    test(
      'returns empty string when uses not existing property with no value',
      () async {
        final scenario = await pull(
          "pulldata('things', 'label', 'property', '')",
          {
            'things': [
              {'name': 'one', 'label': 'One'},
            ],
          },
        );
        expect(scenario.answerOf('/data/calculate'), isNull);
      },
    );

    test('falls back to CSV media for other instance ids', () async {
      final scenario = await externalDataScenario(
        pullForm("pulldata('fruits', 'name', 'name_key', 'mango')"),
        media: {'fruits.csv': media['fruits.csv']!},
        instanceAdapter: InMemoryPullDataInstanceAdapter({'things': []}),
      );
      expect(scenario.answerOf('/data/calculate')!.displayText, 'Mango');
    });
  });
}
