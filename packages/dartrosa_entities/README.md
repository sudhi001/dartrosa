# dartrosa_entities

[![pub package](https://img.shields.io/pub/v/dartrosa_entities.svg)](https://pub.dev/packages/dartrosa_entities)
[![pub points](https://img.shields.io/pub/points/dartrosa_entities)](https://pub.dev/packages/dartrosa_entities/score)
[![CI](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml/badge.svg)](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[ODK entities](https://getodk.github.io/xforms-spec/entities) for
[DartRosa](https://github.com/sudhi001/dartrosa): a port of ODK Collect's
entities module.

- Entity forms: `entities:create`, `update` and upsert, `entities:saveto`,
  entity labels and ids (`EntityFormParseProcessor`,
  `EntityFormFinalizationProcessor`).
- Local entity lists as secondary instances (`jr://file-csv/<list>.csv`)
  with fast predicate filtering (`LocalEntitiesInstanceProvider`,
  `LocalEntitiesFilterStrategy`) and `pulldata()` over them.
- Offline entity updates and server reconciliation
  (`LocalEntityUseCases`) over an `EntitiesRepository` you implement on
  your storage (`InMemEntitiesRepository` included).
- `withEntities` wires everything into a `DartRosaConfig`; with
  `dartrosa_external_data`'s `ExternalDataPlugin` in the config, entity
  lists answer `pulldata()` before CSV media, as in Collect.

## Install

```sh
dart pub add dartrosa_entities
```

## Example

```dart
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';

Future<void> main() async {
  final repository = InMemEntitiesRepository()
    ..save('people', [
      NewEntity('a1', 'Shiv', properties: const [('full_name', 'Shiv Roy')]),
    ]);
  final config = withEntities(
    const DartRosaConfig(),
    entitiesRepository: () => repository,
  );

  final definition = await FormDefinition.parse(entityFormXml, config: config);
  final session = definition.createSession();
  // ... answer questions ...
  if (session.finalize() is FinalizeSuccess) {
    print(formEntities(session)!.entities.map((e) => e.label));
    saveFormEntities(session, repository); // the new person joins 'people'
  }
}
```

See [example/example.dart](example/example.dart) for the complete program
with its form.

## Documentation

- [API reference](https://pub.dev/documentation/dartrosa_entities/latest/)
- [Documentation index](https://github.com/sudhi001/dartrosa/blob/main/docs/README.md)
- [Use CSV data and entities](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/external-data-and-entities.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect's entities
module (Apache-2.0); see
[the licensing notes](https://github.com/sudhi001/dartrosa/blob/main/docs/legal/README.md).
