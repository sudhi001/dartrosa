# Use CSV data and entities

**Audience:** developers whose forms read lists and lookup tables (towns,
health facilities, products) or keep track of things across visits
(households, patients, trees). **Type:** how-to guide.

Forms often need data that does not fit in the form itself: a list of
3,000 villages to choose from, the price of each product, the households
registered last month. ODK has three ways to bring it in, and DartRosa
supports all of them:

| Need | ODK feature | DartRosa package |
|---|---|---|
| Choose from a long list, filter it by an earlier answer | CSV secondary instance (`select_one_from_file` in XLSForm) | `dartrosa` (engine) |
| Look up one value in a table | `pulldata()`, or a `search()` select | `dartrosa_external_data` |
| Create and update records that later forms read | entities | `dartrosa_entities` |

Every Dart snippet below is run by
`packages/dartrosa_collect/test/docs/external_data_guide_test.dart`.

## Choices from a CSV file

In XLSForm, `select_one_from_file towns.csv` with a `choice_filter` of
`region=${region}` becomes a secondary instance and an itemset with a
filter. The engine reads the file through your `ResourceResolver` (here
an in-memory one; in an app, the form's media folder as in
[Show a form in a Flutter app](render-a-form-in-flutter.md)):

```dart
final definition = await FormDefinition.parse(
  choicesForm,
  config: DartRosaConfig(
    resolver: MapResourceResolver({
      'jr://file-csv/towns.csv': utf8.encode(
        'name,label,region\nnbo,Nairobi,central\nmsa,Mombasa,coast\n',
      ),
    }),
  ),
);
final session = definition.createSession();
final [region, town] = session.root.children.cast<QuestionNode>();
session.answer(region.index, const StringValue('coast'));
final towns = [for (final c in town.choices) c.value]; // ['msa']
```

The choices update as soon as the region changes. Filtering a
100,000-row file takes about 10 ms on a desktop
([benchmarks](../BENCHMARKS.md)). XML and GeoJSON files work the same way
(`jr://file/places.xml`, `jr://file/places.geojson`).

## pulldata() and search()

`pulldata('fruits', 'price', 'name', ${fruit})` looks up one cell of
`fruits.csv`; a select with the appearance `search('fruits')` takes its
choices from that file. Both are ODK Collect features outside JavaRosa,
ported in `dartrosa_external_data`. Add its plugin to the configuration,
saying which CSV files the form has:

```dart
// The form's media files, as downloaded with the form.
final media = MapResourceResolver({
  'jr://file/fruits.csv': utf8.encode(
    'name,label,price\nmango,Mango,1.5\npapaya,Papaya,2\n',
  ),
});
final config = DartRosaConfig(
  resolver: media,
  plugins: [
    // Imports the CSV files when the form loads and registers
    // pulldata(). Give it a persistent ExternalDataRepository to
    // import each file only when it changes.
    ExternalDataPlugin(listMedia: (form) => ['fruits.csv']),
  ],
);
final definition = await FormDefinition.parse(fruitsForm, config: config);
final session = definition.createSession();
```

`pulldata()` calculations then work like any other. The choices of a
`search()` select are read with `loadSelectChoices`; the Flutter renderer
does this for you:

```dart
// A select with a search() appearance: its choices come from the CSV.
final choices = loadSelectChoices(
  FormEntryPrompt(definition.formDef, favourite.index),
);
final names = [for (final c in choices) c.value]; // mango, papaya
session.answer(favourite.index, const SelectOneValue(Selection('papaya')));
```

## Entities

Entities let one form create or update records that other forms read,
even offline. A household registration form creates a household entity;
the follow-up visit form offers the registered households as choices.
The server (ODK Central) keeps the lists, called entity lists or
datasets; the app keeps a local copy and adds to it as forms are
finalized. The [ODK Entities spec](https://getodk.github.io/xforms-spec/entities)
defines the form side.

`dartrosa_entities` ports ODK Collect's entities module. Implement
`EntitiesRepository` on your database (an in-memory one is included),
then wrap your configuration with `withEntities`:

```dart
// Your storage of the entity lists downloaded from the server
// (implement EntitiesRepository on your database).
final people = InMemEntitiesRepository()
  ..save('people', [
    NewEntity('p1', 'Ada', properties: const [('full_name', 'Ada L')]),
  ]);
final config = withEntities(
  const DartRosaConfig(),
  entitiesRepository: () => people,
);
```

Forms then read the list as `instance('people')` (the form declares it as
`jr://file-csv/people.csv`; the local list is served in its place) and
through `pulldata('people', ...)`. When an entity form is finalized, save
what it created or updated:

```dart
if (session.finalize() is FinalizeSuccess) {
  final created = formEntities(session)!.entities.single;
  // created.label == 'Grace Hopper', created.action == EntityAction.create
  saveFormEntities(session, people); // works offline, before upload
```

The next form sees the new person straight away. When the device is
online again, upload the submission as usual
([Encrypt and submit](encrypt-and-submit.md)); ODK Central creates the
entity on its side. `LocalEntityUseCases` reconciles the local lists with
fresh downloads from the server.

## Combining them

`withEntities` works on top of a configuration that already has an
`ExternalDataPlugin` (and on `dartrosa_collect`'s `collectFormConfig`).
Entity lists then answer `pulldata()` first and CSV media second, as in
Collect. [PLUGINS.md](../PLUGINS.md#how-the-collect-packages-compose) has
the full setup.

## Related

* [COMPATIBILITY.md](../COMPATIBILITY.md#secondary-instances): which
  secondary instance kinds are supported
* [dartrosa_external_data README](../../packages/dartrosa_external_data/README.md),
  [dartrosa_entities README](../../packages/dartrosa_entities/README.md)
