# dartrosa_collect

ODK Collect's form-filling services for
[DartRosa](https://github.com/sudhi001/dartrosa), ported from ODK Collect:

- **Audit log** (`meta/audit` with `odk:location-*`, `odk:track-changes`,
  `odk:identify-user`, `odk:track-changes-reasons`): `FormAudit`,
  `AuditEventLogger`, `AuditEventCsvWriter`.
- **Fast external itemsets** (`itemsets.csv` with a select's `query`
  attribute): `FastExternalItemsetsPlugin`.
- **Last-saved instance** (`jr://instance/last-saved`): `LastSaved` over a
  `LastSavedStore`.
- **Edited submissions**: `EditedFormFinalizationProcessor` and
  `InstanceEdit` move `meta/instanceID` to `meta/deprecatedID`.
- `collectFormConfig` wires all of these into a `DartRosaConfig` the way
  Collect's `FormLoaderTask` does.

Storage and platform services are interfaces the app implements;
in-memory implementations are included. Pure Dart (no `dart:io`).

## Install

Not on pub.dev yet; depend on it from Git, overriding its DartRosa
siblings to the same source:

```yaml
dependencies:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
  dartrosa_collect:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa_collect}
dependency_overrides:
  dartrosa:
    git: {url: https://github.com/sudhi001/dartrosa, path: packages/dartrosa}
```

## Example

```dart
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';

Future<void> main() async {
  final lastSaved = LastSaved(InMemoryLastSavedStore(), 'visit-v1');
  final config = collectFormConfig(
    media: MapResourceResolver(const {}), // the form's media files
    lastSaved: lastSaved,
  );

  final session = (await FormDefinition.parse(xform, config: config))
      .createSession();
  // ... answer questions ...
  final submission = (session.finalize() as FinalizeSuccess).submission;
  await lastSaved.instanceSaved(session); // pre-fills the next instance

  // Editing a finalized submission gives it a new instanceID.
  final edit = (await FormDefinition.parse(xform, config: config))
      .createSession(existingInstance: submission.xml);
  const InstanceEdit(editOf: 1).markSession(edit);
  print((edit.finalize() as FinalizeSuccess).submission.xml); // deprecatedID
}
```

See [example/example.dart](example/example.dart) for the complete program.

## Documentation

- [Documentation index](https://github.com/sudhi001/dartrosa/blob/main/docs/README.md)
- [Save and resume drafts](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/save-and-resume-drafts.md)
- [Use CSV data and entities](https://github.com/sudhi001/dartrosa/blob/main/docs/guides/external-data-and-entities.md)
- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports classes of
[ODK Collect](https://github.com/getodk/collect) (Apache-2.0); see
[the licensing notes](https://github.com/sudhi001/dartrosa/blob/main/docs/legal/README.md).
