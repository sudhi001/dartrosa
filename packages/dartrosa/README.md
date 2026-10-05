# dartrosa

A pure-Dart ODK XForms engine: a faithful port of
[JavaRosa](https://github.com/getodk/javarosa) 6.0.0, the engine behind
ODK Collect. It parses XForms, evaluates XPath, recalculates, validates,
handles repeats, secondary instances and translations, navigates like
Collect and serializes submissions byte-for-byte as JavaRosa does.

- No Flutter and no `dart:io`: runs on the VM, AOT, dart2js, dart2wasm and
  Flutter.
- Checked against real JavaRosa: about 400 conformance forms replayed
  against JavaRosa 6.0.0 traces (parse structure, initialization,
  recalculation, full walks, random-answer walks, submission XML).
- Three libraries:
  - `package:dartrosa/dartrosa.dart`: the session API (`FormDefinition`,
    `FormSession`, `FormNavigator`, the `FormNode` tree, sealed
    `AnswerResult` / `FinalizeResult`);
  - `package:dartrosa/javarosa.dart`: the JavaRosa-compatible API
    (`FormDef`, `FormEntryController`, `FormEntryPrompt`, `XFormParser`,
    XPath, plugin interfaces);
  - `package:dartrosa/testing.dart`: JavaRosa's `Scenario` and form-building
    DSL, for testing your own forms.

## Install

```sh
dart pub add dartrosa
```

## Example

```dart
import 'package:dartrosa/dartrosa.dart';

Future<void> main() async {
  final definition = await FormDefinition.parse(xform);
  final session = definition.createSession();

  final [name, age] = session.root.visibleChildren.cast<QuestionNode>();
  session.answer(name.index, const StringValue('Ada'));
  switch (session.answer(age.index, const IntegerValue(-3))) {
    case AnswerConstraintViolated(:final message):
      print('Rejected: $message');
    case AnswerAccepted() || AnswerRequired() || AnswerRejected():
      break;
  }
  session.answer(age.index, const UncastValue('42')); // text is parsed

  switch (session.finalize()) {
    case FinalizeSuccess(:final submission):
      print(submission.xml);
    case FinalizeFailure(:final failure):
      print('Invalid at ${failure.index.reference}');
  }
}
```

The complete program, with its form, is in
[example/example.dart](example/example.dart).

## Documentation

- [Documentation index](https://github.com/sudhi001/dartrosa/blob/main/docs/README.md)
- [Overview: what DartRosa is](https://github.com/sudhi001/dartrosa/blob/main/docs/OVERVIEW.md)
- [Save and resume drafts](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/save-and-resume-drafts.md)
- [Architecture](https://github.com/sudhi001/dartrosa/blob/main/docs/ARCHITECTURE.md)
- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)

Related packages: [dartrosa_flutter](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_flutter)
(renderer) and the ODK Collect layer:
[dartrosa_collect](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_collect),
[dartrosa_external_data](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_external_data),
[dartrosa_entities](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_entities),
[dartrosa_encryption](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_encryption),
[dartrosa_openrosa](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_openrosa),
[dartrosa_calendars](https://github.com/sudhi001/dartrosa/tree/main/packages/dartrosa_calendars).

## License

Apache License 2.0 (see [LICENSE](LICENSE)). DartRosa is a derivative
work of JavaRosa (Apache-2.0); see
[the licensing notes](https://github.com/sudhi001/dartrosa/blob/main/docs/legal/README.md).
