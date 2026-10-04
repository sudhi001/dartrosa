// Port of org.odk.collect.entities.javarosa.EntityFormParseProcessorTest.
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

import '../support/entity_xforms_element.dart';

XFormsElement _form({
  String? version,
  String entity = 'entity dataset="people"',
  bool withEntity = true,
  Map<String, String> namespaces = entitiesNs,
  String versionPrefix = 'entities',
  void Function(BindBuilderXFormsElement)? configureBind,
}) {
  final nameBind = bind('/data/name')..type('string');
  (configureBind ?? (b) => b.withSaveTo('name'))(nameBind);
  return html(
    additionalNamespaces: namespaces,
    head([
      title('Create entity form'),
      model(
        [
          mainInstance([
            t('data id="create-entity-form"', [
              t('name'),
              withEntity ? t('meta', [t(entity)]) : t('meta'),
            ]),
          ]),
          nameBind,
        ],
        attributes: {'$versionPrefix:entities-version': ?version},
      ),
    ]),
    body([input('/data/name')]),
  );
}

Future<FormDef> _parse(XFormsElement form, [EntityFormParseProcessor? p]) =>
    (XFormParser()..addProcessor(p ?? EntityFormParseProcessor())).parse(
      form.asXml(),
    );

void main() {
  test('when version is missing parses without error', () async {
    await _parse(
      _form(withEntity: false, namespaces: const {}, configureBind: (_) {}),
    );
  });

  test('when version is missing and there is an entity element throws '
      'exception', () async {
    await expectLater(
      _parse(_form()),
      throwsA(
        isA<MissingModelAttributeException>()
            .having((e) => e.namespace, 'namespace', entitiesNamespace)
            .having((e) => e.name, 'name', 'entities-version'),
      ),
    );
  });

  test('when version is not recognized throws exception', () async {
    await expectLater(
      _parse(_form(version: 'somethingElse')),
      throwsA(isA<UnrecognizedEntityVersionException>()),
    );
  });

  test('when version is new patch parses correctly', () async {
    expect(await _parse(_form(version: '2022.1.12')), isNotNull);
  });

  test('when version is new version with updates parses correctly', () async {
    expect(
      await _parse(
        _form(
          version: '2023.1.0',
          entity: 'entity dataset="people" update="1" id="17"',
        ),
      ),
      isNotNull,
    );
  });

  test('saveTos with incorrect namespace are ignored', () async {
    final formDef = await _parse(
      _form(
        version: '2024.1.0',
        namespaces: const {'correct': entitiesNamespace, 'incorrect': 'blah'},
        versionPrefix: 'correct',
        configureBind: (b) => b.withAttribute('incorrect', 'saveto', 'name'),
      ),
    );
    final extra = formDef.extras[EntityFormExtra]! as EntityFormExtra;
    expect(extra.saveTos, isEmpty);
  });

  // Added: DartRosa processors can be reused across parses.
  test('state does not leak into the next parse', () async {
    final processor = EntityFormParseProcessor();
    await _parse(_form(version: '2024.1.0'), processor);
    await expectLater(
      _parse(_form(), processor),
      throwsA(isA<MissingModelAttributeException>()),
    );
  });

  test('saveTos record the field and its entity group', () async {
    final formDef = await _parse(_form(version: '2024.1.0'));
    final extra = formDef.extras[EntityFormExtra]! as EntityFormExtra;
    expect(extra.saveTos, hasLength(1));
    expect(extra.saveTos.single.value, 'name');
    expect(extra.saveTos.single.reference.toString(), '/data/name');
    expect(extra.saveTos.single.entityGroupReference.toString(), '/data');
  });

  test('forms using versions without local entities get no extra', () async {
    final formDef = await _parse(_form(version: '2023.1.0'));
    expect(formDef.extras[EntityFormExtra], isNull);
  });
}
