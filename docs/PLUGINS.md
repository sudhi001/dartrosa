# Extending DartRosa

**Audience:** developers adding custom XPath functions, processors or
data sources, or combining the Collect-layer packages. **Type:**
reference with examples.

JavaRosa is extended through static registries
(`FormEntryController.addFunctionHandler`, `XFormParser.addProcessor`,
`ReferenceManager.instance()`, `PrototypeManager`, ...). DartRosa has the
same extension points, but they are fields of one immutable
`DartRosaConfig` passed to `FormDefinition.parse`, so two forms can be
loaded with different setups, and tests can run in parallel.

Every Dart snippet below is run by
`packages/dartrosa/test/docs/plugins_test.dart` and
`packages/dartrosa_collect/test/docs/plugins_test.dart`. Types come from
`package:dartrosa/dartrosa.dart` and, for the JavaRosa-level interfaces
(`FormDef`, `EvaluationContext`, the parser processors, ...),
`package:dartrosa/javarosa.dart`.

## Overview

| `DartRosaConfig` field | Type | JavaRosa equivalent |
|---|---|---|
| `resolver` | `ResourceResolver` | `ReferenceManager` roots (`jr://images`, `jr://file`, ...) |
| `functions` | `List<XPathFunctionHandler>` | `FormDef/FormEntryController.addFunctionHandler` (`IFunctionHandler`) |
| `filterStrategies` | `List<FilterStrategy>` | `FormDef.addFilterStrategy` |
| `parseProcessors` | `List<Object>` (processor interfaces below) | `XFormParser.addProcessor` |
| `finalizationProcessors` | `List<FormEntryFinalizationProcessor>` | `FormEntryController.addPostProcessor` |
| `preloadHandlers` | `List<PreloadHandler>` | `QuestionPreloader.addPreloadHandler` (`IPreloadHandler`) |
| `externalInstanceParser` | `ExternalInstanceParser` | `ExternalInstanceParser.addInstanceProvider` / `addFileInstanceParser` |
| `setGeopointAction` | `SetGeopointAction Function(TreeReference)` | `SetGeopointActionHandler` + a custom `SetGeopointAction` |
| `properties` | `PropertyManager` | `PropertyManager` (device id, username, ...) |
| `plugins` | `List<FormLoadPlugin>` | Collect's `IXFormParserFactory` wrapping + `FormLoaderTask` work |
| `lastSavedSrc` | `String` | The `src` Collect gives `jr://instance/last-saved` |

`copyWith` returns a config with some fields replaced; helpers that add
features (such as `withEntities`) use it so the rest of your config is
kept:

```dart
const base = DartRosaConfig();
final config = base.copyWith(
  functions: [...base.functions, GreetFunction()],
);
```

All of them together:

```dart
final filter = CountingFilterStrategy();
final config = DartRosaConfig(
  resolver: MapResourceResolver({
    'jr://file/motto.txt': bytes('Be kind'),
    'jr://file/last-saved.xml': bytes(
      '<data id="plugins"><name>Ada</name></data>',
    ),
  }),
  functions: [GreetFunction()],
  filterStrategies: [filter],
  parseProcessors: [QuestionCounter()],
  finalizationProcessors: [StampFinalization()],
  preloadHandlers: [AppPreloadHandler()],
  externalInstanceParser: ExternalInstanceParser()
    ..addInstanceProvider(StaffProvider()),
  properties: MapPropertyManager({'username': 'ada'}),
  plugins: [const MottoPlugin()],
  lastSavedSrc: 'jr://file/last-saved.xml',
);

final definition = await FormDefinition.parse(formXml, config: config);
final count = definition.formDef.extras.get<QuestionCount>()?.count; // 1
```

The sections below show each piece.

## Resources: `resolver`

`ResourceResolver` has one method, `Future<Uint8List> read(String uri)`,
which throws `ResourceNotFoundException` for missing files. It reads
secondary instances (`jr://file/x.xml`, `jr://file-csv/x.csv`,
`jr://file/x.geojson`), the last-saved instance and, through plugins,
CSV media. Media in labels (`jr://images/...`) are not read by the
engine; the renderer asks its delegates for them. `MapResourceResolver`
serves an in-memory map; implement the interface on your file system,
Flutter assets or download cache. A missing secondary instance becomes an
empty placeholder, and `XPathMissingInstanceException` is raised only when
the form references it, as in JavaRosa.

## XPath functions: `functions`

```dart
// greet('Ada') = 'Hello, Ada!'
final class GreetFunction extends XPathFunctionHandler {
  @override
  String get name => 'greet';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      'Hello, ${args.single}!';
}
```

Arguments are matched against `prototypes` in order and converted
(`XPathArgType.string`, `number` (a `double`), `boolean`, `date` (a
`DateTime`), `any`, or `XPathArgType.ofType<T>()`); set `rawArgs` to
receive the unconverted arguments when no prototype matches. `eval`
returns a `bool`, `double`, `String`, `DateTime` or `XPathNodeset`, never
`null`. As in JavaRosa, built-in functions are looked up first, then
custom handlers (the last registered for a name wins), then the
context's `fallbackFunctionHandler` (an `XPathFallbackFunctionHandler`);
otherwise the call raises `XPathUnhandledException`. Some built-ins with
a fixed arity fall through to custom handlers for other arities.

