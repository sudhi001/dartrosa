# Use CSV lists and entities offline

**Type:** recipe. **Packages:** `dartrosa`, `dartrosa_entities`,
`dartrosa_external_data`.

Many projects register something once and visit it later: households,
patients, water points, trees. ODK's *entities* do this: a registration
form creates an entity in a list on ODK Central, and follow-up forms
offer the list as choices. With DartRosa, as with ODK Collect, it also
works offline: a household registered this morning can be visited this
afternoon, before either form is uploaded.

This recipe registers households (choosing the village from a CSV file)
and offers them in a follow-up form, using the following steps:

1. Load every form through one configuration.
2. Know the entity list.
3. Save the entities a finalized form creates.
4. Read them in the follow-up form.

## 1. One configuration for every form

`withEntities` adds entity support to a `DartRosaConfig`;
`ExternalDataPlugin` adds `pulldata()` and `search()` over the form's CSV
files. Load the registration form and the follow-up forms through the
same function, so they share the entity repository:

```dart
// One repository for the whole app; implement EntitiesRepository on your
// database to keep the lists between runs.
final households = InMemEntitiesRepository();

/// Loads any form of the project: entity forms and the forms that read
/// their lists share the repository.
Future<FormDefinition> loadForm(String xml, ResourceResolver media) =>
    FormDefinition.parse(
      xml,
      config: withEntities(
        DartRosaConfig(
          resolver: media,
          // pulldata() and search() over the form's CSV media.
          plugins: [
            ExternalDataPlugin(listMedia: (form) => ['villages.csv']),
          ],
        ),
        entitiesRepository: () => households,
      ),
    );
```

`select_one_from_file villages.csv` needs no plugin: the engine reads
the CSV through the resolver and filters it with `choice_filter`.

## 2. Know the entity list

Entity lists come from the server with the forms that use them (see
`LocalEntityUseCases` for reconciling downloads). A form adds entities
only to lists the repository already has, as in Collect:

```dart
// Lists come from the server with the form (see LocalEntityUseCases);
// forms add entities only to lists the repository already has.
households.addList('households');
```

## 3. Save what a form creates

After a registration form is finalized, save its entities. This works
offline; upload the submission later, and ODK Central creates the
entity on its side.

```dart
final register = (await loadForm(registerXml, media)).createSession();
final [village, head] = register.root.children.cast<QuestionNode>();
final villages = [for (final c in village.choices) c.value]; // kib, mat
register
  ..answer(village.index, const SelectOneValue(Selection('kib')))
  ..answer(head.index, const StringValue('Amina'));
if (register.finalize() is FinalizeSuccess) {
  // Works offline: the household is in the local list before upload.
  saveFormEntities(register, households);
}
```

## 4. Read them in the follow-up form

The follow-up form declares the list as `jr://file-csv/households.csv`
(in XLSForm, `select_one_from_file households.csv`); the local list is
served in its place, with the new household in it:

```dart
// The visit form offers the new household straight away.
final visit = (await loadForm(visitXml, media)).createSession();
final household = visit.root.children.single as QuestionNode;
final labels = [
  for (final c in household.choices) household.choiceLabel(c),
]; // ['Amina (kib)']
```

## How it works

The registration form has an `entities:entities-version` attribute and
a `meta/entity` block (pyxform writes both from the XLSForm `entities`
sheet). `withEntities` adds the parse processor that reads it, serves
local lists as secondary instances, answers `[name = ...]` filters from
the repository and adds the finalization processor that builds the
entity. `saveFormEntities` stores it, as Collect does after finalizing.

## Related

* [Use CSV data and entities](../guides/external-data-and-entities.md):
  `pulldata()`, `search()` and entity updates, in more depth
* [PLUGINS.md](../PLUGINS.md#how-the-collect-packages-compose): combining
  entities with the other Collect packages
* [ODK entities documentation](https://docs.getodk.org/central-entities/)
