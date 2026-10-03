# DartRosa

A pure-Dart port of [JavaRosa](https://github.com/getodk/javarosa), the ODK
XForms engine used by ODK Collect, for Flutter and any other Dart platform.

> **Status: Phase 0 (foundations).** The workspace, test DSL and JavaRosa
> conformance oracle are in place; the engine is being ported phase by phase.
> See [`docs/PORTING_PLAN.md`](docs/PORTING_PLAN.md).

## Packages

| Package | Purpose | Status |
|---|---|---|
| [`dartrosa_xpath`](packages/dartrosa_xpath) | XPath 1.0 + ODK function library | exceptions ported |
| [`dartrosa`](packages/dartrosa) | XForm engine: parse, recalculate, validate, navigate, serialize | test DSL (`package:dartrosa/testing.dart`) |

Both are pure Dart (no Flutter, no `dart:io`) and are tested on the VM,
dart2js and dart2wasm. `tool/check_core_purity.dart` enforces this.

## Development

```sh
dart pub get
dart format .
dart analyze
dart test packages/dartrosa_xpath packages/dartrosa
dart run tool/check_core_purity.dart
# browser (run inside a package):
(cd packages/dartrosa && dart test -p chrome && dart test -p chrome --compiler dart2wasm)
```

## Conformance against real JavaRosa

DartRosa's goal is identical behaviour to JavaRosa 6.0.0. `conformance/`
holds the evidence:

- `forms/` — JavaRosa's own test forms (`tool/import_javarosa_forms.sh`) plus ours
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