## Predicate filters: `filterStrategies`

A `FilterStrategy` filters the children of a nodeset by a predicate or
hands them to the next strategy. Yours are tried before the built-in
chain (JavaRosa's comparison and equality indexes, then raw evaluation).
`dartrosa_entities` uses one to answer `[name = 'x']` predicates from its
database instead of loading whole entity lists.

```dart
// Sees every predicate (e.g. to answer some from an index) and hands the
// rest to the next strategy.
final class CountingFilterStrategy implements FilterStrategy {
  int predicates = 0;

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    predicates++;
    return next();
  }
}
```

A strategy must give the same result as evaluating the predicate; the
conformance traces check the built-in ones against JavaRosa.

## Parser processors: `parseProcessors`

Each object is passed to `XFormParser.addProcessor` and registered for
every processor interface it implements:

- `BindAttributeProcessor`: bind attributes it declares, such as
  entities' `entities:saveto` (`bindAttributes` is a set of
  `(namespace, name)` pairs);
- `ModelAttributeProcessor`: `<model>` attributes, such as
  `entities:entities-version`;
- `QuestionProcessor`: every parsed `QuestionDef`;
- `FormDefProcessor`: the finished `FormDef`;
- `XPathProcessor`: every XPath expression in the form;
- `ExternalDataInstanceProcessor`: every external secondary instance.

Processors in `parseProcessors` are shared by every parse with that
config. One that keeps per-form state belongs in a `FormLoadPlugin`
(below), which creates fresh processors for each parse.

```dart
// A typed extra attached to the parsed form.
final class QuestionCount {
  QuestionCount(this.count);
  final int count;
}

// Counts the questions while parsing (one processor per parse, as it keeps
// state) and attaches the count to the form.
final class QuestionCounter implements QuestionProcessor, FormDefProcessor {
  int _count = 0;

  @override
  void processQuestion(QuestionDef question) => _count++;

  @override
  void processFormDef(FormDef form) => form.extras.put(QuestionCount(_count));
}
```

### Typed extras: `FormDef.extras`

`FormDef.extras` is an `Extras<Object>`: at most one object per runtime
type, stored with `put(extra)` and read with `get<T>()` (JavaRosa's
`Extras`, keyed by class name). Plugins use it to mark parsed forms, for
example `dartrosa_external_data`'s `DynamicPreloadExtra` or the entities
schema. A `FormSession` has its own `extras` map for per-session state
(finalization processors put their results there; `formEntities(session)`
reads the entities).

## Finalization: `finalizationProcessors`

