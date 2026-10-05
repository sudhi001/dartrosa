# Competitive analysis: form libraries and how they document themselves

**Audience:** maintainers deciding what DartRosa's documentation needs.
**Type:** analysis. **Date:** October 2026 (sources checked then).

This page compares DartRosa with the form libraries and platforms a
developer is likely to consider instead, and with how each documents
itself. It ends with the documentation changes made as a result and
those left for later. Facts about other projects come from the pages
listed under [Sources](#sources); version numbers and statuses change,
so check them before quoting.

## The field

Two groups of projects compete for the same developers:

* **Flutter form libraries** (flutter_form_builder, reactive_forms,
  formz with flutter_bloc). Forms are written in Dart code. They are what
  a Flutter developer finds first on pub.dev, but they have no form
  standard, no server and no offline data-collection model.
* **Data-collection platforms and schema renderers** (ODK Collect, ODK
  Web Forms, Enketo, KoboToolbox, SurveyJS, Form.io, React JSON Schema
  Form). Forms are data (XForms, JSON), designed by non-programmers and
  rendered by an engine. None of them targets Flutter or Dart.

DartRosa sits between them: an ODK XForms engine, verified against
JavaRosa, in pure Dart, with a Flutter renderer.

## Comparison

| Project | Scope | Form standard | Offline | Platforms | Validation model | Theming |
|---|---|---|---|---|---|---|
| **DartRosa** | XForms engine, Collect features (entities, encryption, OpenRosa) and a Flutter renderer | ODK XForms (from XLSForm) | Yes: the engine needs no network; drafts, entities and encryption work offline | Dart VM, AOT, web (dart2js, dart2wasm); Flutter on Android, iOS, web, desktop | Declarative in the form (required, constraint, relevance, calculate), evaluated synchronously on every answer; typed `AnswerResult` | `ThemeData` plus an `XFormTheme` extension; per-question widget overrides |
| flutter_form_builder 11.0 | Ready-made Flutter form fields | None (Dart code) | n/a (local UI) | Flutter | Synchronous validators in code (`form_builder_validators`) | Material `InputDecoration` |
| reactive_forms 18.2 | Model-driven forms, Angular style | None (Dart code; optional generator) | n/a | Flutter (all six platforms) | Sync and async validators in code, field and group level | Standard Flutter theming |
| formz + flutter_bloc | Input value objects plus state management | None (Dart code) | n/a | Flutter | Synchronous, per input, held in bloc state | Standard Flutter theming |
| SurveyJS Form Library | JSON survey renderer, plus a commercial form builder | Custom JSON | Not covered by the library docs (bring your own storage) | Web (React, Angular, Vue, plain JS) | Declarative validators in JSON; error, warning and info severities; server-side hooks | Design tokens, Theme Editor, adapters for Bootstrap, MUI, shadcn |
| ODK Web Forms | Vue renderer and XForms engine for ODK Central; the default for new forms since Central v2026.2 (the standalone repository is archived, development continues in Central's frontend) | ODK XForms | Not yet (listed as upcoming) | Web | Declarative in the form | PrimeVue components |
| Enketo | Web forms for OpenRosa servers (Core, Express, Transformer) | ODK XForms | Yes (offline-capable web app) | Web | Declarative in the form | Grid, Formhub and Plain themes |
| ODK Collect | Android data-collection app | ODK XForms | Yes | Android | Declarative in the form | Appearances only |
| KoboToolbox | Data-collection platform (Formbuilder, KoboCollect, web forms) | XLSForm / XForms | Yes (KoboCollect, Enketo) | Android, web | Declarative in the form | Platform-defined |
| Form.io | JSON form renderer, builder and backend | Custom JSON components | With a paid offline plugin | Web | Declarative per component, custom JavaScript | Bootstrap templates, custom templates |
| React JSON Schema Form 6.11 | Forms generated from JSON Schema | JSON Schema plus `uiSchema` | n/a | Web (React) | Pluggable validator (AJV), live or on submit, custom and server errors | Theme packages for MUI, antd, Chakra, shadcn and others |

### Documentation features

| Project | Quick start | Concepts | Tutorial | Cookbook / recipes | Component catalog | Playground / live demo | API reference | Migration guides | FAQ / troubleshooting |
|---|---|---|---|---|---|---|---|---|---|
| **DartRosa (before)** | README snippet, Getting started | Overview, Architecture | Getting started | 5 guides | Screenshots only | Example app (build it yourself) | dartdoc on pub.dev | From JavaRosa | No |
| **DartRosa (now)** | 5-minute quick start | Concepts page with diagram | End-to-end app tutorial | 9 recipes plus the guides | Widget catalog (in progress) | Example app | dartdoc, plus an API tour by task | From JavaRosa | FAQ and troubleshooting |
| flutter_form_builder | README | No | No | No | No | pub.dev Example tab | dartdoc | Inline in README | No |
| reactive_forms | Long README with a table of contents | In the README | No | README sections | No | No | dartdoc | GitHub wiki | No |
| formz + flutter_bloc | bloclibrary.dev | Yes | Login tutorial, layer by layer, full source with tests | Examples repo | No | No | dartdoc | Yes | No |
| SurveyJS | Per framework | Yes | Yes | Feature pages | Question types | Gallery of 100+ live demos with JSON and code tabs | Yes | Yes | Yes |
| ODK Web Forms | README | No | No | No | No | No | No | No | Feature matrix of supported XForms features |
| Enketo | Install guide | XForms notes | No | No | Showcase forms per widget | Live showcase forms | API pages | No | FAQ |
| ODK Collect | Yes | Form logic pages with "gotchas" | "First form" | Form design pages | Question-type catalog with XLSForm rows and appearances | No | n/a | No | Troubleshooting pages |
| KoboToolbox | Getting started | Glossary of 60+ terms | Yes | Knowledge base | Question-type table | No | REST API docs | No | Yes; docs in English, Spanish and French |
| Form.io | Getting started | Yes | Tutorials and videos | Examples | Components | Builder sandbox and JSFiddles | Yes | Premium library changes | Yes |
| RJSF | Yes | Usage and customization | No | Advanced customization | Widgets | Playground with editable schema panes and permalinks | Yes | One per major version (2.x to 6.x) | Partly |

The Flutter cookbook format (docs.flutter.dev) is the reference for
recipes: an imperative title, a short "why", "This recipe uses the
following steps:" with a numbered list, one action per numbered heading
with a small snippet, and a complete example at the end.

## What DartRosa does better

* **A form standard, verified.** The Flutter libraries have no standard:
  every form is code a developer writes and maintains. DartRosa runs the
  XLSForms that ODK and KoboToolbox projects already use, and is checked against JavaRosa itself on 401 forms with zero
  differences, submission XML included. No other renderer in the
  comparison publishes conformance evidence of this kind; ODK Web Forms
  publishes a feature matrix.
* **Offline by construction.** The engine is synchronous and needs no
  network; drafts, entities (create and update before upload) and
  encryption all work offline. ODK Web Forms lists offline as upcoming,
  SurveyJS leaves storage to the app, and Form.io sells offline as a paid
  plugin.
* **Pure Dart.** The same engine validates on the phone, on the server
  and in the browser (dart2js and dart2wasm), and forms can be
  unit-tested in milliseconds. Schema renderers on the web need a
  separate server-side validator to get the same guarantee.
* **Collect features beyond rendering:** entities, `pulldata()` and
  `search()`, audit logs, last-saved values, edited submissions,
  non-Gregorian calendars, and encryption that ODK Central and Briefcase
  decrypt.
* **Documentation that can't rot.** Every Dart snippet in the guides is
  compiled and run by a test, and links are checked in CI. None of the
  compared projects says it does this.

## Gaps

| Gap | Seen in | Status |
|---|---|---|
| No short path from zero to a form on screen | flutter.dev, SurveyJS | Done: [QUICKSTART.md](../QUICKSTART.md) |
| No page explaining the model (definition, session, nodes, rules) for app developers | bloclibrary.dev, SurveyJS | Done: [CONCEPTS.md](../CONCEPTS.md) |
| No end-to-end tutorial from XLSForm to the server | bloclibrary.dev, ODK "first form" | Done: [the tutorial](../tutorials/build-a-data-collection-app.md) |
| Task-sized recipes | docs.flutter.dev cookbook | Done: [the cookbook](../cookbook/README.md) |
| FAQ and troubleshooting (parse errors, hidden questions) | ODK Collect, Enketo, KoboToolbox | Done: [FAQ.md](../FAQ.md) |
| Finding the class for a task | RJSF, Form.io | Done: [API_TOUR.md](../API_TOUR.md) |
| A learning path on the index page | docs.flutter.dev, bloclibrary.dev | Done: [docs/README.md](../README.md) |
| Component catalog with screenshots per question type and appearance | ODK Collect, Enketo showcase | In progress in a separate change: `docs/widgets/README.md` |
| An interactive playground (paste an XForm, see it rendered and the submission) | RJSF, SurveyJS, Form.io | Deferred: the example app compiled to Flutter web, hosted on GitHub Pages, would do it |
| Versioned docs and one migration guide per major version | RJSF, reactive_forms | Deferred until a breaking release; CHANGELOGs cover 0.x |
| Translated documentation | KoboToolbox, bloclibrary.dev | Deferred |
| Built-in camera, GPS, map implementations | ODK Collect | Out of scope for docs; the renderer relies on delegates (see the [device recipe](../cookbook/device-features.md)) |

## Recommendations

### Implemented in this change

1. **A learning path** on the documentation index and the root README:
   quick start, concepts, tutorial, cookbook, reference, troubleshooting,
   with a diagram ([learning-path.svg](../images/learning-path.svg)).
2. **A five-minute quick start** whose app is run by a widget test.
3. **A concepts page** for app developers (definition and session, nodes,
   relevance, required and constraints, answer types, repeats, languages,
   changes, drafts) with a diagram
   ([form-model.svg](../images/form-model.svg)).
4. **An end-to-end tutorial**: XLSForm, conversion with Central or
   pyxform, download, load, fill and validate, drafts, finalize,
   encrypt, submit, test; with a diagram
   ([tutorial-app.svg](../images/tutorial-app.svg)) and code run against
   a fake ODK Central.
5. **Nine cookbook recipes** in the Flutter cookbook format: custom
   widget, theming (light and dark, brand colors, `maxContentWidth`),
   translations and right-to-left, device delegates, pager or scroll or
   outline, custom XPath function, CSV and entities, server-side
   validation, testing forms.
6. **FAQ and troubleshooting** with the engine's real error messages
   (each produced by a test), why a question is hidden, constraint
   messages, time zones, the web, performance.
7. **An API tour** mapping tasks to classes, linked to pub.dev's API
   documentation (links checked to resolve).
8. **Doc tests for the new folders**: `docs/tutorials` and
   `docs/cookbook` are included in the snippet check, which fails if any
   Dart block there isn't compiled by a test.
9. **Root README**: pub.dev version badges and the learning-path links.

### Deferred

* **Playground**: build `packages/dartrosa_flutter/example` for the web
  and publish it on GitHub Pages, with a "paste your XForm" screen
  showing the rendered form and the submission XML. Highest-value item
  left; RJSF and SurveyJS show how much a playground lowers the cost of
  trying a library.
* **Widget catalog**: being produced in a separate change; the index,
  the cookbook and the API tour already link to `docs/widgets/README.md`.
* **Versioned docs and per-major migration guides** once 1.0 ships.
* **Video walkthrough and translated docs**, for field teams.
* **A "feature matrix" view** of COMPATIBILITY.md in the style of ODK Web
  Forms (supported, partial, not supported, per XLSForm feature).

## Sources

* flutter_form_builder: <https://pub.dev/packages/flutter_form_builder>,
  <https://github.com/flutter-form-builder-ecosystem/flutter_form_builder>
* reactive_forms: <https://pub.dev/packages/reactive_forms>,
  <https://github.com/joanpablo/reactive_forms>
* formz and flutter_bloc: <https://bloclibrary.dev/tutorials/flutter-login/>,
  <https://github.com/felangel/bloc/tree/master/examples>
* Flutter cookbook format: <https://docs.flutter.dev/cookbook/forms/validation>
* SurveyJS: <https://surveyjs.io/form-library/documentation/overview>,
  <https://surveyjs.io/form-library/documentation/data-validation>,
  <https://surveyjs.io/form-library/examples/overview>
* ODK Web Forms: <https://github.com/getodk/web-forms>,
  <https://docs.getodk.org/web-forms-intro/>,
  <https://forum.getodk.org/t/odk-central-v2025-1-form-drafts-visual-redesign-pagination-web-forms-and-entity-deletion/54899>
* Enketo: <https://enketo.org/>, <https://enketo.org/develop/>,
  <https://github.com/enketo/enketo>
* ODK Collect: <https://docs.getodk.org/collect-intro/>,
  <https://docs.getodk.org/form-logic/>,
  <https://docs.getodk.org/form-question-types/>
* KoboToolbox: <https://support.kobotoolbox.org/>,
  <https://support.kobotoolbox.org/question_types.html>
* Form.io: <https://help.form.io/>, <https://github.com/formio/formio.js>,
  <https://help.form.io/dev/form-development/form-renderer>,
  <https://help.form.io/dev/offline-mode>
* React JSON Schema Form: <https://rjsf-team.github.io/react-jsonschema-form/docs/>,
  <https://rjsf-team.github.io/react-jsonschema-form/docs/usage/validation>,
  <https://rjsf-team.github.io/react-jsonschema-form/>,
  <https://rjsf-team.github.io/react-jsonschema-form/docs/migration-guides/v6.x%20upgrade%20guide>
