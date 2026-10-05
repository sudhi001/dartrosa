# DartRosa

A pure-Dart port of [JavaRosa](https://github.com/getodk/javarosa), the ODK
XForms engine used by ODK Collect, for Flutter and any other Dart platform.

> **Status:** the JavaRosa engine port is complete (Phases 0–6): every
> JavaRosa test class is ported, and the JVM oracle comparison (parse
> structure, initialization, recalculation scenarios, full walks, seeded
> random-answer walks and byte-identical submission XML) matches on the
> JavaRosa, DartRosa and ODK Collect test-form corpora. Phase 7 (Flutter
> renderer) and Phase 8 (Collect layer) are well under way and Phase 9 has
> started.

## Documentation

- [Getting started](docs/GETTING_STARTED.md): parse a form, fill it, save,
  resume, finalize, and show it in Flutter.
- [Migrating from JavaRosa](docs/MIGRATING_FROM_JAVAROSA.md): Java class →
  Dart equivalent, naming, behavioural differences, what is not ported.
- [Compatibility](docs/COMPATIBILITY.md): ODK XForms features, XPath
  functions, Collect appearances and platforms, with conformance numbers.
- [Plugins](docs/PLUGINS.md): custom functions, processors, secondary
  instances, and how the Collect packages compose.
- API reference: run `dart doc` in a package (dartdoc on pub.dev once
  published).
- [Benchmarks](docs/BENCHMARKS.md) and the [porting plan](docs/PORTING_PLAN.md).

The Dart snippets in the guides are run by the tests in
`packages/*/test/docs/`, so they stay correct.

## Packages

| Package | Purpose |
|---|---|
| [`dartrosa`](packages/dartrosa) | XForms engine: XPath, parse, recalculate, validate, navigate, serialize; JavaRosa-compatible API (`javarosa.dart`) and test DSL (`testing.dart`) |
| [`dartrosa_external_data`](packages/dartrosa_external_data) | Collect's `pulldata()` and `search()` over CSV form media |
| [`dartrosa_entities`](packages/dartrosa_entities) | ODK entities: entity forms, entity lists as secondary instances, offline updates |
| [`dartrosa_collect`](packages/dartrosa_collect) | Collect services: audit log, fast external itemsets, last-saved instance, edited submissions |
| [`dartrosa_encryption`](packages/dartrosa_encryption) | Encrypted submissions, decryptable by ODK Central and Briefcase |
| [`dartrosa_openrosa`](packages/dartrosa_openrosa) | OpenRosa client: form lists, manifests, downloads, submission upload |
| [`dartrosa_calendars`](packages/dartrosa_calendars) | Collect's non-Gregorian date appearances (ethiopian, coptic, islamic, ...) |
| [`dartrosa_flutter`](packages/dartrosa_flutter) | Flutter renderer (`XFormView`), with an example app that fills every corpus form |

The core is pure Dart (no Flutter, no `dart:io`) and is tested on the VM,
dart2js and dart2wasm. `tool/check_core_purity.dart` enforces this.

## Publishing

The packages are not on pub.dev yet; until then depend on them from Git
(`path: packages/<name>`) or with `path:` dependencies. To publish, go in
dependency order, running `dart pub publish` in each package
(`flutter pub publish` for the renderer), after bumping versions and
CHANGELOGs together:

1. `dartrosa` and `dartrosa_calendars` (no sibling dependencies);
2. `dartrosa_external_data` and `dartrosa_encryption`;
3. `dartrosa_entities` (needs `dartrosa_external_data`) and
   `dartrosa_openrosa` (needs `dartrosa_encryption`);
4. `dartrosa_collect` (its dev dependencies, used by a docs test, include
   `dartrosa_entities`, and publishing resolves dev dependencies too);
5. `dartrosa_flutter`: first replace its `path:` dependencies (and its
   `dependency_overrides`) with version constraints; pub.dev rejects
   packages with path dependencies.

The workspace packages already name their siblings with version
constraints (`^0.0.1`); inside the workspace they resolve to the local
copies.

## Development

```sh
dart pub get
dart format .
dart analyze
dart test packages/dartrosa
dart run tool/check_core_purity.dart
# browser (run inside a package):
(cd packages/dartrosa && dart test -p chrome && dart test -p chrome --compiler dart2wasm)
```

## Conformance against real JavaRosa

DartRosa's goal is identical behaviour to JavaRosa 6.0.0. `conformance/`
holds the evidence:

- `forms/` — about 400 XForms: JavaRosa's own test forms (`tool/import_javarosa_forms.sh`),
  ODK Collect and ODK Web Forms test forms, pyxform-generated forms, plus ours
- `scenarios/` — form + sequence of user actions
- `traces/` — JSON traces produced by real JavaRosa (committed goldens)
- `jvm_oracle/` — the harness that produces them (needs Java 17+, no Gradle)

```sh
conformance/jvm_oracle/oracle.sh batch conformance          # regenerate all traces
conformance/jvm_oracle/oracle.sh walk path/to/form.xml      # trace one form
conformance/jvm_oracle/oracle.sh scenario conformance/scenarios/basics.scenario.json
```

The trace format and normalization rules are in
[`conformance/TRACE_FORMAT.md`](conformance/TRACE_FORMAT.md).

## License

Apache License 2.0. DartRosa is a derivative work of JavaRosa; see
[`NOTICE.md`](NOTICE.md).