Run by `FormSession.finalize()` after validation and before
serialization (JavaRosa's `FormEntryFinalizationProcessor`), for
example to compute entities or set `meta/deprecatedID`.

```dart
// Runs when a session is finalized.
final class StampFinalization implements FormEntryFinalizationProcessor {
  @override
  void processForm(FormEntryModel model) =>
      model.extras['finalizedBy'] = 'my-app';
}
```

`model.extras` is the session's `extras`; `model.form` is the `FormDef`,
whose main instance a processor may change before it is serialized.

## Preloads and device properties: `preloadHandlers`, `properties`

The built-in `jr:preload` handlers are `date`, `property`, `timestamp`
and `uid`. A handler with the same `preloadHandled` replaces one;
`handlePostProcess` runs again on finalization (e.g. `timestamp end`).

```dart
// jr:preload="app" jr:preloadParams="name"
final class AppPreloadHandler implements PreloadHandler {
  @override
  String get preloadHandled => 'app';

  @override
  AnswerValue? handlePreload(String? params) =>
      params == 'name' ? const StringValue('my-app') : null;

  @override
  bool handlePostProcess(TreeElement node, String? params) => false;
}
```

`properties` (a `PropertyManager`, e.g. `MapPropertyManager`) supplies
`jr:preload="property"` and the XPath `property()` function: `deviceid`,
`subscriberid`, `simserial`, `phonenumber`, `username`, `email`.

## Secondary instances: `externalInstanceParser`

An `ExternalInstanceParser` turns a secondary instance's `src` into a
tree. Its `InstanceProvider`s are asked first (synchronously; they may
return partial elements, completed when evaluation reaches them), then
its file parsers (`addFileInstanceParser`; CSV and GeoJSON are built in),
then XML. As in JavaRosa, only `jr://file/...` and `jr://file-csv/...`
(and `jr://instance/last-saved`) sources are loaded; other `src` values
are ignored with a warning.

```dart
// Serves instance('staff') from the app's database instead of the CSV.
final class StaffProvider implements InstanceProvider {
  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      instanceSrc == 'jr://file-csv/staff.csv';

  @override
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) {
    final root = TreeElement('root')..instanceName = instanceId;
    return root..addChild(
      TreeElement('item', 0)
        ..addChild(TreeElement('name')..value = const StringValue('Grace'))
        ..addChild(TreeElement('role')..value = const StringValue('boss')),
    );
  }
}
```

An `ExternalInstanceParser` holds providers, so it is not copied by
helpers: `withEntities` refuses a base config that has one and takes an
`externalInstanceParserFactory` instead.

`lastSavedSrc` is the `src` read (through the resolver) for
`<instance src="jr://instance/last-saved"/>`; without it those instances
are empty. `dartrosa_collect`'s `LastSaved` provides both the `src` and a
resolver over a store.

## Geopoint actions: `setGeopointAction`

`odk:setgeopoint` actions do nothing by default (the engine has no
location). Give a factory returning a `SetGeopointAction` backed by the
device's location to fill them, as Collect does.

## Feature plugins: `plugins`

A `FormLoadPlugin` takes part in loading every form:

- `createParseProcessors()` returns fresh processors for one parse;
- `prepareForm(form, resolver)` runs after parsing and before any
  session, asynchronously (e.g. importing CSV media into an index). It
  may add function handlers and filter strategies to the `FormDef`;
  `DartRosaConfig.functions` are added after, so the app's functions
  win;
- `answerResolver` types the answers of saved instances loaded with
  `createSession(existingInstance:)` (the first plugin providing one
  wins).

```dart
// motto() reads jr://file/motto.txt, once per form load.
final class MottoPlugin extends FormLoadPlugin {
  const MottoPlugin();

  @override
  Future<void> prepareForm(FormDef form, ResourceResolver resolver) async {
    final motto = utf8.decode(await resolver.read('jr://file/motto.txt'));
    form.addFunctionHandler(_Constant('motto', motto));
  }
}
```

## How the Collect packages compose

The Collect-layer packages are plugins and helpers over `DartRosaConfig`:

- **`dartrosa_external_data`**: `ExternalDataPlugin` (a `FormLoadPlugin`)
  imports the form's CSV media, registers `pulldata()` and serves the
  choices of `search()` selects (`loadSelectChoices`).
- **`dartrosa_collect`**: `collectFormConfig(media: ...)` builds a config
  the way Collect's `FormLoaderTask` does: `jr://instance/last-saved`
  through `LastSaved`, fast external itemsets (`itemsets.csv`, a
  `FastExternalItemsetsPlugin`) and `EditedFormFinalizationProcessor`
  (`meta/deprecatedID` when editing). Your own functions, processors and
  plugins are passed through, before Collect's.
- **`dartrosa_entities`**: `withEntities(base, entitiesRepository: ...)`
  adds the entity parse processor, local entity lists as secondary
  instances, the entity filter strategy and the entity finalization
  processor. With an `ExternalDataPlugin` in `base`, entity lists join
  its `pulldata()` and are asked first, then the CSV media (as in
  Collect), instead of registering a second `pulldata` handler; without
  one, `withEntities` registers its own `pulldata` (keeping an existing
  handler as its fallback). Call it for every form load.
- **`dartrosa_encryption`** and **`dartrosa_openrosa`** work on the
  finalized `Submission` (encrypting, uploading) and need no config.

```dart
// The form's media folder.
final media = MapResourceResolver({
  'jr://file/sizes.csv': Uint8List.fromList(
    utf8.encode('name,label,size\nbig,Big,10\n'),
  ),
});
// Entity lists downloaded from the server (implement
// EntitiesRepository on your database).
final entities = InMemEntitiesRepository()
  ..save('people', [NewEntity('p1', 'Ada')]);
final lastSaved = LastSaved(InMemoryLastSavedStore(), 'collect-v1');

final config = withEntities(
  collectFormConfig(
    media: media,
    lastSaved: lastSaved, // jr://instance/last-saved
    plugins: [
      // pulldata() and search() over the form's CSV media.
      ExternalDataPlugin(listMedia: (form) => ['sizes.csv']),
    ],
  ),
  // Entity lists become secondary instances and answer pulldata()
  // before CSV media.
  entitiesRepository: () => entities,
);

final definition = await FormDefinition.parse(formXml, config: config);
final session = definition.createSession();
// ... fill the form, then:
if (session.finalize() case FinalizeSuccess(:final submission)) {
  saveFormEntities(session, entities); // entities the form created
  await lastSaved.instanceSaved(session); // for the next instance
```

In that form, `pulldata('people', 'label', 'name', 'p1')` reads the
`people` entity list and `pulldata('sizes', 'size', 'name', 'big')` reads
`sizes.csv`.

## Other extension points (JavaRosa-compatible API)

`XFormParser` (from `package:dartrosa/javarosa.dart`) also has
`registerActionHandler(name, handler)` for custom action elements and
`onWarning(callback)` for parse warnings; `FormDef` has
`addFunctionHandler`, `addFilterStrategy` and `recordAudioListener`
(for `odk:recordaudio`). Use them when driving the parser yourself; see
[MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md).
