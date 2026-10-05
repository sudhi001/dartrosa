# Contributing to DartRosa

Thanks for your interest. DartRosa is a faithful Dart port of
[JavaRosa](https://github.com/getodk/javarosa), so the most important rule
is: **the engine must behave exactly like JavaRosa 6.0.0**, quirks
included. The conformance traces in `conformance/` are the contract.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Report security problems privately as described in [SECURITY.md](SECURITY.md).

## Before you start

- For anything larger than a small fix, open an issue first so we can
  agree on the approach.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and, for engine work,
  [conformance/TRACE_FORMAT.md](conformance/TRACE_FORMAT.md).

## Making a change

1. Fork the repository and create a branch.
2. Make the change with tests. Engine behaviour changes need a JavaRosa
   reference: a ported JavaRosa test, or a form whose oracle trace shows
   the behaviour (`conformance/jvm_oracle/oracle.sh batch conformance`
   regenerates the traces; CI fails if they are out of date).
3. Run the checks CI runs:

   ```sh
   dart pub get
   dart format --output=none --set-exit-if-changed .
   dart analyze --fatal-infos
   dart run tool/check_core_purity.dart
   dart run tool/license_headers.dart --check
   python3 tool/check_docs.py
   (cd packages/dartrosa && dart test)
   (cd packages/dartrosa_flutter && flutter analyze --fatal-infos && flutter test --exclude-tags golden)
   ```

4. New source files need the SPDX header (`dart run tool/license_headers.dart
   --apply <path>` adds it). Code ported from JavaRosa or ODK Collect keeps a
   `Port of ...` doc comment naming the upstream class.
5. Public API needs doc comments; user-visible changes need a line in the
   package's `CHANGELOG.md`.
6. Open a pull request and fill in the template.

## Third-party code and dependencies

Only add dependencies or copied code under licenses compatible with
Apache-2.0, and follow the process in [docs/legal/README.md](docs/legal/README.md)
(NOTICE, `LICENSES/`, SBOM).

## License

Contributions are licensed under the [Apache License 2.0](LICENSE), as
stated in section 5 of the license. Add yourself to [AUTHORS](AUTHORS) in
your first contribution if you like.
