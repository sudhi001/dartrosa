# dartrosa_external_data

ODK Collect's external data ("dynamic preload") for
[DartRosa](https://github.com/sudhi001/dartrosa): `pulldata()` and
`search()` appearances over CSV form media. A port of Collect's
`dynamicpreload` package and the entities module's
`PullDataFunctionHandler`.

- Add an `ExternalDataPlugin` to `DartRosaConfig.plugins`: CSV media are
  imported when the form loads (into an `ExternalDataRepository`; in
  memory by default, or your own persistent one to import only changed
  files), `pulldata()` is registered, and saved instances are typed as
  Collect types them.
- Read the choices of selects with a `search()` appearance with
  `loadSelectChoices`; `dartrosa_flutter` does this for you.
- `PullDataInstanceAdapter` lets other sources (such as
  `dartrosa_entities`' local entity lists) answer `pulldata()` first.

## Install

Not on pub.dev yet; depend on it from Git, overriding its DartRosa
siblings to the same source:

```yaml
dependencies:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
  dartrosa_external_data:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa_external_data}
dependency_overrides:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
```

## Example

```dart
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';

Future<void> main() async {
  final config = DartRosaConfig(
    // Form media, read as jr://file/<name>.
    resolver: MapResourceResolver({
      'jr://file/fruits.csv': utf8.encode('name,price\nmango,1.5\n'),
    }),
    plugins: [ExternalDataPlugin(listMedia: (_) => ['fruits.csv'])],
  );
  // The form calculates pulldata('fruits', 'price', 'name', /data/fruit).
  final definition = await FormDefinition.parse(xform, config: config);
  final session = definition.createSession();
  final [fruit, price] = session.root.children.cast<QuestionNode>();
  session.answer(fruit.index, const StringValue('mango'));
  print(price.value?.displayText); // 1.5
}
```

See [example/example.dart](example/example.dart) for the complete program.

## Documentation

- [Documentation index](https://github.com/sudhi001/dartrosa/blob/main/docs/README.md)
- [Use CSV data and entities](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/external-data-and-entities.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect code
(Apache-2.0); see
[the licensing notes](https://github.com/sudhi001/dartrosa/blob/main/docs/legal/README.md).
