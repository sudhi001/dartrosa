# Glossary

**Audience:** everyone reading the DartRosa documentation. **Type:**
reference.

The documentation uses these terms with these meanings. Where a term has
a Dart counterpart, it is given in parentheses.

**AOT, JIT.** Two ways of running Dart code. AOT (ahead-of-time) compiles
to machine code before running, as Flutter release builds and
`dart compile exe` do. JIT (just-in-time) compiles while running, as
`dart run` and `dart test` do. Benchmarks use AOT.

**Appearance.** A hint in the form about how to show a question: for
example `minimal` (a drop-down instead of radio buttons), `multiline`,
`ethiopian` (an Ethiopian-calendar date picker) or `field-list` (a group
shown on one screen). The engine passes appearances through
(`FormNode.appearance`); the renderer interprets them.

**Attachment.** A file a submission refers to, such as a photo or a
recording. Uploaded together with the submission.

**Audit log.** A record of what the person did while filling a form
(questions visited, answers changed, locations), requested by the form's
`meta/audit` field. Provided by `dartrosa_collect` (`FormAudit`).

**Bind.** A `<bind>` element in the XForm that attaches rules to a field:
its data type and its relevance, required, read-only, constraint and
calculation expressions.

**Calculation.** A bind's `calculate` expression: the field's value is
computed from other answers and recomputed when they change.

**Choice filter.** An expression that limits a select's choices based on
earlier answers (`[region = /data/region]`), producing cascading selects.

**Collect layer.** The DartRosa packages that port ODK Collect features
outside JavaRosa: `dartrosa_external_data`, `dartrosa_entities`,
`dartrosa_collect`, `dartrosa_encryption`, `dartrosa_openrosa` and
`dartrosa_calendars`.

**Conformance corpus.** The 401 test forms in `conformance/forms`, taken
from JavaRosa, ODK Collect, ODK Web Forms and pyxform, plus DartRosa's
own. Both engines run them and the results must match.

**Constraint.** A bind's `constraint` expression that an answer must
satisfy (`. >= 18`), with an optional message (`jr:constraintMsg`). A
violation gives `AnswerConstraintViolated`.

**DartRosa.** This project: a Dart port of JavaRosa plus the Collect
layer and a Flutter renderer.

**Delegate.** An object the app gives the Flutter renderer to reach
device features it can't provide itself: camera, location, barcode
scanner, maps, external apps (`XFormDelegates`).

**Draft.** A saved, unfinished filling of a form: the instance XML,
including hidden answers. Reopened with
`createSession(existingInstance: ...)`.

**Entity, entity list.** A record (a household, a patient) that forms
create or update and later forms read, managed by ODK Central. An entity
list (or dataset) is all records of one kind. See the
[ODK Entities spec](https://getodk.github.io/xforms-spec/entities).
Provided by `dartrosa_entities`.

**Field-list.** The `field-list` appearance on a group: all its questions
on one screen in a one-question-per-screen interface.

**Finalize.** Declaring a filled form complete: every required question
and constraint is checked and the submission is produced
(`FormSession.finalize()`, which returns `FinalizeSuccess` or
`FinalizeFailure`).

**Form definition.** A parsed form, ready to be filled
(`FormDefinition`; in the JavaRosa-compatible API, `FormDef`).

**Form list, manifest.** The OpenRosa documents that list a server's
forms and, for each form, its media files.

**Fuzz walk.** A conformance run that answers a form with random but
seeded (repeatable) values, to cover combinations the test forms don't
spell out.

**Group.** Questions kept together, optionally with a label, a relevance
condition or an appearance (`GroupNode`).

**Hint, guidance hint.** Help text under a question's label. A guidance
hint is longer help shown on request or always, depending on the app's
setting.

**Instance.** The data of one filling of a form, as an XML tree: the
answers. The primary (or main) instance is the form's own data; a
secondary instance is extra read-only data the form uses, such as a CSV
list of choices (`jr://file-csv/towns.csv`), an XML or GeoJSON file, an
entity list or the last saved instance.

**instanceID.** The unique id of a submission (`uuid:...`), kept in
`meta/instanceID`. An edited submission gets a new one and keeps the old
one in `meta/deprecatedID`.

**Itemset.** Choices for a select that come from an instance (often a
secondary instance) rather than being listed in the form.

**Itext.** The XForm's translations: the text of labels, hints and
choices in each language, plus media (images, audio, video) per
language. The language names are often written with an ISO 639 code,
such as `French (fr)`.

**JavaRosa.** The Java XForms engine behind ODK Collect, maintained by
the ODK project. DartRosa ports version 6.0.0.

**JavaRosa-compatible API.** `package:dartrosa/javarosa.dart`: the Dart
version of JavaRosa's classes (`FormDef`, `FormEntryController`,
`FormEntryPrompt`, `XFormParser`, ...), for porting Java code. See
[MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md).

