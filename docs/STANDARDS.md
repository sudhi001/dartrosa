# Standards and specifications

**Audience:** technical leads, procurement and quality reviewers, and
developers who need to know which specifications DartRosa follows and
how that is checked. **Type:** reference.

DartRosa implements the open specifications behind ODK, and its
engineering process is organised around several ISO/IEC quality and
documentation standards. This page lists each one, what it means
concretely for DartRosa, and where it is verified.

> **Alignment, not certification.** No part of DartRosa has been
> certified or audited against any of these standards by a third party.
> "Implements" means the behaviour is specified there and tested here;
> "aligns with" means the standard's model was used to organise the work
> and its evidence. Where DartRosa departs from a specification, this
> page says so.

Licensing and software supply-chain standards (ISO/IEC 5962, SPDX; and
ISO/IEC 5230, OpenChain) are covered in [legal/README.md](legal/README.md).

## Data-collection specifications

### ODK XForms specification

The [ODK XForms specification](https://getodk.github.io/xforms-spec/)
defines the XML forms that ODK tools exchange: a profile of W3C XForms
1.1 with ODK extensions (the `jr:`, `odk:` and `orx:` namespaces).

* What DartRosa does: parses and fills ODK XForms as JavaRosa 6.0.0
  does, including repeats, itext translations, secondary instances (XML,
  CSV, GeoJSON, last-saved), actions and events (`setvalue`,
  `odk:setgeopoint`, `odk:recordaudio`), preloads and submission
  profiles. Where JavaRosa departs from the specification, DartRosa
  follows JavaRosa, because ODK Collect users depend on that behaviour.
* Verified by: the conformance suite (401 forms, traces from real
  JavaRosa, 0 differences) and every JavaRosa 6.0.0 unit test class,
  ported to Dart. The feature-by-feature list is in
  [COMPATIBILITY.md](COMPATIBILITY.md).

### W3C XForms 1.1 and XPath 1.0 (as profiled by ODK)

ODK XForms uses a subset of [W3C XForms 1.1](https://www.w3.org/TR/xforms11/)
(the model, binds, the body controls and the recalculation model) and
[XPath 1.0](https://www.w3.org/TR/1999/REC-xpath-19991116/) for every
expression.

* What DartRosa does: implements the XPath 1.0 syntax ODK uses (paths,
  predicates, axes, unions, all operators), XPath's type coercions and
  comparison rules as JavaRosa applies them, and ODK's function library
  (dates, geography, `digest`, `randomize`, `extract-signed`,
  `indexed-repeat`, ...). Recalculation follows XForms' dependency-graph
  model through JavaRosa's `TriggerableDag`.
* Departures: like JavaRosa (and so ODK Collect), DartRosa does not
  implement the XPath 1.0 core functions `floor`, `ceiling`, `last`,
  `local-name`, `name`, `substring`, `lang` and `id`; forms calling them
  get `XPathUnhandledException`, as in Collect. `regex()` uses the
  ECMAScript dialect instead of Java's
  ([DEVIATIONS.md](../conformance/DEVIATIONS.md)). Only the XForms 1.1
  features ODK uses are implemented; DartRosa is not a general W3C
  XForms processor.
* Verified by: `packages/dartrosa/test/xpath` (ported JavaRosa XPath
  tests) and the conformance traces, which record every computed value.

### ODK Entities specification

The [ODK Entities specification](https://getodk.github.io/xforms-spec/entities)
defines how forms create and update entities (shared records such as
households or patients) and read entity lists.

* What DartRosa does: `dartrosa_entities` supports the
  `entities-version` values ODK Collect supports (2022.1, 2023.1, 2024.1
  and 2025.1 prefixes): create, update and upsert, `entities:saveto`,
  labels, local entity lists as secondary instances and offline updates.
* Verified by: the tests in `packages/dartrosa_entities/test`, ported
  from ODK Collect's entities module and JavaRosa's entity tests.

### OpenRosa

The [OpenRosa APIs](https://docs.getodk.org/openrosa/) are the HTTP
protocols between form apps and servers: the Form List API, the form
manifest, the Form Submission API, and the submission encryption
format.

* What DartRosa does: `dartrosa_openrosa` (a port of ODK Collect's
  OpenRosa client) sends the `X-OpenRosa-Version: 1.0` header, reads form
  lists and manifests, downloads forms and media, and uploads submissions
  as `multipart/form-data` with `xml_submission_file`, split to respect
  the server's `X-OpenRosa-Accept-Content-Length`; it authenticates with
  HTTP Digest and Basic. `dartrosa_encryption` produces ODK's encrypted
  submission format: a random 256-bit AES key (AES/CFB with PKCS#5
  padding, as Collect uses) for the submission and each attachment, the
  key encrypted with the form's RSA public key (RSAES-OAEP with SHA-256),
  a plaintext manifest and its signature.
* Verified by: `packages/dartrosa_openrosa/test` against a mock server,
  and `packages/dartrosa_encryption/test/golden_test.dart`, which
  compares DartRosa's output byte for byte with encryptions made by ODK
  Collect's own code given the same random bytes, and decrypts it as ODK
  Briefcase does.

### ISO 8601 dates and times

XForms store dates, times and date-times as ISO 8601 text
(`2024-03-20`, `14:30:00.000+03:00`, `2024-03-20T14:30:00.000+03:00`).

* What DartRosa does: reads and writes these forms as JavaRosa does,
  including its time zone offsets and millisecond precision; uses the
  device's local time zone as JavaRosa uses the JVM's default.
* Calendar note: for dates before the Gregorian reform (15 October
  1582), JavaRosa uses Java's hybrid calendar, which counts earlier dates
  in the Julian calendar. ISO 8601 uses the proleptic Gregorian calendar
  throughout. DartRosa reproduces JavaRosa's hybrid behaviour (in
  `lib/src/model/utils/date_utils.dart`) so that historical dates
  compute the same values as in Collect. Non-Gregorian calendar
  appearances (Ethiopian, Persian, ...) change only how dates are shown
  and picked; the stored value is always the Gregorian ISO 8601 date
  ([guide](guides/non-gregorian-calendars.md)).
* Verified by: the engine tests and conformance traces run in nine time
  zones in CI (UTC, America/New_York, Asia/Kolkata, Europe/London,
  Etc/GMT-2, Etc/GMT-3, Pacific/Chatham, Europe/Warsaw, Europe/Kiev),
  covering offsets, half-hour and 45-minute zones and daylight saving
  changes.

### ISO 639 language codes

ODK forms name their translations freely; XLSForm encourages a name
followed by an ISO 639 code, such as `French (fr)`.

* What DartRosa does: the engine treats language names as opaque
  strings, as JavaRosa does. The Flutter renderer reads the ISO 639-1 code
  in a language name (or the name alone) to lay out right-to-left
  languages: `ar`, `fa`, `he`, `ur`, `ps`, `sd`, `ug`, `yi` and `dv`.
* Verified by: the renderer's widget and golden tests
  (`packages/dartrosa_flutter/test`).

## Quality standards

### ISO/IEC 25010 product quality model

ISO/IEC 25010 describes software product quality as eight
characteristics. The table maps each to the evidence DartRosa has for
it. It is a self-assessment.

| Characteristic | What it means here | Evidence |
|---|---|---|
| Functional suitability | Forms behave exactly as in ODK Collect | Conformance suite: 401 forms, 397 traced by real JavaRosa (structure, initialization, full walks, 1,191 seeded random walks, submissions), 0 differences; every JavaRosa 6.0.0 test class ported; the example app fills every corpus form ([COMPATIBILITY.md](COMPATIBILITY.md)) |
| Performance efficiency | Fast enough on mid-range phones | AOT benchmarks against targets: parse, answer, CSV filter, repeat growth ([BENCHMARKS.md](BENCHMARKS.md)); phone measurements still to do |
| Compatibility | Works with ODK's forms, servers and data | ODK XForms, Entities and OpenRosa above; submissions byte-identical to JavaRosa's; encrypted output decryptable by ODK Central and Briefcase; JavaRosa-compatible API for existing Java code |
| Interaction capability (usability) | Field workers can fill forms easily and accessibly | Collect-like pager and scroll layouts; Collect appearances; WCAG 2.1 AA as the accessibility target (below); right-to-left layouts; localizable interface strings |
| Reliability | No lost or wrong data | Drafts keep every value; finalize validates the whole form; tests in nine time zones; CI on every push; coverage gate of at least 90% of lines (`tool/check_coverage.dart`) |
| Security | Collected data stays confidential | Submission encryption compatible with ODK (RSA-OAEP and AES); no global mutable state; no reflection; the engine performs no file or network access of its own |
| Maintainability | Easy to change safely | Pure-Dart packages with one responsibility each; strict analysis (`dart analyze --fatal-infos` with strict casts, inference and raw types); public API documentation required by lint; `dart format` in CI; each ported file names its JavaRosa source |
| Flexibility (portability) | Runs wherever Dart runs | Pure-Dart core checked by `tool/check_core_purity.dart`; tested on the Dart VM, dart2js and dart2wasm in CI; Flutter on Android, iOS, web and desktop ([COMPATIBILITY.md](COMPATIBILITY.md#platforms)) |

The 2023 revision of ISO/IEC 25010 renamed usability to interaction
capability and portability to flexibility, and added safety as a ninth
characteristic; safety is not applicable to a form engine.

### ISO/IEC/IEEE 26514 user documentation

ISO/IEC/IEEE 26514 covers the design and development of user
documentation. DartRosa's documentation follows its main principles:

* each document states its audience and its type at the top;
* concept, task and reference information are kept apart: concepts in
  [OVERVIEW.md](OVERVIEW.md) and [ARCHITECTURE.md](ARCHITECTURE.md),
  tasks in [GETTING_STARTED.md](GETTING_STARTED.md) and
  [guides/](guides/), reference in [COMPATIBILITY.md](COMPATIBILITY.md),
  [PLUGINS.md](PLUGINS.md), [MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md),
  this page, [BENCHMARKS.md](BENCHMARKS.md) and the API reference
  (`dart doc`);
* terms are used consistently and defined in [GLOSSARY.md](GLOSSARY.md);
* task guides list prerequisites, give steps in order and say what the
  result is;
* every Dart example is compiled and run by the tests in
  `packages/*/test/docs/`, so the documentation matches the software;
* figures have text alternatives.

The index of documents by audience is [docs/README.md](README.md).

### WCAG 2.1 AA (renderer accessibility target)

[WCAG 2.1](https://www.w3.org/TR/WCAG21/) level AA is the target for the
Flutter renderer.

* What the renderer does: each question is one accessibility node
  labelled with its label, "required" and its validation state;
  validation errors are announced as live regions, including when Next
  or Finalize is blocked; focus moves in form order; choice and button
  targets are at least 48 by 48 dp; colours come from the app's Material
  theme, so contrast follows the theme; forms in right-to-left languages
  are mirrored.
* Not yet done: a full WCAG audit with screen readers on devices;
  audio and video in labels depend on the app's delegates.
* Verified by: `packages/dartrosa_flutter/test/accessibility_test.dart`.
