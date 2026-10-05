## 0.0.1

- Initial release: a pure-Dart port of JavaRosa 6.0.0.
- XPath 1.0 parser and the full JavaRosa function library (dates, geo, digest, randomize, extract-signed, ...).
- XForm parsing (body controls, binds, itext, secondary XML/CSV/GeoJSON/last-saved instances, actions and events, submission profiles).
- Dependency graph recalculation, validation, preloaders and predicate filter strategies.
- Session API (`FormDefinition`, `FormSession`, `FormNavigator`, `FormNode` tree, sealed `AnswerResult`/`FinalizeResult`) and the JavaRosa-compatible API (`package:dartrosa/javarosa.dart`).
- Submission serialization, drafts and resume, and the `FormDefCodec` form-definition cache.
- Plugin points through `DartRosaConfig` (functions, filter strategies, parse/finalization processors, preload handlers, external instance parsers, `FormLoadPlugin`s, resource resolver).
- `package:dartrosa/testing.dart`: JavaRosa's `Scenario` and XForm builder DSL.
- Checked against JavaRosa 6.0.0 oracle traces on a 401-form conformance corpus.
