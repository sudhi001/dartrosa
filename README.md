# DartRosa

[![CI](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml/badge.svg)](https://github.com/sudhi001/dartrosa/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

DartRosa fills [ODK](https://getodk.org) forms in Dart and Flutter. It is
a faithful port of [JavaRosa](https://github.com/getodk/javarosa) 6.0.0,
the form engine inside ODK Collect, plus the ODK Collect features around
it and a Flutter form renderer. Forms behave exactly as they do in ODK
Collect, on Android, iOS, the web, desktop and servers.

![The life of a form: designed as a spreadsheet, filled in with DartRosa, sent to ODK Central](docs/images/form-lifecycle.svg)

New to ODK or XForms? Read the [overview](docs/OVERVIEW.md) first.

| | | |
|---|---|---|
| ![Number questions](docs/images/screenshots/text_number_light.png) | ![Choices with pictures](docs/images/screenshots/select_images_light.png) | ![An Ethiopian-calendar date](docs/images/screenshots/date_ethiopian_dark.png) |

## Quick start

```dart
import 'package:dartrosa/dartrosa.dart';

Future<void> main() async {
  final definition = await FormDefinition.parse(xform);
  final session = definition.createSession();

  final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
  session.answer(name.index, const StringValue('Ada'));
  switch (session.answer(age.index, const IntegerValue(-3))) {
    case AnswerConstraintViolated(:final message):
      print('Rejected: $message');
    case AnswerAccepted() || AnswerRequired() || AnswerRejected():
      break;
  }

  if (session.finalize() case FinalizeSuccess(:final submission)) {
    print(submission.xml); // ready to upload
  }
}
```

In Flutter, `XFormView(session: session)` shows the form with one
question per screen, as in ODK Collect. Install with `dart pub add
dartrosa` (or `flutter pub add dartrosa_flutter`);
[Getting started](docs/GETTING_STARTED.md) walks through the API.

## Packages

![DartRosa package architecture](docs/images/architecture.svg)

| Package | Purpose |
|---|---|
| [`dartrosa`](packages/dartrosa) | The XForms engine: parse, XPath, recalculate, validate, navigate, serialize. Session API, JavaRosa-compatible API and test DSL |
| [`dartrosa_flutter`](packages/dartrosa_flutter) | Flutter renderer (`XFormView`), with an example app that fills every test form |
| [`dartrosa_external_data`](packages/dartrosa_external_data) | `pulldata()` and `search()` over CSV media |
| [`dartrosa_entities`](packages/dartrosa_entities) | ODK entities: entity forms, local entity lists, offline updates |
| [`dartrosa_collect`](packages/dartrosa_collect) | Audit log, last-saved instance, fast external itemsets, edited submissions |
| [`dartrosa_encryption`](packages/dartrosa_encryption) | Encrypted submissions, decryptable by ODK Central and Briefcase |
| [`dartrosa_openrosa`](packages/dartrosa_openrosa) | OpenRosa client: form lists, manifests, downloads, submission upload |
| [`dartrosa_calendars`](packages/dartrosa_calendars) | Ethiopian, Coptic, Islamic, Persian, Bikram Sambat, Myanmar and Buddhist dates |

Everything except `dartrosa_flutter` is pure Dart (no Flutter, no
`dart:io`) and is tested on the Dart VM, dart2js and dart2wasm.

## Documentation

* [Documentation index](docs/README.md): which document is for whom.
* Concepts: [Overview](docs/OVERVIEW.md), [Architecture](docs/ARCHITECTURE.md).
* Guides: [Getting started](docs/GETTING_STARTED.md),
  [Show a form in Flutter](docs/guides/render-a-form-in-flutter.md),
  [Save and resume drafts](docs/guides/save-and-resume-drafts.md),
  [Encrypt and submit](docs/guides/encrypt-and-submit.md),
  [CSV data and entities](docs/guides/external-data-and-entities.md),
  [Non-Gregorian calendars](docs/guides/non-gregorian-calendars.md),
  [Plugins](docs/PLUGINS.md).
* Reference: [Compatibility](docs/COMPATIBILITY.md),
  [Migrating from JavaRosa](docs/MIGRATING_FROM_JAVAROSA.md),
  [Standards](docs/STANDARDS.md), [Benchmarks](docs/BENCHMARKS.md),
  [Glossary](docs/GLOSSARY.md), API reference (`dart doc`).

The Dart code in the guides is compiled and run by the tests in
`packages/*/test/docs/`.

## Status

The JavaRosa engine port is complete. The Collect layer and the Flutter
renderer cover the ODK Collect features listed in
[Compatibility](docs/COMPATIBILITY.md), which also lists the gaps.

* Conformance: 401 test forms from JavaRosa, ODK Collect, ODK Web Forms
  and pyxform; 397 traced by real JavaRosa 6.0.0 (structure,
  initialization, full walks, 1,191 seeded random-answer walks,
  submission XML) with 0 differences. The other 4 use unseeded random
  numbers by design. CI re-runs JavaRosa and fails if a trace changes.
* Every JavaRosa 6.0.0 unit test class is ported and passes on the Dart VM.
* The example app fills, saves, resumes, finalizes and encrypts every
  corpus form.
* Performance targets are met on a desktop
  ([Benchmarks](docs/BENCHMARKS.md)); phone measurements are still to do.

![How DartRosa is checked against JavaRosa](docs/images/conformance-flow.svg)

## Development

```sh
dart pub get
dart format .
dart analyze --fatal-infos
dart run tool/check_core_purity.dart
dart test packages/dartrosa
(cd packages/dartrosa && dart test -p chrome && dart test -p chrome --compiler dart2wasm)
(cd packages/dartrosa_flutter && flutter test --exclude-tags golden)
conformance/jvm_oracle/oracle.sh batch conformance   # regenerate traces (Java 17+)
```

How the conformance traces work: [conformance/TRACE_FORMAT.md](conformance/TRACE_FORMAT.md).
Publishing: [docs/development/RELEASING.md](docs/development/RELEASING.md).

## Contributing

Contributions are welcome: read [CONTRIBUTING.md](CONTRIBUTING.md) and
the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems
privately as described in [SECURITY.md](SECURITY.md).

## Licence

Apache License 2.0 ([LICENSE](LICENSE)). DartRosa is a derivative work of
JavaRosa and ports code from ODK Collect and other Apache-2.0 and MIT
projects. Attribution, third-party licences and compliance information:
[docs/legal/README.md](docs/legal/README.md).

DartRosa is an independent project. It is not affiliated with or endorsed
by Get ODK Inc. or the JavaRosa and ODK Collect projects; their names are
used only to describe where the code comes from and what it is compatible
with.
