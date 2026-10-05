## 0.1.0

- Initial release: a pure-Dart port of JavaRosa 6.0.0.
- XPath 1.0 parser and the full JavaRosa function library (dates, geo, digest, randomize, extract-signed, ...).
- XForm parsing (body controls, binds, itext, secondary XML/CSV/GeoJSON/last-saved instances, actions and events, submission profiles).
- Dependency graph recalculation, validation, preloaders and predicate filter strategies.
- Session API (`FormDefinition`, `FormSession`, `FormNavigator`, `FormNode` tree, sealed `AnswerResult`/`FinalizeResult`) and the JavaRosa-compatible API (`package:dartrosa/javarosa.dart`).
- Submission serialization, drafts and resume, and the `FormDefCodec` form-definition cache.
- Plugin points through `DartRosaConfig` (functions, filter strategies, parse/finalization processors, preload handlers, external instance parsers, `FormLoadPlugin`s, resource resolver).
- `package:dartrosa/testing.dart`: JavaRosa's `Scenario` and XForm builder DSL.
- Checked against JavaRosa 6.0.0 oracle traces on a 401-form conformance corpus.
- `FormSession.close()` and `isClosed`: a closed session's `changes` stream is done and it no longer receives the form's events. `FormDefinition.createSession` closes the session it created before, since both share the definition's form.
- `FormSession.answer` returns `AnswerRejected` for text that doesn't fit the question's type or choices.
- Performance (AOT, desktop): a 1,000-question form parses in about 40 ms and an answer recomputes its dependents in about 0.02 ms; forms and external XML instances are built from XML events, without an intermediate DOM.
