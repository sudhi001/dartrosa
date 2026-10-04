// Added: the DartRosaConfig wiring (Collect's form-loading setup).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

import 'support/entity_xforms_element.dart';

const _shivId = '3d9c6b1e-5f1a-4b8e-9c2d-000000000001';

String _form() => html(
  additionalNamespaces: entitiesNs,
  head([
    title('Add person'),
    entityModel('2024.1.0', [
      mainInstance([
        t('data id="add-person"', [
          t('name'),
          t('count'),
          t('shiv'),
          t('meta', [entityNode('people', EntityAction.create)]),
        ]),
      ]),
      t('instance id="people" src="jr://file-csv/people.csv"'),
      bind('/data/name')
        ..type('string')
        ..withSaveTo('full_name'),
      bind('/data/count')
        ..type('string')
        ..calculate("count(instance('people')/root/item)"),
      bind('/data/shiv')
        ..type('string')
        ..calculate("instance('people')/root/item[name='$_shivId']/full_name"),
      entityIdBind(),
      entityIdSetValue(),
      entityLabelBind('/data/name'),
    ]),
  ]),
  body([input('/data/name')]),
).asXml();

String? _value(FormSession session, String name) =>
    RegExp('<$name>([^<]*)</$name>').firstMatch(session.saveDraft())?.group(1);

void main() {
  test(
    'withEntities supports entity lists, filters and entity creation',
    () async {
      final repository = InMemEntitiesRepository()
        ..save('people', [
          NewEntity(
            _shivId,
            'Shiv',
            properties: const [('full_name', 'Shiv Roy')],
          ),
        ]);

      var definition = await FormDefinition.parse(
        _form(),
        config: withEntities(
          const DartRosaConfig(),
          entitiesRepository: () => repository,
        ),
      );
      final session = definition.createSession();
      expect(_value(session, 'count'), '1');
      expect(_value(session, 'shiv'), 'Shiv Roy');

      session.navigator.next();
      session.answer(
        session.navigator.position,
        const StringValue('Kendall Roy'),
      );
      expect(session.finalize(), isA<FinalizeSuccess>());

      final entities = formEntities(session)!.entities;
      expect(entities, hasLength(1));
      expect(entities.single.label, 'Kendall Roy');
      expect(entities.single.properties, [('full_name', 'Kendall Roy')]);

      saveFormEntities(session, repository);
      expect(repository.getCount('people'), 2);

      definition = await FormDefinition.parse(
        _form(),
        config: withEntities(
          const DartRosaConfig(),
          entitiesRepository: () => repository,
        ),
      );
      expect(_value(definition.createSession(), 'count'), '2');
    },
  );

  test(
    'withEntities uses an attached file instead of a same-named list',
    () async {
      final repository = InMemEntitiesRepository()
        ..save('people', [NewEntity(_shivId, 'Shiv')]);
      final definition = await FormDefinition.parse(
        _form(),
        config: withEntities(
          DartRosaConfig(
            resolver: MapResourceResolver({
              'jr://file-csv/people.csv': Uint8List.fromList(
                utf8.encode('name,label,full_name\na,A,X\nb,B,Y\nc,C,Z\n'),
              ),
            }),
          ),
          entitiesRepository: () => repository,
          mediaFiles: InMemFormMediaFileRepository([
            'jr://file-csv/people.csv',
          ]),
        ),
      );
      expect(_value(definition.createSession(), 'count'), '3');
    },
  );

  test('withEntities keeps an existing pulldata handler as fallback', () {
    final config = withEntities(
      DartRosaConfig(functions: [_OtherPullData()]),
      entitiesRepository: InMemEntitiesRepository.new,
    );
    expect(config.functions.single, isA<PullDataFunctionHandler>());
    expect(config.parseProcessors.single, isA<EntityFormParseProcessor>());
    expect(
      config.finalizationProcessors.single,
      isA<EntityFormFinalizationProcessor>(),
    );
    expect(config.filterStrategies.single, isA<LocalEntitiesFilterStrategy>());
  });

  test('withEntities rejects a base external instance parser', () {
    expect(
      () => withEntities(
        DartRosaConfig(externalInstanceParser: ExternalInstanceParser()),
        entitiesRepository: InMemEntitiesRepository.new,
      ),
      throwsArgumentError,
    );
  });
}

final class _OtherPullData extends XPathFunctionHandler {
  @override
  String get name => 'pulldata';

  @override
  List<List<XPathArgType>> get prototypes => const [];

  @override
  Object eval(List<Object> args, EvaluationContext context) => '';
}
