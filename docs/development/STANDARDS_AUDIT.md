# Dart and pub.dev standards audit

**Audience:** maintainers and reviewers of the pure-Dart packages.
**Type:** reference (audit record).

This page records an audit of the seven pure-Dart packages (`dartrosa`,
`dartrosa_calendars`, `dartrosa_collect`, `dartrosa_encryption`,
`dartrosa_entities`, `dartrosa_external_data`, `dartrosa_openrosa`)
against [Effective Dart](https://dart.dev/effective-dart), the
[pub.dev package layout and scoring](https://pub.dev/help/scoring) rules
and semantic versioning. `dartrosa_flutter` is audited separately.

* Audited: the published 0.1.0 sources (git `cb8c85d`), 2026-10-05,
  with Dart 3.13.4, pana 0.23.19 and dart_apitool 0.23.2.
* Result: the fixes listed here are released as 0.1.1 of every package.
  They change documentation, examples, tests and package metadata only;
  no behaviour or API changes (see [Semantic versioning](#semantic-versioning)).

Status values: **Pass** (met before the audit), **Fixed** (met after the
0.1.1 changes), **Flagged** (not met or worth revisiting; left alone
because changing it would break the API or is a design choice),
**N/A**.

## Summary

| Package | pana 0.1.0 | pana 0.1.1 | API docs 0.1.0 | API docs 0.1.1 | `dart doc` warnings | `pub publish --dry-run` |
| --- | --- | --- | --- | --- | --- | --- |
| `dartrosa` | 160/160 | 160/160 | 1469/1486 (98.9%) | 1486/1486 (100%) | 0 | 0 warnings |
| `dartrosa_calendars` | 160/160 | 160/160 | 94/95 (98.9%) | 95/95 (100%) | 0 | 0 warnings |
| `dartrosa_collect` | 160/160 | 160/160 | 223/223 | 223/223 (100%) | 0 | 0 warnings |
| `dartrosa_encryption` | 160/160 | 160/160 | 41/41 | 41/41 (100%) | 0 | 0 warnings |
| `dartrosa_entities` | 160/160 | 160/160 | 228/228 | 228/228 (100%) | 0 | 0 warnings |
| `dartrosa_external_data` | 160/160 | 160/160 | 179/181 (98.9%) | 181/181 (100%) | 0 | 0 warnings |
| `dartrosa_openrosa` | 160/160 | 160/160 | 277/278 (99.6%) | 278/278 (100%) | 0 | 0 warnings |

The pana scores were computed locally from a clean export of each
package (see [How to reproduce](#how-to-reproduce)). API docs is pana's
count of documented API elements.

## Effective Dart: style

| Item | Status | Evidence |
| --- | --- | --- |
| Identifier, file and library naming (`UpperCamelCase` types, `lowerCamelCase` members, `lowercase_with_underscores` files) | Pass | `dart analyze --fatal-infos` at the root: 0 issues, with `package:lints/recommended.yaml` (which has `camel_case_types`, `non_constant_identifier_names`, `file_names`, `library_prefixes`, ...) and the stricter rules in `analysis_options.yaml` |
| Formatting | Pass | `dart format --output=none --set-exit-if-changed .`: 0 changed |
| Import ordering, relative imports inside a package | Pass | `directives_ordering` and `prefer_relative_imports` are enabled |
| Strict typing | Pass | `strict-casts`, `strict-inference`, `strict-raw-types`, `type_annotate_public_apis`, `strict_top_level_inference` |
| License header on every source file | Pass | `dart run tool/license_headers.dart --check`: every file has an SPDX header |

## Effective Dart: documentation

| Item | Status | Evidence |
| --- | --- | --- |
| A doc comment on every public member | Fixed | `public_member_api_docs` was already enforced, but implicit default constructors can't carry a comment: pana counted 17 (dartrosa), 1 (calendars), 2 (external_data) and 1 (openrosa) undocumented constructors. Each class now declares the same constructor explicitly, with a doc comment; the API and behaviour are unchanged (`dart_apitool` below). Coverage is 100% in all seven packages |
| `///` comments only; no Javadoc tags (`@param`, `@return`, ...); keywords in backticks, not brackets; no parentheses in links | Pass | A scan of every `///` block under `lib/` found none |
| First paragraph is one sentence that ends with a period | Fixed | The same scan found 25 summaries that ran on into a second sentence, ended in a colon or had no period (`FormSession.close`, `DartRosaConfig.lastSavedSrc`, `collectFormConfig`, `withEntities`, `XPathExpressionExt.toQuery`, token and control-type enum values, ...); each now has a one-sentence summary and a separate paragraph |
| Methods start with a third-person verb, booleans with "Whether" | Fixed | One "Gets ..." summary (`OpenRosaXmlFetcher.getXml`) now reads "Fetches ..." |
| Public documentation doesn't refer to internal plans | Fixed | `FormDefinition` mentioned "Phase 6" of the porting plan; removed |
| `[references]` resolve | Pass | `dart doc --dry-run` in each package: 0 warnings, 0 errors (dartdoc reports unresolved references as warnings) |
| Every public library has a library doc comment on `library;` | Pass | All ten public libraries: `dartrosa.dart`, `javarosa.dart`, `testing.dart` (dartrosa), `dartrosa_calendars.dart`, `dartrosa_collect.dart`, `dartrosa_encryption.dart`, `dartrosa_entities.dart`, `dartrosa_external_data.dart`, `testing.dart` (external_data), `dartrosa_openrosa.dart`. Out-of-library references use `@docImport` |
| Code examples on the main entry points | Fixed | New ```` ```dart ```` examples on the `dartrosa` library, `FormDefinition`, `FormSession`, `FormNavigator`, `DartRosaConfig`, `AnswerResult`; the `dartrosa_calendars` library and `CustomCalendar`; `collectFormConfig`; `encryptSubmission`; `withEntities`; `OpenRosaClient`. The existing examples (`dartrosa_encryption` and `dartrosa_openrosa` libraries, `ExternalDataPlugin`, `LastSaved`, `FastExternalItemsetsPlugin`, `bind`) were completed where they referred to undefined values and reformatted |
| Code examples are tested | Fixed | Each package has `test/docs/api_examples_test.dart`, which contains every ```` ```dart ```` block of its `lib/` doc comments and runs it (with assertions on the printed output where the example prints). `packages/dartrosa/test/docs/api_docs_test.dart` fails if a doc-comment block is not, line for line, in a doc test, or if an entry point above loses its example. This extends the existing check for `docs/*.md` (`doc_snippets.dart`) to the API docs |
| Code fences are labelled | Pass | Every fence in `lib/` is ```` ```dart ```` |

Why inline examples rather than dartdoc's `{@example}` directive (the
`dart-use-doc-examples` skill): inline blocks show in IDE hovers as well
as on pub.dev, and the repository already enforces "every snippet is in a
running test" for its guides, so the same mechanism now covers the API
docs. The trade-off is that the example appears twice (doc comment and
test); `api_docs_test.dart` keeps the copies identical.

## Effective Dart: usage and library structure

| Item | Status | Evidence |
| --- | --- | --- |
| Implementation under `lib/src/`, public libraries at the top of `lib/` | Pass | Every package: only the libraries listed above sit in `lib/`, everything else is in `lib/src/` |
| One public library per entry point | Pass | `dartrosa` has three by design: the session API (`dartrosa.dart`), the JavaRosa-compatible API (`javarosa.dart`) and test support (`testing.dart`); `dartrosa_external_data` has its main library and `testing.dart` |
| No imports of another package's `src/` from `lib/` | Pass | `implementation_imports` (recommended lints); `grep -rl "package:dartrosa[a-z_]*/src/" packages/*/lib`: none. Tests import their own package's `src/` for white-box tests, which is allowed |
| Export hygiene | Pass | `dartrosa.dart` narrows its exports with `show`/`hide` (for example it hides `nodeAtIndex`, `rootNode` and `bindAttributeValue` from `form_node.dart`); the other libraries export whole `src` files that contain only public API |
| Types used in public signatures are exported | Flagged | An analyzer script (walks every exported declaration's signatures, supertypes and members) found 12 types that appear in public API but are not exported by any public library of their package: `SubmissionProfile` (`FormDef.submissionProfile`, `defaultSubmission`, `addSubmissionProfile`), `ReferenceContext` (`TreeReference.contextType`, `withContextType`), `TreeReferenceLevel` (`TreeReference.levels`), `LocaleDataSource` (`Localizer.registerLocaleResource`), the private `_GeoPointsValue` supertype of `GeoTraceValue` and `GeoShapeValue` (dartrosa); `BasicChronology` (`JodaCalendar.chronology`), `BsCalendar` (`BikramSambatCalendar.calendar`), `MyanmarDate` (`MyanmarCalendar.fromMyanmarDate`) (dartrosa_calendars). Users can get values of these types but not name them. Recommendation: export them (an additive, non-breaking change) in the next feature release, or make the members private if they were not meant to be public |

## Effective Dart: design

| Item | Status | Evidence |
| --- | --- | --- |
| Closed result and node hierarchies are `sealed` | Pass | `AnswerResult`, `FinalizeResult`, `FormNode`, `ContainerNode`, `CustomCalendar`; their cases are `final` |
| Class modifiers on public classes | Flagged | 16 public classes have no class modifier, so they can be extended and implemented anywhere: `FormEntryPrompt`, `FormEntryCaption`, `FormInstance`, `QuestionDef`, `XPathException`, `XPathNodeset`, and the abstract `Action`, `DataInstance`, `FormElement`, `FormLoadPlugin`, `RangeHint`, `SetGeopointAction`, `XPathFunctionHandler` (dartrosa); `ExternalDataHandler`, `ExternalDataException` (dartrosa_external_data); `FormUploadException` (dartrosa_openrosa). Most are JavaRosa-compatible API that plugins subclass (`FormLoadPlugin`, `XPathFunctionHandler`, `Action`), so `base` or `abstract base` may be the right modifier rather than `final`. Adding a modifier is a breaking change: consider it for 0.2.0. All other class declarations under `lib/` (about 355) have a modifier (`final`, `sealed`, `base`, `interface` or `abstract final`) |
| Immutable configuration and values | Pass | `DartRosaConfig` has a `const` constructor, `final` fields and `copyWith`; answer values (`StringValue`, `IntegerValue`, ...) and results are immutable with `const` constructors |
| `const` constructors where possible | Flagged | A heuristic (all instance fields `final`, a public generative constructor that is not `const`) lists 45 engine constructors and 48 in the other packages. Sampled: most compute in their initializers or bodies (`DateValue` rounds the date, `GeoPointValue` copies its list, `XPathQName` validates), so they can't be `const`; a few could (`XFormParseException`, `KText`). Adding `const` is additive; optional |
| No boolean traps in public API | Flagged | The session API has none (for example `FormSession.answer(index, value, {validate})`). Four positional `bool` parameters exist, all in the JavaRosa-compatible API and kept for parity with JavaRosa signatures: `BooleanValue(b)` (a value wrapper, acceptable), `TreeElement([name, multiplicity, isPartial])` (also exposes private parameter names `_name`, `_multiplicity`, `_isPartial` in the docs), `TreeElement.setEnabled(enabled)` and `XPathEqExpr(equal, a, b)`. Changing them would break the API; left alone |
| Dependencies are injected, not global | Pass | Configuration goes through `DartRosaConfig`; JavaRosa's global `ReferenceManager` singleton is an ordinary object here |
| Named parameters for optional and configuration arguments | Pass | Entry points take named parameters (`FormDefinition.parse(xml, {config})`, `createSession({existingInstance, language})`, `collectFormConfig({media, ...})`, `withEntities(base, {entitiesRepository, ...})`); `always_put_required_named_parameters_first` is enabled |

## pub.dev package layout and scoring

| Item | Status | Evidence |
| --- | --- | --- |
| README: title, description, install, usage with code, links to the API docs and guides | Fixed | Every README had a title, description, `dart pub add`, an example and links to the guides. Added: pub.dev version and pub points badges, CI and license badges, and an "API reference" link (`https://pub.dev/documentation/<package>/latest/`) |
| README code is correct and tested | Fixed | Each package's `test/docs/readme_example.dart` holds the README program verbatim (plus the declarations its placeholders stand for) and `api_examples_test.dart` runs it; `api_docs_test.dart` fails if a README block is not in a doc test or in `example/example.dart`. Two README programs were reformatted with `dart format` to keep the copies identical |
| CHANGELOG: newest version first, one `## <version>` heading per release | Pass | `## 0.1.1` added above `## 0.1.0` in every package |
| A meaningful example in `example/example.dart` | Pass | Each package's example runs end to end (`dart run example/example.dart`); each is now also run by its `api_examples_test.dart` |
| pubspec: name, description (60 to 180 characters), version, homepage, repository, issue tracker | Pass | Descriptions are 126 to 150 characters; `homepage`, `repository` (package subdirectory) and `issue_tracker` are set in all seven |
| pubspec: topics (at most 5, valid names) | Pass | Five topics each, for example `odk`, `xforms`, `forms`, `data-collection`, `xpath` |
| pubspec: `documentation`, `funding` | N/A | pub.dev links the generated API docs itself; no funding link wanted |
| pubspec: `false_secrets` | N/A | `dart pub publish --dry-run` reports no potential secrets (the encryption test material is a public key) |
| Platform support | Pass | pana tags every package `platform:android`, `ios`, `linux`, `macos`, `windows`, `web` and `is:wasm-ready`; `tool/check_core_purity.dart` keeps `dart:io` and Flutter out of `lib/`; CI runs the tests with dart2js and dart2wasm |
| SDK constraint | Pass | `sdk: ^3.10.0` in every package, the workspace's lower bound; pana's checks for the current SDK and for dependency lower bounds pass |
| Dependency constraints allow the latest versions | Pass | `dart pub outdated --no-dev-dependencies --up-to-date`: every direct dependency resolves to its latest version (`xml: ">=6.5.0 <8.0.0"`, `http: ^1.2.0`, `pointycastle: ^4.0.0`, ...) |
| No unnecessary dependencies | Fixed | `dartrosa_encryption` declared `meta` and `dartrosa_external_data` declared `collection` without importing them; both removed. Every other dependency is imported from `lib/` (and every dev dependency from `test/`, `example/` or `benchmark/`) |
| LICENSE recognized | Pass | pana: `license:apache-2.0`, `license:osi-approved` |
| API docs coverage of at least 20% | Fixed | 98.9 to 100% before, 100% in every package after (table above) |
| `analysis_options.yaml` in the published package | N/A | The packages use the repository's root `analysis_options.yaml`, which is not published; pana analyzes with its own options and gives 50/50. Not required |

## Semantic versioning

| Item | Status | Evidence |
| --- | --- | --- |
| No breaking API changes compared with the published 0.1.0 | Pass | `dart_apitool diff --old pub://<package>/0.1.0 --new <export of HEAD>` for each package: "No changes detected" for `dartrosa`, `dartrosa_calendars`, `dartrosa_collect`, `dartrosa_entities` and `dartrosa_openrosa` (the explicit constructors are the same API as the implicit ones); `dartrosa_encryption` and `dartrosa_external_data` report only "Package dependency removed" (`meta`, `collection`), a patch-level change |
| Version bump matches the change | Pass | 0.1.1 (patch): documentation, examples, tests and metadata only. The sibling constraints (`dartrosa: ^0.1.0`, ...) still match |

## Verification

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 0 changed |
| `dart analyze --fatal-infos` (root) | No issues found |
| `dart run tool/license_headers.dart --check` | every file has a header |
| `dart run tool/check_core_purity.dart` | passed |
| `python3 tool/check_docs.py` | links resolve |
| Tests, `TZ=UTC` and `TZ=America/New_York` | all pass in all seven packages (engine: 3,702 tests; also `TZ=Asia/Kolkata`) |
| Engine line coverage (`tool/check_coverage.dart`, minimum 90%) | 92.07% |
| `dart doc --dry-run`, each package | 0 warnings, 0 errors |
| `dart pub publish --dry-run`, each package | 0 warnings |
| pana, each package (clean export of HEAD) | 160/160 |

## How to reproduce

```sh
# Style, analysis, headers
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart run tool/license_headers.dart --check
dart run tool/check_core_purity.dart

# Per package (from packages/<package>)
dart doc --dry-run
dart pub publish --dry-run
TZ=UTC dart test && TZ=America/New_York dart test

# pana, on a clean export of a package
tmp=$(mktemp -d)
git archive HEAD packages/<package> | tar -x -C "$tmp"
sed -i '' '/^resolution: workspace/d' "$tmp/packages/<package>/pubspec.yaml"
dart pub global run pana --no-warning "$tmp/packages/<package>"

# API changes against the published version (from an export as above)
dart pub global activate dart_apitool
dart pub global run dart_apitool:main diff \
  --old pub://<package>/0.1.0 --new "$tmp/packages/<package>" \
  --version-check-mode=onlyBreakingChanges

# Dependencies
dart pub outdated --no-dev-dependencies --up-to-date
```

The `resolution: workspace` line is removed from the exported pubspec
because pana resolves an isolated package; the published package resolves
the same way. The scans for doc-comment style, unexported types, class
modifiers, `const` candidates and positional `bool` parameters were
one-off scripts (a regular-expression scan of `///` blocks and an
analyzer-based walk of each package's exported API); their findings are
listed above.
