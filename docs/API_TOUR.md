# API tour

**Audience:** developers who know what they want to do and need the
class that does it. **Type:** reference.

Each row names a task, the class or function for it, and its package.
Names link to the API documentation on pub.dev. The
[concepts page](CONCEPTS.md) explains how the pieces fit together.

| Package | Library to import | API documentation |
|---|---|---|
| `dartrosa` | `package:dartrosa/dartrosa.dart` (session API), `javarosa.dart` (JavaRosa API), `testing.dart` | [pub.dev/documentation/dartrosa](https://pub.dev/documentation/dartrosa/latest/) |
| `dartrosa_flutter` | `package:dartrosa_flutter/dartrosa_flutter.dart` (re-exports `dartrosa.dart`) | [pub.dev/documentation/dartrosa_flutter](https://pub.dev/documentation/dartrosa_flutter/latest/) |
| `dartrosa_openrosa` | `package:dartrosa_openrosa/dartrosa_openrosa.dart` | [pub.dev/documentation/dartrosa_openrosa](https://pub.dev/documentation/dartrosa_openrosa/latest/) |
| `dartrosa_encryption` | `package:dartrosa_encryption/dartrosa_encryption.dart` | [pub.dev/documentation/dartrosa_encryption](https://pub.dev/documentation/dartrosa_encryption/latest/) |
| `dartrosa_entities` | `package:dartrosa_entities/dartrosa_entities.dart` | [pub.dev/documentation/dartrosa_entities](https://pub.dev/documentation/dartrosa_entities/latest/) |
| `dartrosa_external_data` | `package:dartrosa_external_data/dartrosa_external_data.dart` | [pub.dev/documentation/dartrosa_external_data](https://pub.dev/documentation/dartrosa_external_data/latest/) |
| `dartrosa_collect` | `package:dartrosa_collect/dartrosa_collect.dart` | [pub.dev/documentation/dartrosa_collect](https://pub.dev/documentation/dartrosa_collect/latest/) |
| `dartrosa_calendars` | `package:dartrosa_calendars/dartrosa_calendars.dart` | [pub.dev/documentation/dartrosa_calendars](https://pub.dev/documentation/dartrosa_calendars/latest/) |

The API documentation follows the latest published version; classes
added in an unreleased version (the outline and `XFormWindowSize` of
`dartrosa_flutter` 0.2.0, marked below) appear there once it is published. Until then,
run `dart doc` in the package.

## Load a form

| Task | Use | Package |
|---|---|---|
| Parse an XForm | [`FormDefinition.parse`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormDefinition-class.html) | dartrosa |
| Configure parsing: media, functions, plugins, device properties | [`DartRosaConfig`](https://pub.dev/documentation/dartrosa/latest/dartrosa/DartRosaConfig-class.html) | dartrosa |
| Serve form media (`jr://file/...`) | [`ResourceResolver`](https://pub.dev/documentation/dartrosa/latest/dartrosa/ResourceResolver-class.html), [`MapResourceResolver`](https://pub.dev/documentation/dartrosa/latest/dartrosa/MapResourceResolver-class.html) | dartrosa |
| Device id, username for `property()` and metadata | [`MapPropertyManager`](https://pub.dev/documentation/dartrosa/latest/dartrosa/MapPropertyManager-class.html) | dartrosa |
| Handle a broken form | [`XFormParseException`](https://pub.dev/documentation/dartrosa/latest/dartrosa/XFormParseException-class.html), [`XPathException`](https://pub.dev/documentation/dartrosa/latest/dartrosa/XPathException-class.html) | dartrosa |
| Cache a parsed form | [`FormDefCodec`](https://pub.dev/documentation/dartrosa/latest/javarosa/FormDefCodec-class.html) | dartrosa (`javarosa.dart`) |

## Fill a form

| Task | Use | Package |
|---|---|---|
| Start, resume, change language | [`FormDefinition.createSession`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormDefinition/createSession.html), [`FormSession`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession-class.html) | dartrosa |
| Read the form as a tree | [`FormNode`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormNode-class.html), [`QuestionNode`](https://pub.dev/documentation/dartrosa/latest/dartrosa/QuestionNode-class.html), [`GroupNode`](https://pub.dev/documentation/dartrosa/latest/dartrosa/GroupNode-class.html), [`RepeatNode`](https://pub.dev/documentation/dartrosa/latest/dartrosa/RepeatNode-class.html) | dartrosa |
| Walk it screen by screen, like Collect | [`FormNavigator`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormNavigator-class.html), [`FormEntryEvent`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormEntryEvent.html) | dartrosa |
| Answer a question | [`FormSession.answer`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession/answer.html) with an [`AnswerValue`](https://pub.dev/documentation/dartrosa/latest/dartrosa/AnswerValue-class.html) | dartrosa |
| Know whether the answer was accepted | [`AnswerResult`](https://pub.dev/documentation/dartrosa/latest/dartrosa/AnswerResult-class.html) | dartrosa |
| Add or remove repeat instances | [`FormSession.addRepeatInstance`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession/addRepeatInstance.html) | dartrosa |
| React to recalculations | [`FormSession.changes`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession/changes.html), [`FormChange`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormChange-class.html) | dartrosa |
| Save a draft | [`FormSession.saveDraft`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession/saveDraft.html) | dartrosa |
| Validate everything and get the submission | [`FormSession.finalize`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormSession/finalize.html), [`Submission`](https://pub.dev/documentation/dartrosa/latest/dartrosa/Submission-class.html) | dartrosa |

## Show a form in Flutter

| Task | Use | Package |
|---|---|---|
| Show a session | [`XFormView`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormView-class.html), [`XFormMode`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormMode.html) | dartrosa_flutter |
| Open the outline, jump to a question | `XFormViewState`, `XFormOutlineMode` (0.2.0) | dartrosa_flutter |
| Camera, GPS, barcodes, maps, external apps | [`XFormDelegates`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormDelegates-class.html) | dartrosa_flutter |
| Spacing, cards, maximum width | [`XFormTheme`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormTheme-class.html) | dartrosa_flutter |
| Translate buttons and messages | [`XFormLocalizations`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormLocalizations-class.html) | dartrosa_flutter |
| Replace a question widget | [`QuestionWidgetBuilder`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/QuestionWidgetBuilder.html), [`XFormScope`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormScope-class.html), [`XFormController`](https://pub.dev/documentation/dartrosa_flutter/latest/dartrosa_flutter/XFormController-class.html) | dartrosa_flutter |
| Layout by window size | `XFormWindowSize` (0.2.0) | dartrosa_flutter |

What each question type looks like: the [widget catalog](widgets/README.md).

## Talk to a server

| Task | Use | Package |
|---|---|---|
| Form list, form and media downloads | [`OpenRosaClient`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/OpenRosaClient-class.html) | dartrosa_openrosa |
| HTTP with Collect's headers and Digest auth | [`HttpClientConnection`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/HttpClientConnection-class.html), [`WebCredentialsUtils`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/WebCredentialsUtils-class.html) | dartrosa_openrosa |
| Prepare a submission (encrypted if the form has a key) | [`InstanceUpload.forForm`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/InstanceUpload-class.html) | dartrosa_openrosa |
| Upload it | [`OpenRosaInstanceUploader`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/OpenRosaInstanceUploader-class.html) | dartrosa_openrosa |
| Handle upload failures | [`FormUploadException`](https://pub.dev/documentation/dartrosa_openrosa/latest/dartrosa_openrosa/FormUploadException-class.html) | dartrosa_openrosa |
| Encrypt without uploading | [`encryptSubmission`](https://pub.dev/documentation/dartrosa_encryption/latest/dartrosa_encryption/encryptSubmission.html) | dartrosa_encryption |

## Data and Collect features

| Task | Use | Package |
|---|---|---|
| Entities (create, update, offline lists) | [`withEntities`](https://pub.dev/documentation/dartrosa_entities/latest/dartrosa_entities/withEntities.html), [`saveFormEntities`](https://pub.dev/documentation/dartrosa_entities/latest/dartrosa_entities/saveFormEntities.html), [`EntitiesRepository`](https://pub.dev/documentation/dartrosa_entities/latest/dartrosa_entities/EntitiesRepository-class.html), [`LocalEntityUseCases`](https://pub.dev/documentation/dartrosa_entities/latest/dartrosa_entities/LocalEntityUseCases-class.html) | dartrosa_entities |
| `pulldata()` and `search()` over CSV media | [`ExternalDataPlugin`](https://pub.dev/documentation/dartrosa_external_data/latest/dartrosa_external_data/ExternalDataPlugin-class.html) | dartrosa_external_data |
| Collect's form setup: last-saved, fast itemsets, edits | [`collectFormConfig`](https://pub.dev/documentation/dartrosa_collect/latest/dartrosa_collect/collectFormConfig.html), [`LastSaved`](https://pub.dev/documentation/dartrosa_collect/latest/dartrosa_collect/LastSaved-class.html), [`InstanceEdit`](https://pub.dev/documentation/dartrosa_collect/latest/dartrosa_collect/InstanceEdit-class.html) | dartrosa_collect |
| Audit log | [`AuditEventLogger`](https://pub.dev/documentation/dartrosa_collect/latest/dartrosa_collect/AuditEventLogger-class.html) | dartrosa_collect |
| Ethiopian, Persian, Nepali and other dates | [library](https://pub.dev/documentation/dartrosa_calendars/latest/dartrosa_calendars/) | dartrosa_calendars |

## Extend and test

| Task | Use | Package |
|---|---|---|
| A custom XPath function | [`XPathFunctionHandler`](https://pub.dev/documentation/dartrosa/latest/javarosa/XPathFunctionHandler-class.html) | dartrosa (`javarosa.dart`) |
| Hook into loading and finalizing | [`FormLoadPlugin`](https://pub.dev/documentation/dartrosa/latest/dartrosa/FormLoadPlugin-class.html), `parseProcessors`, `finalizationProcessors` of `DartRosaConfig` ([PLUGINS.md](PLUGINS.md)) | dartrosa |
| The JavaRosa classes (`FormDef`, `FormEntryController`, ...) | [`javarosa` library](https://pub.dev/documentation/dartrosa/latest/javarosa/) | dartrosa |
| Test forms | [`Scenario`](https://pub.dev/documentation/dartrosa/latest/testing/Scenario-class.html) and the form-building DSL | dartrosa (`testing.dart`) |

## Where to go next

* By task, with code: the [cookbook](cookbook/README.md).
* By feature: [COMPATIBILITY.md](COMPATIBILITY.md).
* From Java: [MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md).
