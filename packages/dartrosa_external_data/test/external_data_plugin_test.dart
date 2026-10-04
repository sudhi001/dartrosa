// DartRosa tests of ExternalDataPlugin through the app API
// (DartRosaConfig.plugins, FormDefinition, FormSession).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

void main() {
  final resolver = MapResourceResolver({
    'jr://file/fruits.csv': utf8.encode(media['fruits.csv']!),
    'jr://file-csv/fruits.csv': utf8.encode(media['fruits.csv']!),
    'jr://file/external-csv-search-produce.csv': utf8.encode(
      media['external-csv-search-produce.csv']!,
    ),
  });

  test('pulldata works in sessions', () async {
    final definition = await FormDefinition.parse(
      forms['pull_data.xml']!,
      config: DartRosaConfig(
        resolver: resolver,
        plugins: [
          ExternalDataPlugin(listMedia: (_) => ['fruits.csv']),
        ],
      ),
    );
    definition.createSession();
    expect(
      definition.formDef.mainInstance.root
          .getChild('fruit', 0)!
          .value!
          .displayText,
      'Mango',
    );
  });

  test('search() choices and saved answers in sessions', () async {
    final repository = InMemoryExternalDataRepository();
    final definition = await FormDefinition.parse(
      forms['external-csv-search.xml']!,
      config: DartRosaConfig(
        resolver: resolver,
        plugins: [ExternalDataPlugin(repository: (_) => repository)],
      ),
    );
    expect(repository.table('external-csv-search-produce'), isNotNull);
    final session = definition.createSession(
      existingInstance:
          '<external-csv-search id="external-csv-search">'
          '<multi_produce>apple carrot</multi_produce><produce_search/>'
          '<produce>banana</produce><meta><instanceID/></meta>'
          '</external-csv-search>',
    );
    final node = session.root.children.whereType<QuestionNode>().firstWhere(
      (n) => n.ref!.lastName == 'produce',
    );
    expect(node.value, isA<SelectOneValue>());
    final prompt = FormEntryPrompt(definition.formDef, node.index);
    expect(values(loadSelectChoices(prompt)), contains('banana'));
    // As in Collect, the resolver's virtual choice (labelled with the
    // value) is already attached, so the CSV label isn't used.
    expect(prompt.answerText, 'banana');
  });

  test('import errors fail the form load', () async {
    expect(
      FormDefinition.parse(
        forms['pull_data.xml']!,
        config: DartRosaConfig(
          resolver: MapResourceResolver({
            'jr://file/fruits.csv': utf8.encode('a,A\n1,2'),
          }),
          plugins: [ExternalDataPlugin()],
        ),
      ),
      throwsA(
        isA<ExternalDataException>().having(
          (e) => e.message,
          'message',
          'Could not import data from fruits.csv. Reason: Columns [a, A] '
              'match!',
        ),
      ),
    );
  });

  test('cancelling fails the form load', () async {
    expect(
      FormDefinition.parse(
        forms['pull_data.xml']!,
        config: DartRosaConfig(
          resolver: resolver,
          plugins: [ExternalDataPlugin(isCancelled: () => true)],
        ),
      ),
      throwsA(isA<ExternalDataImportCancelledException>()),
    );
  });

  test('forms without external data import nothing', () async {
    final repository = InMemoryExternalDataRepository();
    final messages = <String>[];
    await FormDefinition.parse(
      forms['different-search-appearances.xml']!.replaceAll(
        "search('fruits')",
        'minimal',
      ),
      config: DartRosaConfig(
        resolver: resolver,
        plugins: [
          ExternalDataPlugin(
            repository: (_) => repository,
            listMedia: (_) => ['fruits.csv'],
            onProgress: messages.add,
          ),
        ],
      ),
    );
    expect(repository.table('fruits'), isNull);
    expect(messages, isEmpty);
  });
}

List<String> values(List<SelectChoice> choices) => [
  for (final c in choices) c.value,
];
