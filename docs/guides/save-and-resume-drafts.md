# Save and resume drafts

**Audience:** developers of apps that fill forms with DartRosa (Flutter or
plain Dart). **Type:** how-to guide.

People rarely fill a long form in one go: the phone rings, the battery
runs low, the household asks the interviewer to come back tomorrow. A
draft keeps everything entered so far so the form can be reopened
exactly where it was. This guide saves drafts, saves them automatically,
reopens them and opens finalized submissions for editing.

Every Dart snippet below is run by
`packages/dartrosa/test/docs/drafts_guide_test.dart`.

## What a draft is

A draft is the form's instance (the answers) as XML text. `saveDraft()`
returns it and you store it wherever you keep data: a file, a database
row, secure storage. It keeps every value, including answers to
questions that are hidden at the moment (JavaRosa does the same), so
nothing is lost if the person changes an earlier answer and changes it
back. The finalized submission, by contrast, leaves hidden answers out.

Store the form's id and version with the draft: a draft can only be
reopened with the form it was made with. The version is in the draft's
root element (`<data id="visit" version="2">`).

## Save a draft

```dart
// Save when the person leaves the form or the app goes to the
// background, and keep it with the form's id and version.
drafts['visit-1'] = session.saveDraft();
await session.close();
```

`close()` releases the session. A `FormDefinition` backs one session at a
time: close one before you start the next, or parse the form again to
fill two side by side.

## Save automatically

`session.changes` is a stream of everything the engine changes. Saving
on each answer and each added or removed repeat instance means nothing
is lost even if the app is killed:

```dart
// Save after every answer and every added or removed repeat
// instance, so nothing is lost if the app is killed.
final subscription = session.changes
    .where((change) => change.kind == 'answer' || change.kind == 'repeat')
    .listen((_) => drafts['visit-1'] = session.saveDraft());
// ... and when the form is closed:
await subscription.cancel();
```

`saveDraft()` serializes the whole instance, which takes well under a
millisecond for typical forms; for very large forms, debounce the saves.

Some forms mark questions with `saveIncomplete="true()"` (the
`save_incomplete` column in XLSForm) to ask for a draft as soon as they
are answered, as ODK Collect does:

```dart
// Questions with saveIncomplete="true()" (XLSForm's save_incomplete
// column) ask the app to save a draft as soon as they are answered.
final result = session.answer(question.index, value);
if (result is AnswerAccepted && question.saveIncomplete) {
  drafts['visit-1'] = session.saveDraft();
}
```

## Resume

Parse the same form again and pass the draft as `existingInstance`. All
calculations and relevance conditions are recomputed from the saved
answers:

```dart
// Later, maybe after the app restarted: parse the form again and load
// the draft into a new session.
definition = await FormDefinition.parse(formXml);
final resumed = definition.createSession(
  existingInstance: drafts['visit-1'],
);
```

`createSession` also takes `language:` to reopen the form in the
language the person used.

## Finalize

When the person is done, `finalize()` checks every required question and
constraint. On success it returns the submission; on failure it says
which question needs attention (the Flutter renderer jumps there):

```dart
switch (resumed.finalize()) {
  case FinalizeSuccess(:final submission):
    // Non-relevant answers are left out of the submission.
    outbox.add(submission); // to upload
    drafts.remove('visit-1');
  case FinalizeFailure(:final failure):
    // Show the question that needs attention.
    resumed.navigator.jumpTo(failure.index);
}
```

`submission.xml` is what servers receive, `submission.instanceId` its
unique id (`uuid:...`) and `submission.attachments` the names of the
files it refers to. To send it, see
[Encrypt and submit](encrypt-and-submit.md).

## Edit a finalized submission

A finalized submission opens like a draft:

```dart
// A finalized submission opens like a draft.
final edit = definition.createSession(existingInstance: submission.xml);
```

ODK Collect gives an edited submission a new `instanceID` and records the
old one in `meta/deprecatedID`, so the server knows it replaces the
first. `dartrosa_collect` does this with `InstanceEdit`; see its
[README](../../packages/dartrosa_collect/README.md).

## Related

* [Show a form in a Flutter app](render-a-form-in-flutter.md)
* [Getting started](../GETTING_STARTED.md), section 7
* `dartrosa_collect`'s `LastSaved` pre-fills a new instance from the last
  saved one (`jr://instance/last-saved`); see [PLUGINS.md](../PLUGINS.md#how-the-collect-packages-compose)
