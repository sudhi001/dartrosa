# Releasing the packages

**Audience:** maintainers publishing DartRosa to pub.dev. **Type:** task.

The packages are not on pub.dev yet; until then apps depend on them from
Git (`path: packages/<name>`) or with `path:` dependencies. The
workspace packages already name their siblings with version constraints
(`^0.0.1`); inside the workspace they resolve to the local copies.

## Before publishing

1. Bump the versions of the packages being released and add their
   `CHANGELOG.md` entries, together.
2. Run the full verification: `dart format --output=none
   --set-exit-if-changed .`, `dart analyze --fatal-infos`,
   `dart run tool/check_core_purity.dart`, the package tests, and for the
   renderer `flutter analyze --fatal-infos` and `flutter test`.
3. Check the licensing material described in
   [legal/README.md](../legal/README.md).

## Order

Publish in dependency order, running `dart pub publish` in each package
(`flutter pub publish` for the renderer):

1. `dartrosa` and `dartrosa_calendars` (no sibling dependencies);
2. `dartrosa_external_data` and `dartrosa_encryption`;
3. `dartrosa_entities` (needs `dartrosa_external_data`) and
   `dartrosa_openrosa` (needs `dartrosa_encryption`);
4. `dartrosa_collect` (its dev dependencies, used by a docs test, include
   `dartrosa_entities`, and publishing resolves dev dependencies too);
5. `dartrosa_flutter`: first replace its `path:` dependencies (and its
   `dependency_overrides`) with version constraints and remove its
   `publish_to: none`; pub.dev rejects packages with path dependencies.

The dependency graph is drawn in [ARCHITECTURE.md](../ARCHITECTURE.md#packages).
