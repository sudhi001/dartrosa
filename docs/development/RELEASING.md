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

After publishing each package, check its page on pub.dev (score, API
docs, example) before publishing the next, and tag the release in Git:
`git tag <package>-v<version>` for each package, then `git push --tags`.

## Making the repository public

Done once, by the repository owner, in this order:

1. **Validate.** CI is green on `main`; `dart run tool/license_headers.dart
   --check`, `python3 tool/check_docs.py` and `reuse lint` pass; a secret
   scan of the full history finds only the allowlisted test key
   (`gitleaks git .`, configured by `.gitleaks.toml`).
2. **Review what becomes public:** the full Git history, including commit
   author names and email addresses, every file under `conformance/`
   (third-party forms, credited in NOTICE.md), and the issue tracker.
3. **Repository settings** (Settings → General): description ("Faithful
   Dart/Flutter port of the ODK JavaRosa XForms engine"), website, topics
   (`odk`, `xforms`, `dart`, `flutter`, `data-collection`), enable Issues,
   disable Wiki/Projects if unused.
4. **Change visibility** (Settings → General → Danger Zone → Change
   visibility → Public).
5. **Security** (Settings → Code security): enable private vulnerability
   reporting (SECURITY.md points to it), Dependabot alerts and security
   updates (`.github/dependabot.yml` configures version updates), secret
   scanning and push protection.
6. **Branch protection** for `main` (free for public repositories): require
   pull requests and the CI checks (`Dart`, `Flutter renderer`, `JavaRosa
   oracle traces`), block force pushes.
7. **Publish** the packages (sections above), then create a GitHub release
   for the version with the CHANGELOG entries as notes.
