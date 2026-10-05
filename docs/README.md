# DartRosa documentation

**Audience:** everyone; start here to find the right document.

The documents are grouped by what they are for, following
ISO/IEC/IEEE 26514: concepts explain, guides walk through a task, and
reference material is for looking things up. Each document states its
audience at the top. Terms are defined in the [glossary](GLOSSARY.md).

## Start here

| If you are... | Read |
|---|---|
| New to ODK, XForms or DartRosa, and not necessarily a programmer | [Overview](OVERVIEW.md) |
| A developer about to use DartRosa | [Getting started](GETTING_STARTED.md), then the guides below |
| Moving Java code from JavaRosa | [Migrating from JavaRosa](MIGRATING_FROM_JAVAROSA.md) |
| Checking whether your forms and platforms are supported | [Compatibility](COMPATIBILITY.md) |
| Reviewing quality, standards or licensing | [Standards](STANDARDS.md), [Benchmarks](BENCHMARKS.md), [Legal](legal/README.md) |
| Contributing to DartRosa | [Architecture](ARCHITECTURE.md), the [conformance docs](#conformance) and the [porting plan](development/PORTING_PLAN.md) |

## Concepts

| Document | Audience | Contents |
|---|---|---|
| [OVERVIEW.md](OVERVIEW.md) | Anyone | What ODK, XForms and DartRosa are, the problem they solve, the journey of a form, screenshots |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Integrators, contributors | The packages and their dependencies, the engine's internals, the two APIs, how correctness is checked |

## Guides (how-to)

| Document | Audience | Task |
|---|---|---|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Developers | Install, parse a form, answer, repeats, languages, drafts, finalize, show it in Flutter |
| [guides/render-a-form-in-flutter.md](guides/render-a-form-in-flutter.md) | Flutter developers | Show a downloaded form with its media, connect device features, theme and translate the interface |
| [guides/save-and-resume-drafts.md](guides/save-and-resume-drafts.md) | Developers | Save drafts, autosave, resume, finalize, edit finalized submissions |
| [guides/encrypt-and-submit.md](guides/encrypt-and-submit.md) | Developers | Download forms from ODK Central, encrypt and upload submissions over OpenRosa |
| [guides/external-data-and-entities.md](guides/external-data-and-entities.md) | Developers | CSV choice lists, `pulldata()`, `search()`, entities |
| [guides/non-gregorian-calendars.md](guides/non-gregorian-calendars.md) | Form designers, developers | Ethiopian, Persian, Nepali and other calendars |
| [PLUGINS.md](PLUGINS.md) | Developers extending the engine | Custom XPath functions, processors, secondary instances, how the Collect packages plug in |

## Reference

| Document | Audience | Contents |
|---|---|---|
| [COMPATIBILITY.md](COMPATIBILITY.md) | Developers, form designers | Every supported XForms feature, XPath function, appearance and platform, with the conformance evidence |
| [MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md) | Java developers | JavaRosa class to Dart class map, behavioural differences, what is not ported |
| [STANDARDS.md](STANDARDS.md) | Technical leads, reviewers | Specifications implemented (ODK XForms, XPath, Entities, OpenRosa, ISO 8601) and quality standards (ISO/IEC 25010, ISO/IEC/IEEE 26514, WCAG 2.1) |
| [BENCHMARKS.md](BENCHMARKS.md) | Developers, maintainers | Performance targets, results, method, how to reproduce |
| [GLOSSARY.md](GLOSSARY.md) | Everyone | Terms used in the documentation |
| API reference | Developers | Run `dart doc` in a package (published on pub.dev once the packages are released) |
| Package READMEs | Developers | Install and a short example for each package: [dartrosa](../packages/dartrosa/README.md), [dartrosa_flutter](../packages/dartrosa_flutter/README.md), [dartrosa_collect](../packages/dartrosa_collect/README.md), [dartrosa_external_data](../packages/dartrosa_external_data/README.md), [dartrosa_entities](../packages/dartrosa_entities/README.md), [dartrosa_encryption](../packages/dartrosa_encryption/README.md), [dartrosa_openrosa](../packages/dartrosa_openrosa/README.md), [dartrosa_calendars](../packages/dartrosa_calendars/README.md) |
| [legal/README.md](legal/README.md) | Legal and compliance reviewers | Licences, notices, SPDX and OpenChain |

## Conformance

| Document | Audience | Contents |
|---|---|---|
| [conformance/TRACE_FORMAT.md](../conformance/TRACE_FORMAT.md) | Contributors | The JSON traces recorded from JavaRosa and how they are compared |
| [conformance/DEVIATIONS.md](../conformance/DEVIATIONS.md) | Developers, contributors | Every intentional difference from JavaRosa and why |

## Development history

| Document | Audience | Contents |
|---|---|---|
| [development/PORTING_PLAN.md](development/PORTING_PLAN.md) | Maintainers | The original porting plan: design decisions, the JavaRosa inventory, compatibility traps. Historical; not kept in step with the code |

## Keeping the documentation correct

Every Dart code block in `docs/*.md` and `docs/guides/*.md` must appear
in a test under `packages/*/test/docs/`, which compiles and runs it;
`packages/dartrosa/test/docs/all_docs_test.dart` fails otherwise. The
diagrams in `images/` are hand-written SVG, except `benchmarks.svg`
(drawn by `packages/dartrosa/benchmark/render_chart.dart`). The renderer
screenshots in `images/screenshots/` are produced by
`packages/dartrosa_flutter/test/screenshots/screenshots_test.dart`.
