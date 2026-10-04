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

## Packages

| Package | Purpose | Status |
|---|---|---|
| [`dartrosa`](packages/dartrosa) | XForm engine: XPath, parse, recalculate, validate, navigate, serialize | XPath parser; test DSL (`package:dartrosa/testing.dart`) |

The core is pure Dart (no Flutter, no `dart:io`) and are tested on the VM,
dart2js and dart2wasm. `tool/check_core_purity.dart` enforces this.

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
