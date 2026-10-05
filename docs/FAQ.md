# FAQ and troubleshooting

**Audience:** developers using DartRosa, and anyone helping them debug a
form. **Type:** reference (questions and answers).

Can't find your problem here? Search the
[issues](https://github.com/sudhi001/dartrosa/issues) or open one with
the form (or a trimmed copy) and what you expected. For questions about
form design itself, the [ODK forum](https://forum.getodk.org) is the
place: DartRosa behaves like ODK Collect, so their answers apply.

* [General](#general)
* [Parse errors](#parse-errors)
* [Why is a question hidden?](#why-is-a-question-hidden)
* [Constraint and required messages](#constraint-and-required-messages)
* [Dates, times and time zones](#dates-times-and-time-zones)
* [Files, drafts and submissions](#files-drafts-and-submissions)
* [The web](#the-web)
* [Performance](#performance)

## General

**Does DartRosa read XLSForm spreadsheets?** No. It reads XForms, the
XML that pyxform, XLSForm Online and ODK Central produce from a
spreadsheet. Convert first; the
[tutorial](tutorials/build-a-data-collection-app.md#2-convert-and-publish-it)
shows three ways.

**Will my form behave as in ODK Collect?** Yes, for everything the
engine does: DartRosa is a port of JavaRosa 6.0.0 (Collect's engine) and
is checked against JavaRosa itself on 401 forms, with identical results
down to the submission XML. Collect features outside the engine (entities,
`pulldata()`, audit logs, encryption, the widgets) are ported in the
other packages. [COMPATIBILITY.md](COMPATIBILITY.md) lists what is
supported and the [known gaps](COMPATIBILITY.md#known-gaps).

**Do I need Flutter?** No. `dartrosa` and the Collect packages are pure
Dart: they run on servers, the command line and the web. Only
`dartrosa_flutter` needs Flutter.

**Does it work with KoboToolbox, ODK Aggregate or my own server?** Any
OpenRosa server works with `dartrosa_openrosa`; pass a username and
password to `InMemoryServerCredentialsSettings` for servers with
accounts. See [Encrypt and submit](guides/encrypt-and-submit.md).

**Why does `createSession` close my other session?** A
`FormDefinition` backs one session at a time, as a JavaRosa `FormDef`
does. Finish one filling before starting the next, or parse the form
twice to fill two copies side by side.

## Parse errors

Wrap opening a form so the person gets a message instead of a crash:

```dart
/// Opens a form, or explains why it can't be opened.
Future<FormSession?> tryOpen(
  String xml,
  void Function(String message) showError,
) async {
  try {
    final definition = await FormDefinition.parse(xml);
    return definition.createSession();
  } on XFormParseException catch (e) {
    // Not XML, a question bound to a missing node, a cycle in the logic...
    showError("This form can't be opened: ${e.message}");
  } on XPathException catch (e) {
    // An expression that can't be read or run.
    showError('This form has an error: ${e.message}');
  } on Exception catch (e) {
    // A calculation failing when the form starts (an unknown function,
    // a missing secondary instance): TriggerableEvaluationException.
    showError('This form has an error: $e');
  }
  return null;
}
```

The messages are JavaRosa's, so they match what Collect shows and what
the ODK forum discusses.

| Message | Usual cause | Fix |
|---|---|---|
| `XML Syntax Error at Line: 1, Column: ...` | Not an XForm: the `.xlsx` itself, or an HTML page (a login page, an error page) saved instead of the form | Convert the spreadsheet; check the download's status and content type |
| `Question bound to non-existent node: [/data/x]` | The body refers to a node missing from the main instance, usually after hand-editing; or a secondary `<instance>` placed before the main one | Regenerate with pyxform; the main instance must be the first `<instance>` in `<model>` |
| `Cycle detected in form's relevant and calculation logic!` | Two calculations (or relevances) that depend on each other; the message lists the nodes | Break the loop; pyxform's validator catches most cycles |
| `bind for /data/x contains invalid constraint expression [...]` | An XPath syntax error (a missing operand, unbalanced brackets) | Fix the expression in the XLSForm |
| `cannot handle function 'name'` | A function that is not in the ODK spec, a typo, or a custom function you haven't registered | Check the spelling; register custom functions ([recipe](cookbook/add-an-xpath-function.md)); `pulldata()` needs `ExternalDataPlugin` or `withEntities` |
| `Instance referenced by instance(x)/... does not exist` | A secondary instance that is not declared | Declare it (pyxform does for `select_one_from_file` and `pulldata`) |

## Why is a question hidden?

Check, in this order:

1. **Its relevance, or a group's.** `node.isRelevant` is false when the
   question's own `relevant` expression or any enclosing group's is
   false. `session.root.visibleChildren` (and the renderer) skip it.
2. **Empty values in the expression.** An unanswered question is an
   empty string: `${age} > 18` is false while `age` is empty, and
   `${a} + ${b}` is NaN when either is empty. Use `coalesce(${a}, 0)` or
   test `${age} != ''` first. The [ODK docs](https://docs.getodk.org/form-logic/)
   list the usual traps.
3. **It is not a question.** A `calculate` row has no body control, so it
   is never shown; read its value from the instance or the submission.
4. **Its choices are empty.** A select with no choices shows only its
   label. A CSV list the resolver didn't find becomes an empty list (the
   form still opens); make your `ResourceResolver` serve
   `jr://file-csv/<name>.csv`, and check the `choice_filter` against
   the current answers.
5. **You are reading an old node.** Nodes are views of the session's
   state: read `session.root` again after answering.

## Constraint and required messages

* `AnswerConstraintViolated.message` is the form's `constraint_message`
  in the current language, or `null` when the form has none; the
  renderer then shows "Sorry, this response is not valid.". Required
  questions use `required_message`, or "Sorry, this response is
  required!". Both defaults come from `XFormLocalizations`, which you
  can translate.
* Constraints are checked only when there is a value: an empty answer
  passes the constraint and is caught by `required` instead.
* `AnswerRejected` is different: the value is of the wrong type (text
  for an integer) or is not one of the choices. It is never saved.
* With `validate: false` a value is stored without checks (drafts);
  `finalize()` checks everything again.

## Dates, times and time zones

* Dates are local midnights in the device's time zone and times are read
  in that zone, as in JavaRosa. A submission contains the date
  (`2026-10-05`) and date-times with the device's offset.
* `today()`, `now()` and the `start`/`end` metadata use the device clock;
  in tests, fix the zone with `TZ=UTC dart test` and "now" with
  `withClock` from `package:clock`.
* Around daylight saving changes, a local time that doesn't exist moves
  forward and an ambiguous one takes the earlier instant, as Joda-Time
  does in Collect.
* Month and day names from `format-date-time` (`%b`, `%a`) are in
  English, as in JavaRosa with an English JVM.
* Ethiopian, Persian, Nepali and other calendars:
  [Non-Gregorian calendars](guides/non-gregorian-calendars.md).

## Files, drafts and submissions

* **My photo isn't in the upload.** The renderer stores a captured
  file's *name* as the answer; the file itself is yours. Keep the files
  your delegates save, and pass the ones `submission.attachments` names
  as `attachments` to `InstanceUpload.forForm`, as the
  [tutorial](tutorials/build-a-data-collection-app.md#8-finalize-and-encrypt)
  does. `Submission.attachments` lists the file names answered to media
  questions (image, audio, video, file, signature, drawing) that are in
  the submission; answers to hidden questions are left out.
* **My capture button is missing.** Override the matching `can...`
  getter of your `XFormDelegates` (`canCaptureMedia`, `canLocate`, ...)
  to return `true`; see the
  [device recipe](cookbook/device-features.md).
* **A draft opens empty or fails.** Open it with the same form version
  it was saved with; keep old form versions while drafts exist.
* **Hidden answers are in my draft.** By design: `saveDraft()` keeps
  every value, so nothing is lost if a question becomes relevant again.
  The finalized submission leaves them out.
* **New entities don't show up in the next form.** Entities are saved
  only into lists the repository already has (downloaded from the
  server); see [CSV lists and entities](cookbook/csv-and-entities.md#2-know-the-entity-list).

## The web

DartRosa runs on the web (dart2js and dart2wasm, both tested in CI),
with a few things to know:

* **No file system.** Implement `ResourceResolver` on `fetch`, Flutter
  assets or IndexedDB to serve form media.
* **Big integers.** Integers are JavaScript numbers under dart2js: exact
  only up to 2^53. dart2wasm has 64-bit integers.
* **Servers and CORS.** A browser can only call servers that allow your
  site's origin; check your server's CORS settings, or go through your
  own backend.
* **Device features** go through your `XFormDelegates`, using plugins that
  support the web (image_picker does, for example).
* `regex()` uses JavaScript-style regular expressions on every platform
  (Java-only syntax such as possessive quantifiers is rejected).

## Performance

* **Parse once.** Parsing is the expensive step (about 40 ms for 1,000
  questions on a desktop, a few times that on a mid-range phone); keep
  the `FormDefinition` and create sessions from it.
* **Answering is fast**: recomputing everything that depends on an answer
  takes well under a millisecond on a 1,000-question form
  ([benchmarks](BENCHMARKS.md)).
* **Keep `widgetOverrides` stable.** Build the map once (a constant or a
  field); a new map on every build rebuilds every question.
* **Large CSV lists.** Filtering 100,000 rows takes a few milliseconds;
  for very large lists, `dartrosa_collect`'s fast external itemsets and a
  persistent `ExternalDataRepository` avoid re-importing files.
* **Very large repeats** (hundreds of instances, with `position()` or
  `count()` in calculations) slow down as they grow, as in Collect;
  split them across forms or use entities.
* Measure in profile or release mode: debug builds of Flutter are
  several times slower.
