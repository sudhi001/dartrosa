// search() appearances: the engine-level assertions of Collect's
// instrumented DynamicPreLoadedDataSelects, ExternalSelectsTest and
// SearchAppearancesTest, plus DartRosa tests of ExternalDataHandlerSearch
// and populateExternalChoices.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_external_data/testing.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

List<String?> labels(List<SelectChoice> choices) => [
  for (final c in choices) c.labelInnerText,
];

List<String> values(List<SelectChoice> choices) => [
  for (final c in choices) c.value,
];

const _searchForm = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
<h:head><h:title>Search</h:title><model>
<itext><translation lang="en">
<text id="c"><value>label,color</value><value form="image">jr://images/img</value></text>
</translation></itext>
<instance><data id="search"><q/><type/><s/><m/><r/></data></instance>
<bind nodeset="/data/s" type="select1"/>
<bind nodeset="/data/m" type="select"/>
<bind nodeset="/data/r" type="odk:rank"/>
</model></h:head>
<h:body>
<input ref="/data/q"><label>Q</label></input>
<input ref="/data/type"><label>Type</label></input>
<select1 ref="/data/s" appearance="search('produce', 'startsWith', 'name label', /data/q, 'type', /data/type)"><label>S</label>
<item><label ref="jr:itext('c')"/><value>name</value></item>
<item><label>None</label><value>0</value></item>
</select1>
<select ref="/data/m" appearance="search('produce')"><label>M</label>
<item><label>label</label><value>name</value></item>
</select>
<odk:rank xmlns:odk="http://www.opendatakit.org/xforms" ref="/data/r" appearance="search('produce')"><label>R</label>
<item><label>label</label><value>name</value></item>
</odk:rank>
</h:body></h:html>
''';

const _produce = '''
name,label,color,type,img,sortby
banana,Banana,yellow,fruit,banana.png,3
apple,Apple,red,fruit,,1
avocado,Avocado,green,fruit,avocado.png,2
artichoke,Artichoke,green,vegetable,,4
apple,Apple again,red,fruit,,5
''';

void main() {
  group('DynamicPreLoadedDataSelects', () {
    test('withoutFilterAndWithFilter_displaysMatchingChoices', () async {
      final scenario = await externalDataScenario(
        forms['external-csv-search.xml']!,
        media: {
          'external-csv-search-produce.csv':
              media['external-csv-search-produce.csv']!,
        },
      );
      expect(
        labels(
          externalChoicesOf(scenario, '/external-csv-search/multi_produce'),
        ),
        ['Artichoke', 'Apple', 'Banana', 'Blueberry', 'Cherimoya', 'Carrot'],
      );

      scenario.answer('/external-csv-search/produce_search', 'A');
      expect(
        labels(externalChoicesOf(scenario, '/external-csv-search/produce')),
        ['Artichoke', 'Apple', 'Banana', 'Cherimoya', 'Carrot'],
      );
    });

    test('displayErrorWhenFilesAreMissing', () async {
      final scenario = await externalDataScenario(
        forms['simple-search-external-csv.xml']!,
      );
      expect(
        () => externalChoicesOf(scenario, '/simple-search-external-csv/fruit1'),
        throwsA(
          isA<ExternalDataFileMissingException>().having(
            (e) => '$e',
            'message',
            'File: jr://file/simple-search-external-csv-fruits.csv is '
                'missing.',
          ),
        ),
      );
    });

    test('displayWarningWhenQueryIsBad', () async {
      final scenario = await externalDataScenario(
        forms['external-csv-search-broken.xml']!,
        media: {
          'external-csv-search-produce.csv':
              media['external-csv-search-produce.csv']!,
        },
      );
      scenario.answer('/external-csv-search/produce_search', 'blah');
      expect(
        () => externalChoicesOf(scenario, '/external-csv-search/produce'),
        throwsA(
          isA<ExternalDataException>().having(
            (e) => e.message,
            'message',
            'no such column: c_wat (code 1 SQLITE_ERROR): , while compiling: '
                'SELECT c_name, c_label FROM externalData WHERE c_wat LIKE ? ',
          ),
        ),
      );
    });
  });

  group('ExternalSelectsTest', () {
    Future<Scenario> dynamicAndStatic() => externalDataScenario(
      forms['dynamic_and_static_choices.xml']!,
      media: {'fruits.csv': media['fruits.csv']!},
    );

    test('dynamicChoicesCanBeMixedWithNumericInternalOnes', () async {
      final choices = externalChoicesOf(
        await dynamicAndStatic(),
        '/data/fruits',
      );
      expect(labels(choices), [
        'Mango',
        'Oranges',
        'Strawberries',
        'None of the above',
      ]);
      expect(values(choices), ['mango', 'oranges', 'strawberries', '0']);
      expect(choices.first, isA<ExternalSelectChoice>());
    });

    test(
      'missingFileMessage_shouldBeDisplayedIfDynamicChoicesUsedButTheConfigurationRowIsMissing',
      () async {
        final scenario = await dynamicAndStatic();
        expect(
          () => externalChoicesOf(scenario, '/data/numbers'),
          throwsA(
            isA<ExternalDataFileMissingException>().having(
              (e) => e.path,
              'path',
              'jr://file/numbers.csv',
            ),
          ),
        );
      },
    );

    test(
      'a missing configuration row with the file present is an error',
      () async {
        final scenario = await externalDataScenario(
          forms['dynamic_and_static_choices.xml']!,
          media: {'fruits.csv': media['fruits.csv']!, 'numbers.csv': 'n\n1'},
        );
        expect(
          () => externalChoicesOf(scenario, '/data/numbers'),
          throwsA(
            isA<ExternalDataException>().having(
              (e) => e.message,
              'message',
              'jr://file/numbers.csv',
            ),
          ),
        );
      },
    );

    // https://github.com/getodk/collect/issues/6801 and #7387, without the
    // last-saved instance: answers survive reloading the instance.
    test('searchFunctionWorksWellWithLastSaved', () async {
      final files = {
        'fruits.csv': media['fruits.csv']!,
        'external_data.csv': media['external_data.csv']!,
      };
      final scenario = await externalDataScenario(
        forms['search-with-last-saved.xml']!,
        media: files,
        instanceXml:
            '<data id="search-with-last-saved"><group><fruit>mango</fruit>'
            '<number>one two</number></group><meta><instanceID>uuid:1'
            '</instanceID></meta></data>',
      );
      expect(scenario.answerOf('/data/group/fruit')!.displayText, 'mango');
      expect(labels(externalChoicesOf(scenario, '/data/group/number')), [
        'One',
        'Two',
        'Three',
      ]);
      scenario.answer('/data/group/fruit', 'strawberries');
      expect(
        scenario.answerOf('/data/group/fruit')!.displayText,
        'strawberries',
      );
    });
  });

  group('SearchAppearancesTest', () {
    late Scenario scenario;

    setUp(() async {
      scenario = await externalDataScenario(
        forms['different-search-appearances.xml']!,
        media: {'fruits.csv': media['fruits.csv']!},
      );
    });

    for (final ref in ['fruit1', 'fruit2', 'fruit3']) {
      test('searchFunctionFetchesChoicesFromCSVFile ($ref)', () {
        expect(
          labels(
            externalChoicesOf(scenario, '/different-search-appearances/$ref'),
          ),
          ['Mango', 'Oranges', 'Strawberries'],
        );
      });
    }

    test('static selects with a search appearance keep their choices', () {
      expect(
        labels(
          externalChoicesOf(scenario, '/different-search-appearances/animal2'),
        ),
        ['Wolf', 'Warthog', 'Raccoon', 'Rabbit'],
      );
    });
  });

  group('ExternalDataHandlerSearch', () {
    late Scenario scenario;

    setUp(() async {
      scenario = await externalDataScenario(
        _searchForm,
        media: {'produce.csv': _produce},
      );
    });

    test('builds labels from several columns, with images', () {
      scenario.answer('/data/type', 'fruit');
      final choices = externalChoicesOf(scenario, '/data/s');
      expect(labels(choices), [
        'Apple (color: red)',
        'Avocado (color: green)',
        'Banana (color: yellow)',
        'None',
      ]);
      expect(
        [for (final c in choices.whereType<ExternalSelectChoice>()) c.image],
        [null, 'jr://images/avocado.png', 'jr://images/banana.png'],
      );
      expect([for (final c in choices) c.index], [0, 1, 2, 1]);
    });

    test('an empty filter value matches no rows', () {
      expect(values(externalChoicesOf(scenario, '/data/s')), ['0']);
    });

    test('searches columns with startsWith and filters', () {
      scenario
        ..answer('/data/q', 'A')
        ..answer('/data/type', 'FRUIT');
      expect(values(externalChoicesOf(scenario, '/data/s')), [
        'apple',
        'avocado',
        '0',
      ]);
    });

    test('dedupes values and falls back to the value as label', () {
      final choices = externalChoicesOf(scenario, '/data/m');
      expect(values(choices), ['apple', 'avocado', 'banana', 'artichoke']);
      expect(labels(choices).first, 'Apple');
    });

    test('attaches the current answer to its choice', () {
      scenario.answer('/data/m', ['banana', 'apple']);
      final prompt = FormEntryPrompt(
        scenario.formDef,
        scenario.indexOf('/data/m')!,
      );
      loadSelectChoices(prompt);
      expect(prompt.answerText, 'Banana Apple ');
    });

    test('search types', () {
      expect(
        ExternalDataSearchType.getByKeyword(
          ' STARTSWITH ',
          ExternalDataSearchType.contains,
        ),
        ExternalDataSearchType.starts,
      );
      expect(
        ExternalDataSearchType.getByKeyword(
          'nope',
          ExternalDataSearchType.contains,
        ),
        ExternalDataSearchType.contains,
      );
      expect(ExternalDataSearchType.matches.constructLikeArguments('a', 2), [
        'a',
        'a',
      ]);
      expect(ExternalDataSearchType.ends.singleLikeArgument('a'), '%a');
    });

    test('wrong argument counts are rejected', () {
      expect(
        () => ExternalDataHandlerSearch(
          ExternalDataManager(),
          null,
          'v',
          null,
        ).eval(['a', 'b'], EvaluationContext(null)),
        throwsA(isA<ExternalDataException>()),
      );
    });
  });

  group('ExternalAnswerResolver', () {
    const instance =
        '<data id="search"><q/><type/><s>banana</s><m>banana apple</m>'
        '<r>apple</r></data>';

    test('keeps saved answers of search() selects', () async {
      final scenario = await externalDataScenario(
        _searchForm,
        media: {'produce.csv': _produce},
        instanceXml: instance,
      );
      expect(scenario.answerOf('/data/s'), isA<SelectOneValue>());
      expect(scenario.answerOf('/data/s')!.displayText, 'banana');
      expect(scenario.answerOf('/data/m'), isA<SelectMultiValue>());
      expect(scenario.answerOf('/data/m')!.displayText, 'banana, apple');
      expect(scenario.answerOf('/data/r')!.displayText, 'apple');
    });

    // Collect wraps the saved value as soon as it meets the configuration
    // row, so a static choice listed after it isn't used.
    test('wraps the answer at the first configuration row', () async {
      final scenario = await externalDataScenario(
        _searchForm,
        media: {'produce.csv': _produce},
        instanceXml: '<data id="search"><q/><type/><s>0</s><m/><r/></data>',
      );
      final answer = scenario.answerOf('/data/s')! as SelectOneValue;
      expect(answer.selection.choice!.labelInnerText, '0');
      expect(answer.selection.index, 0);
    });

    test('the default resolver drops them', () async {
      final form = await XFormParser().parse(
        _searchForm,
        instanceXml: instance,
      );
      expect(form.mainInstance.root.getChild('s', 0)!.value, isNull);
    });
  });
}
