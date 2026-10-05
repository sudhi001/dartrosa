# Validate submissions on the server

**Type:** recipe. **Package:** `dartrosa`.

The engine is pure Dart, with no Flutter and no `dart:io`, so it runs on
a server too (Dart Frog, Shelf, Cloud Run, a command-line job). That
lets a backend check submissions with exactly the rules the app used:
the same required questions, constraints, relevance and calculations,
evaluated by the same code. Use it for submissions that arrive from
somewhere other than your app (an import, an API), or to double-check
data before it enters your database.

This recipe checks a submission's XML against its form, using the
following steps:

1. Load the form, with a cache.
2. Open the submission and finalize it.
3. Report the first problem.

## The code

```dart
final _definitions = <String, Future<FormDefinition>>{};

/// The first problem of [submissionXml] against [formXml], or `null` if
/// the submission is valid.
Future<String?> validateSubmission(String formXml, String submissionXml) async {
  // Parse each form version once. A definition backs one session at a
  // time, so nothing below awaits between createSession and finalize.
  final definition = await _definitions.putIfAbsent(
    formXml,
    () => FormDefinition.parse(formXml),
  );
  final session = definition.createSession(existingInstance: submissionXml);
  switch (session.finalize()) {
    case FinalizeSuccess():
      return null;
    case FinalizeFailure(:final failure):
      final question = session.nodeAt(failure.index) as QuestionNode;
      final problem = switch (failure.result) {
        AnswerRequired(:final message) => message ?? 'is required',
        AnswerConstraintViolated(:final message) => message ?? 'is invalid',
        AnswerRejected(:final message) => message,
        AnswerAccepted() => 'is invalid',
      };
      return '${question.label.text}: $problem';
  }
}
```

For a submission with 40 household members, it returns
`How many people live here?: Between 1 and 29`.

## 1. Load the form, with a cache

Parsing is the expensive part; keep one `FormDefinition` per form
version. A definition backs one session at a time, and
`createSession` replaces the previous session. In a single isolate that
is safe as long as nothing awaits between `createSession` and the end of
the check, as above. To check in parallel, use one cache per isolate.

## 2. Open and finalize

`createSession(existingInstance: xml)` loads the submitted values, as
when resuming a draft. `finalize()` then validates every relevant
question, recomputes calculations and returns the first failure.

## 3. Report the problem

`failure.index` locates the question; its label and the form's own
messages make a readable error. To collect every problem rather than
the first, walk `session.root` and check each relevant `QuestionNode`
yourself.

## Things to know

* Hidden (non-relevant) answers are not validated, as in the app.
* Calculations are recomputed from the submitted answers, so a tampered
  calculated value is replaced, not trusted. Compare
  `submission.xml` with what you received if you want to detect it.
* Encrypted submissions must be decrypted first; the server needs the
  private key.
* Values like `now()` and `uuid()` change on every run; don't compare
  them.

## Related

* [Concepts: drafts and submissions](../CONCEPTS.md#drafts-and-submissions)
* [Test your forms](test-your-forms.md)
* [Benchmarks](../BENCHMARKS.md): parsing and validation times
