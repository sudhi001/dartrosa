# Getting started with DartRosa

**Audience:** developers new to DartRosa (Dart or Flutter). **Type:**
tutorial. Terms are explained in the [glossary](GLOSSARY.md).

DartRosa fills [ODK XForms](https://getodk.github.io/xforms-spec/) in pure
Dart: it parses a form, keeps its calculations, relevance, constraints and
repeats up to date while you answer, and produces the submission XML, with
the same results as JavaRosa (the engine of ODK Collect).

This guide walks through the session API (`package:dartrosa/dartrosa.dart`)
and then the Flutter renderer. Every Dart snippet below is run by
`packages/dartrosa/test/docs/getting_started_test.dart` and
`packages/dartrosa_flutter/test/docs/getting_started_test.dart`, so it
compiles and does what it says.

- New to ODK and XForms? Read the [overview](OVERVIEW.md) first.
- Porting code from JavaRosa? See [MIGRATING_FROM_JAVAROSA.md](MIGRATING_FROM_JAVAROSA.md).
- What is supported: [COMPATIBILITY.md](COMPATIBILITY.md).
- Custom functions, entities, CSV data, ...: [PLUGINS.md](PLUGINS.md).

## 1. Install

```sh
dart pub add dartrosa
```

For Flutter, run `flutter pub add dartrosa_flutter` instead; it
re-exports `dartrosa`. The engine
needs Dart 3.10 or later and has no Flutter or `dart:io` dependency, so
it also runs on servers, the command line and the web (dart2js and
dart2wasm).

XForms are usually written as XLSForms and converted with
[pyxform](https://github.com/XLSForm/pyxform), XLSForm Online or ODK
Central; DartRosa reads the resulting XML.

## 2. Parse a form

The examples use this form (two languages, a required question, a
constraint, a select, a repeat and an `instanceID`):

```xml
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household survey</h:title>
    <model>
      <itext>
        <translation lang="English" default="true()">
          <text id="name"><value>Your name</value></text>
          <text id="age"><value>Your age</value></text>
          <text id="consent"><value>Do you agree?</value></text>
        </translation>
        <translation lang="Français">
          <text id="name"><value>Votre nom</value></text>
          <text id="age"><value>Votre âge</value></text>
          <text id="consent"><value>Êtes-vous d'accord ?</value></text>
        </translation>
      </itext>
      <instance>
        <data id="household">
          <name/><age/><consent/>
          <member jr:template=""><member_name/></member>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 18"
          jr:constraintMsg="You must be an adult"/>
      <bind nodeset="/data/consent" type="select1"/>
      <bind nodeset="/data/member/member_name" type="string"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label ref="jr:itext('name')"/></input>
    <input ref="/data/age"><label ref="jr:itext('age')"/></input>
    <select1 ref="/data/consent">
      <label ref="jr:itext('consent')"/>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <group ref="/data/member">
      <label>Members</label>
      <repeat nodeset="/data/member">
        <input ref="/data/member/member_name"><label>Name</label></input>
      </repeat>
    </group>
  </h:body>
</h:html>
```

`FormDefinition.parse` is asynchronous because secondary instances
(`jr://file/...xml`, `jr://file-csv/...csv`, GeoJSON) are read through the
config's `ResourceResolver`. Everything after parsing is synchronous.

```dart
final definition = await FormDefinition.parse(
  formXml,
  config: DartRosaConfig(
    // Reads jr://file/... form media and secondary instances.
    resolver: MapResourceResolver({
      'jr://file/towns.csv': Uint8List.fromList(
        utf8.encode('name,label\nnbo,Nairobi\n'),
      ),
    }),
    // Device properties for jr:preload="property" and property().
    properties: MapPropertyManager({'deviceid': 'my-app:1234'}),
  ),
);
```

`DartRosaConfig` is immutable and holds everything JavaRosa keeps in
globals (resolver, custom functions, parser and finalization processors,
plugins); see [PLUGINS.md](PLUGINS.md). Implement `ResourceResolver` on
your file system, assets or cache; `MapResourceResolver` serves bytes
from memory. Malformed forms throw `XFormParseException`; XPath errors in
the form throw the `XPathException` family.

```dart
final title = definition.title; // 'Household survey'
final languages = definition.languages; // ['English', 'Français']
final session = definition.createSession();
```

## 3. Read the form as a tree

`session.root` is the form as a tree of `FormNode`s, a sealed hierarchy:
`RootNode`, `GroupNode`, `RepeatNode` (with its `instances`),
`RepeatInstanceNode` and `QuestionNode`. Nodes are views of the current
state: read them again after answering. This builds an outline of the
relevant nodes:

```dart
// An outline of the form tree, one line per node.
List<String> outline(FormNode node, [String indent = '']) => [
  switch (node) {
    QuestionNode(:final label, :final value) =>
      '$indent${label.text}: ${value?.displayText ?? '-'}',
    RepeatNode(:final instances) =>
      '$indent[repeat, ${instances.length} instances]',
    RepeatInstanceNode(:final position) => '$indent[instance $position]',
    GroupNode(:final label) => '$indent${label.text}',
    RootNode(:final label) => '${label.text}',
  },
  if (node is ContainerNode)
    for (final child in node.visibleChildren) ...outline(child, '$indent  '),
  if (node is RepeatNode)
    for (final instance in node.instances) ...outline(instance, '$indent  '),
];
```

A `QuestionNode` has everything a widget needs: `label` (a `LocalizedText`
with `text`, `short`, `image`, `bigImage`, `audio`, `video`), `hint`,
`guidanceHint`, `controlType`, `dataType`, `appearance`, `choices`,
`choiceLabel(choice)`, `value`, `displayValue`, `isRequired`,
`isReadonly`, `isRelevant`, `constraintMessage`, `requiredMessage`,
`bindAttributes` and `attributes` (unhandled attributes such as
`orx:max-pixels` or `rows`). `session.changes` is a stream of
`FormChange`s (answers, recalculated values, relevance, repeats, language)
for UIs that rebuild only what changed.

## 4. Or walk it with the navigator

`session.navigator` is a cursor with JavaRosa's `FormEntryController`
semantics: it skips non-relevant nodes, enters groups and repeat
instances, and stops at "add another?" prompts. Use it for
one-question-per-screen UIs.

```dart
final nav = session.navigator;
for (
  var event = nav.next();
  event != FormEntryEvent.endOfForm;
  event = nav.next()
) {
  switch (event) {
    case FormEntryEvent.question:
      final question = nav.current as QuestionNode;
      labels.add(question.label.text);
    case FormEntryEvent.promptNewRepeat:
      // "Add another member?": nav.addRepeatAndEnter() adds one; next()
      // declines.
      break;
    default:
      // Groups and repeat instances.
      break;
  }
}
```

`nav.previous()`, `nav.jumpTo(index)`, `nav.jumpToBeginning()`,
`nav.jumpToEnd()` and `nav.position` (a `FormIndex`) complete it.
`nav.current` is the `FormNode` at the cursor.

## 5. Answer questions

`session.answer(index, value)` checks `required` and the constraint and
returns a sealed `AnswerResult`. Only `AnswerAccepted` saves the value;
calculations, relevance and other questions update immediately.

```dart
final age = session.root.children[1] as QuestionNode;
final result = session.answer(age.index, const IntegerValue(16));
final message = switch (result) {
  AnswerAccepted() => 'Saved',
  AnswerRequired(:final message) => message ?? 'Sorry, this is required',
  AnswerConstraintViolated(:final message) => message ?? 'Invalid answer',
  AnswerRejected(:final message) => message, // wrong type, unknown choice
};
```

Here `message` is `'You must be an adult'`, the form's
`jr:constraintMsg` (in the current language). Values are `AnswerValue`s:
`StringValue`, `IntegerValue`, `LongValue`, `DecimalValue`,
`BooleanValue`, `DateValue`, `TimeValue`, `DateTimeValue`,
`SelectOneValue`, `MultipleItemsValue`/`SelectMultiValue`,
`GeoPointValue`, `GeoTraceValue`, `GeoShapeValue`, `PointerValue` (files)
and `UncastValue` (text, read as the question's type):

```dart
// Text is read as the question's type, as Collect's widgets do.
session.answer(age.index, const UncastValue('42')); // AnswerAccepted
session.answer(age.index, const UncastValue('forty')); // AnswerRejected

final consent = session.root.children[2] as QuestionNode;
session.answer(consent.index, const SelectOneValue(Selection('yes')));
final choices = [for (final c in consent.choices) c.value]; // yes, no

// A required question can't be cleared...
final name = session.root.children[0] as QuestionNode;
final cleared = session.answer(name.index, null); // AnswerRequired
// ...unless validation is skipped (as when leaving a draft).
session.answer(name.index, null, validate: false); // AnswerAccepted
```

`AnswerRejected` is never saved, even with `validate: false`: it means the
value can't be read as the question's data type, has another type, or is
not one of the choices (selects with a `search()` appearance take their
choices from CSV media and are not checked).

## 6. Repeats and languages

```dart
// pyxform wraps repeats in a group with the same ref; JavaRosa (and
// DartRosa) merge the two into the repeat.
final members = session.root.children[3] as RepeatNode;
final first = session.addRepeatInstance(members.index);
final instance = session.nodeAt(first) as RepeatInstanceNode;
final memberName = instance.children.single as QuestionNode;
session.answer(memberName.index, const StringValue('Amina'));
final count = members.instances.length; // 1
session.removeRepeatInstance(first);
```

`RepeatNode.canAddInstance` is false for repeats with a fixed `jr:count`
or `jr:noAddRemove`. `RepeatInstanceNode.header` is the instance's
caption (such as `Member 2/3`).

```dart
session.language = 'Français';
final label = session.root.children[0].label.text; // 'Votre nom'
```

`createSession(language: ...)` starts in a given language; labels, hints,
choice labels and constraint messages follow the current language.

## 7. Save a draft, resume, finalize

```dart
final draft = session.saveDraft(); // the instance XML, store it
await session.close();

// Later (a definition backs one session at a time):
final resumed = definition.createSession(existingInstance: draft);

switch (resumed.finalize()) {
  case FinalizeSuccess(:final submission):
    upload(submission.xml, submission.instanceId, submission.attachments);
  case FinalizeFailure(:final failure):
    // Show the first invalid question.
    resumed.navigator.jumpTo(failure.index);
}
```

- `saveDraft()` keeps every value, non-relevant ones included, like
  JavaRosa's saved instances. `createSession(existingInstance: xml)` also
  opens finalized submissions for editing (see `dartrosa_collect`'s
  `InstanceEdit` for `meta/deprecatedID`).
- A `FormDefinition` backs one session at a time: `createSession` resets
  it, so finish with one session before starting the next (parse again to
  fill two forms side by side).
- `finalize()` validates the whole form. On success it sets end
  timestamps, runs finalization processors (entities, edited
  submissions, ...) and returns a `Submission`: the XML without
  non-relevant nodes, the `instanceID` and the attachment file names.
  On failure, `failure.result` is `AnswerRequired` or
  `AnswerConstraintViolated` and `failure.index` locates the question.
- To upload to ODK Central or another OpenRosa server, see
  `dartrosa_openrosa`; to encrypt (forms with a `base64RsaPublicKey`),
  `dartrosa_encryption`.

## 8. Show it in Flutter

`dartrosa_flutter` renders a session with Material widgets, in a
Collect-like pager or a single scrolling page, rebuilding only the
questions whose state changed:

```dart
class FormScreen extends StatelessWidget {
  const FormScreen({required this.session, required this.onDone, super.key});

  final FormSession session;
  final ValueChanged<Submission> onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(session.definition.title ?? '')),
    body: XFormView(
      session: session,
      mode: XFormMode.pager, // or XFormMode.scroll
      // Camera, location, barcode, media in labels, external apps, ...
      // Without delegates, capture questions fall back to typing.
      delegates: const NoDelegates(),
      // Replace any question widget, by control type and appearance.
      widgetOverrides: {
        'selectOne:likert': (context, node) => const Text('My likert'),
      },
      onFinalized: onDone,
    ),
  );
}
```

Platform features (camera, location, barcode scanning, maps, external
apps, printing) go through your `XFormDelegates` subclass. Add an
`XFormTheme` to `ThemeData.extensions` to style it and register an
`XFormLocalizations` delegate to translate its buttons. See
[packages/dartrosa_flutter/README.md](../packages/dartrosa_flutter/README.md)
for the supported controls and appearances, and
`packages/dartrosa_flutter/example` for an app that fills, saves,
resumes and finalizes every form of the conformance corpus.

## Testing your forms

`package:dartrosa/testing.dart` has JavaRosa's `Scenario` and its XForm
builder DSL (`html`, `head`, `model`, `bind`, `input`, ...), so you can
test your own forms the way the engine is tested.

## Next steps

- [Show a form in a Flutter app](guides/render-a-form-in-flutter.md):
  media files, device features, theming and translations.
- [Save and resume drafts](guides/save-and-resume-drafts.md).
- [Download forms, encrypt and submit to ODK Central](guides/encrypt-and-submit.md).
- [Use CSV data and entities](guides/external-data-and-entities.md).
- [Use non-Gregorian calendars](guides/non-gregorian-calendars.md).
- [How DartRosa is built](ARCHITECTURE.md).
