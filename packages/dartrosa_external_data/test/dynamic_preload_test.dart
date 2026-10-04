// Ports of Collect's DynamicPreloadParseProcessorTest, DynamicPreloadExtraTest
// and ExternalDataUseCasesTest (mocks become real expressions and questions;
// the media directory becomes a ResourceResolver).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

QuestionDef createQuestion(String appearance) =>
    QuestionDef()..appearance = appearance;

MapResourceResolver resolverFor(Map<String, String> files) =>
    MapResourceResolver({
      for (final MapEntry(:key, :value) in files.entries)
        'jr://file/$key': utf8.encode(value),
    });

void main() {
  group('DynamicPreloadParseProcessorTest', () {
    late DynamicPreloadParseProcessor processor;

    setUp(() => processor = DynamicPreloadParseProcessor());

    test(
      'DynamicPreloadExtra is null when xpath does not contain pulldata',
      () {
        final formDef = FormDef();
        processor
          ..processXPath(parseXPath("concat('a', /data/b)"))
          ..processFormDef(formDef);
        expect(formDef.extras.get<DynamicPreloadExtra>(), isNull);
      },
    );

    test(
      'DynamicPreloadExtra is not null when xpath does contain pulldata',
      () {
        final formDef = FormDef();
        processor
          ..processXPath(
            parseXPath("concat(pulldata('fruits.CSV', 'a', 'b', 'c'), 'x')"),
          )
          ..processFormDef(formDef);
        final extra = formDef.extras.get<DynamicPreloadExtra>();
        expect(extra, isA<DynamicPreloadExtra>());
        expect(extra!.referencedDataSets, {'fruits'});
      },
    );

    test(
      'DynamicPreloadExtra is null when question appearance does not contain '
      'search',
      () {
        final formDef = FormDef();
        processor
          ..processQuestion(createQuestion('minimal'))
          ..processFormDef(formDef);
        expect(formDef.extras.get<DynamicPreloadExtra>(), isNull);
      },
    );

    test(
      'DynamicPreloadExtra is not null when question appearance does contain '
      'search',
      () {
        final formDef = FormDef();
        processor
          ..processQuestion(createQuestion("search('fruits')"))
          ..processFormDef(formDef);
        final extra = formDef.extras.get<DynamicPreloadExtra>();
        expect(extra, isA<DynamicPreloadExtra>());
        expect(extra!.referencedDataSets, {'fruits'});
      },
    );

    test(
      'collects data sets from nested expressions of a parsed form',
      () async {
        final parser = XFormParser()..addProcessor(processor);
        final form = await parser.parse(r"""
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>Pull</h:title><model>
<instance><data id="pull"><a/><b/></data></instance>
<bind nodeset="/data/a" calculate="if(true(), /data/b[. = pulldata('one', 'x', 'y', 'z')], -pulldata(/data/b, 'x', 'y', 'z'))"/>
</model></h:head>
<h:body><select1 ref="/data/b" appearance="search('Two.csv')"><label>B</label>
<item><label>l</label><value>v</value></item></select1></h:body></h:html>
""");
        expect(form.extras.get<DynamicPreloadExtra>()?.referencedDataSets, {
          'one',
          'two',
        });
      },
    );
  });

  // Collect's DynamicPreloadExtraTest (`can be externalized`) has no
  // counterpart: DartRosa doesn't serialize FormDefs with Externalizable;
  // its codec re-parses the form, re-running the processor. Instead:
  test('parsing a pulldata form with a saved instance marks it', () async {
    final form =
        await (XFormParser()..addProcessor(DynamicPreloadParseProcessor()))
            .parse(
              forms['pull_data.xml']!,
              instanceXml:
                  '<data id="pull_data"><fruit>x</fruit><note_country/>'
                  '<meta><instanceID/></meta></data>',
            );
    expect(form.extras.get<DynamicPreloadExtra>()?.referencedDataSets, {
      'fruits',
    });
  });

  group('ExternalDataUseCasesTest', () {
    final mediaDir = resolverFor({'items.csv': 'name_key,name\nmango,Mango'});

    test(
      "create() does nothing if the form doesn't use dynamic preload",
      () async {
        final repository = InMemoryExternalDataRepository();
        await ExternalDataUseCases.create(
          FormDef(),
          mediaDir,
          repository: repository,
          mediaFiles: ['items.csv'],
        );
        expect(repository.table('items'), isNull);
      },
    );

    test('create() does not create a db file if the FormDef does not have a '
        'DynamicPreloadExtra', () async {
      final repository = InMemoryExternalDataRepository();
      await ExternalDataUseCases.create(
        FormDef(),
        mediaDir,
        repository: repository,
        mediaFiles: ['items.csv'],
      );
      expect(repository.table('items'), isNull);
    });

    test(
      'create() creates a db file if the FormDef has a DynamicPreloadExtra',
      () async {
        final form = FormDef()..extras.put(DynamicPreloadExtra());
        final repository = InMemoryExternalDataRepository();
        final manager = await ExternalDataUseCases.create(
          form,
          mediaDir,
          repository: repository,
          mediaFiles: ['items.csv'],
        );
        expect(repository.table('items')!.rowCount, 1);
        expect(manager.getDatabase('ITEMS'), isNotNull);
        expect(manager.hasMediaFile('items.csv'), isTrue);
      },
    );

    test('create() leaves original CSV in place', () async {
      final form = FormDef()..extras.put(DynamicPreloadExtra());
      await ExternalDataUseCases.create(
        form,
        mediaDir,
        repository: InMemoryExternalDataRepository(),
        mediaFiles: ['items.csv'],
      );
      expect(await mediaDir.read('jr://file/items.csv'), isNotEmpty);
    });

    test(
      'create() skips itemsets.csv, other files and missing files',
      () async {
        final form = FormDef()..extras.put(DynamicPreloadExtra());
        final repository = InMemoryExternalDataRepository();
        await ExternalDataUseCases.create(
          form,
          resolverFor({'ItemSets.CSV': 'a\n1', 'notes.txt': 'a\n1'}),
          repository: repository,
          mediaFiles: ['ItemSets.CSV', 'notes.txt', 'missing.csv'],
        );
        expect(repository.table('itemsets'), isNull);
        expect(repository.table('notes'), isNull);
        expect(repository.table('missing'), isNull);
      },
    );

    test(
      'create() tries the referenced data sets without a media list',
      () async {
        final form = FormDef()..extras.put(DynamicPreloadExtra(['items']));
        final repository = InMemoryExternalDataRepository();
        final manager = await ExternalDataUseCases.create(
          form,
          mediaDir,
          repository: repository,
        );
        expect(manager.getDatabase('items'), isNotNull);
      },
    );

    test('create() fails when cancelled', () async {
      final form = FormDef()..extras.put(DynamicPreloadExtra());
      expect(
        ExternalDataUseCases.create(
          form,
          mediaDir,
          repository: InMemoryExternalDataRepository(),
          mediaFiles: ['items.csv'],
          isCancelled: () => true,
        ),
        throwsA(isA<ExternalDataImportCancelledException>()),
      );
    });
  });
}