**Last-saved instance.** The previously saved filling of the same form
(`jr://instance/last-saved`), used to pre-fill answers. Provided by
`dartrosa_collect` (`LastSaved`).

**Media file.** A file downloaded with a form: images and audio in
labels, CSV and XML files for choices and lookups.

**Navigator.** A cursor over the form with ODK Collect's
one-question-per-screen rules: it skips hidden questions, enters groups
and repeats, and stops at "add another?" prompts (`FormNavigator`).

**ODK.** Open Data Kit, the open-source project that makes ODK Collect,
ODK Central, ODK Web Forms, JavaRosa, pyxform and the XForms and XLSForm
specifications. See [getodk.org](https://getodk.org).

**ODK Central.** ODK's server: it publishes forms, manages entity lists
and receives and decrypts submissions.

**ODK Collect.** ODK's Android app for filling forms, built on JavaRosa.

**OpenRosa.** The HTTP protocol between form apps and servers: form
lists, manifests, downloads and submission upload. Implemented by
`dartrosa_openrosa`. See the [OpenRosa
specification](https://docs.getodk.org/openrosa/).

**Oracle.** Real JavaRosa 6.0.0, run on the Java virtual machine by
`conformance/jvm_oracle`, whose recorded behaviour is the reference
DartRosa must reproduce.

**Plugin.** Code that extends form loading or evaluation through
`DartRosaConfig`: custom XPath functions, parse and finalization
processors, instance providers, `FormLoadPlugin`s. See
[PLUGINS.md](PLUGINS.md).

**Preload.** A value filled in automatically when a form starts or is
finalized (`jr:preload`): start and end time, today's date, a device
property, a unique id.

**pulldata().** An ODK Collect function that looks up a value in a CSV
media file or an entity list:
`pulldata('fruits', 'price', 'name', ${fruit})`.

**pyxform.** ODK's converter from XLSForm to XForm. Built into ODK
Central and XLSForm Online.

**Relevance.** A bind's `relevant` expression: when false, the question
(or group) is hidden and its answer is left out of the submission.

**Renderer.** The user interface that draws a form and collects answers.
DartRosa's is `dartrosa_flutter` (`XFormView`).

**Repeat, repeat instance.** A group of questions the person can fill
several times, such as one block per household member (`RepeatNode`).
Each filling is a repeat instance (`RepeatInstanceNode`).

**Required.** A bind's `required` expression: when true, the question
must be answered before moving on or finalizing (`AnswerRequired`
otherwise).

**ResourceResolver.** The interface through which the engine reads
media and secondary instance files (`jr://file/...`). The app implements
it on its storage; the engine never opens files itself.

**Scenario.** A conformance test that applies a fixed sequence of
actions to a form and records the result. Also the name of JavaRosa's
test driver, ported in `package:dartrosa/testing.dart`.

**search().** An ODK Collect appearance that takes a select's choices
from a CSV media file. Provided by `dartrosa_external_data`.

**Select one, select multiple.** Questions answered by choosing one
choice, or any number of choices, from a list (`select1` and `select`
in XForms).

**Session.** One filling of a form, from start to finalize
(`FormSession`).

**Session API.** `package:dartrosa/dartrosa.dart`: the Dart-style API
(`FormDefinition`, `FormSession`, `FormNavigator`, the `FormNode` tree,
sealed result types). Recommended for new code.

**Submission.** The finished, finalized answers as XML, with their
attachments, ready to upload (`Submission`). Hidden answers are left
out.

**Trace.** A JSON file recording what the oracle did with one form
(structure, values, events, submission). See
[conformance/TRACE_FORMAT.md](../conformance/TRACE_FORMAT.md).

**Triggerable, dependency graph.** A triggerable is a bind expression
that must be recomputed when what it reads changes (a calculation,
relevance, required or read-only condition). The dependency graph
(`TriggerableDag`) orders them so each change recomputes exactly what
depends on it.

**XForm.** A form written in the XML format defined by the
[ODK XForms specification](https://getodk.github.io/xforms-spec/), a
profile of W3C XForms 1.1. This is what DartRosa reads.

**XLSForm.** A spreadsheet format for writing forms: one row per
question, with columns for type, name, label, rules and appearance. See
[xlsform.org](https://xlsform.org). Converted to an XForm by pyxform.

**XPath.** The expression language used in XForms for calculations,
conditions and references to fields (`/data/age >= 18`,
`count(/data/member)`). DartRosa implements XPath 1.0 with ODK's
functions.
