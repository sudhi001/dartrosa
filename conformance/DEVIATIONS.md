# Intentional deviations from JavaRosa

**Audience:** developers and contributors who need to know where DartRosa
deliberately behaves differently from JavaRosa 6.0.0. **Type:** reference.

Each entry: what differs, why, and which traces are affected. The goal is to
keep this list as short as possible.

## XPath numbers made of non-ASCII digits

- **JavaRosa:** the lexer accepts any Unicode decimal digit (`٣`) as part of
  a number, then `Double.valueOf` crashes with an unchecked
  `NumberFormatException`.
- **DartRosa:** throws `XPathSyntaxException('Invalid number: ٣')`.
- **Why:** both reject the expression; DartRosa reports it as the syntax
  error it is instead of crashing. Digits inside names (`x٣`) behave
  identically.
- **Traces affected:** none (parse failures compare `ok` only).

## Forms without a main instance

- **JavaRosa:** a form with no `<model>`, a `<model>` with no `<instance>`,
  or the `<h:body>` before the `<h:head>` crashes `XFormParser.parse` with
  an unchecked `NullPointerException` (on `mainInstanceNode` while
  resolving a control's or bind's reference, or on `getMainInstance()`
  after parsing).
- **DartRosa:** throws `XFormParseException('XForm Parse: the form has no
  main instance (...)')`.
- **Why:** both reject the form; DartRosa reports a typed, catchable parse
  error with a message saying what is missing instead of crashing.
- **Traces affected:** `body-before-model.xml` (parse failures compare `ok`
  only).

## Default locale for date names and week numbers

- **JavaRosa:** `format-date` (`%b`, `%a`) and `%W` use the JVM default
  `Locale` (on Android, the device locale).
- **DartRosa:** the locale is an explicit optional parameter of the date
  functions, defaulting to US English (`en_US`). The session will pass the
  form/app locale once the engine API exists (P4).
- **Why:** no global mutable locale; Dart has no settable default locale.
- **Traces affected:** none (the oracle runs with the default `en_US`).

## Java time zone vs Dart local zone

Not a deviation in behaviour: both use the device zone. Dart cannot change
the zone at runtime, so JavaRosa tests that call `TimeZone.setDefault` run
when the process `TZ` matches and are skipped otherwise; CI runs the suite
under several zones.

## Undefined XPath variables

- **JavaRosa:** `$name` with no such variable evaluates to `null`, which
  fails later in an unrelated type conversion.
- **DartRosa:** throws `XPathUnhandledException('variable $name')` at once.
- **Why:** clearer error; ODK forms don't use XPath variables.
- **Traces affected:** none.

## `property()` for an unknown property

- **JavaRosa:** returns `null` from the global `PropertyManager`, which then
  breaks wherever the value is used.
- **DartRosa:** returns `''`; properties come from
  `EvaluationContext.propertyLookup` (no global state).
- **Traces affected:** none known.

## `regex()` dialect

- **JavaRosa:** `Pattern.matches` (Java regex, whole-string match).
- **DartRosa:** Dart `RegExp` (ECMAScript dialect) anchored as
  `^(?:pattern)$`; leading inline flags `(?i)`, `(?s)`, `(?m)` are
  translated. Java-only syntax (possessive quantifiers `a*+`, atomic groups,
  `\p{Alpha}`-style POSIX classes, `\Q…\E`) fails to compile.
- **Why:** no Java regex engine in Dart. Common ODK patterns (digits, phone
  numbers, e-mail) behave identically.
- **Traces affected:** forms using Java-only regex syntax.

## Unseeded `randomize()` and other run-dependent values

Not a behavioural deviation: traces normalize them (see TRACE_FORMAT.md).

# Structural changes (no behaviour change)

Recorded so that nothing in JavaRosa disappears silently.

| JavaRosa | DartRosa | Reason |
|---|---|---|
| `AbstractTreeElement` interface | `TreeElement` used directly | Only one implementation exists; `DataInstance.resolveReference` already casts to `TreeElement`. |
| `TreeElement.tryBatchChildFetch` | not ported | Dead code in JavaRosa 6.0.0 (never called). |
| `EvaluationContext.setPredicateProcessSet` (progress counters) | not ported | Progress reporting for a UI JavaRosa doesn't have; can be added if an app needs it. |
| `XPathFuncExpr` constructor calling `XFormParser.recordInstanceFunctionCall` (static) | parser will walk the expression tree for `instance()` calls (P2) | No global state. |
| `TreeElement.accept(ITreeVisitor)` | `TreeElement.selfAndDescendants` iterable | Idiomatic Dart. |
| Mutable `IAnswerData` (`setValue`, `clone`) | immutable `AnswerValue` | JavaRosa never compares or shares-and-mutates answers. |
| Mutable `TreeReference` | immutable `TreeReference` | Safe as map keys; same operations return new references. |
| `TreeElement.populate` / `populateTemplate` | ported with instance loading (P6) | Need the engine. |
| Static `Localization` singleton | not ported | Global state; apps create their own `Localizer`. |
| `ResourceFileDataSource`, `ReferenceDataSource` (classpath / jr:// locale files) | not ported; `parseLocaleInput` + `ResourceResolver` cover the use | JVM-specific / global `ReferenceManager`. |
| `Localizer.equals`, `TableLocaleSource.equals` | not ported | Only used by JavaRosa's serialization tests. |
| Global `ReferenceManager`, static `ExternalInstanceParser` registries, static `XFormParser` action handlers / processors | `ResourceResolver`, per-parser `ExternalInstanceParser`, `XFormParser.registerActionHandler` / `addProcessor` | No global state. |
| `ReferenceManager` singleton, `RootTranslator`, `PrefixedRootFactory`, `ResourceReferenceFactory` | same logic in a per-instance `ReferenceManager`; factories receive the manager; `ReferenceManagerResolver` adapts it to `ResourceResolver` | No global state. |
| `Reference` stream methods (`getStream`, `getOutputStream`, `remove`, `doesBinaryExist`, `probeAlternativeReferences`) | not ported; `Reference` has `uri` and `localUri` | The core does no I/O; apps read `localUri`. |
| `org.javarosa.core.reference.InvalidReferenceException` | `InvalidReferenceUriException` | Name clash with the tree-reference `InvalidReferenceException`. |
| Mutable answer data (`setValue`, null values, defensive `Date`/`List` copies) | immutable, non-nullable values over `DateTime` and unmodifiable lists | JavaRosa's mutation/null tests become type-system guarantees. |
| `DataTypeClasses`, `ExtWrapIntEncoding*` | ported with the codec (P6) or not at all | Only used by `Externalizable` serialization. |
| `XFormParser.parse` is synchronous | `Future<FormDef>` | External secondary instances are read through an async `ResourceResolver`. |
| `XPathReference` / `IDataReference` wrappers | plain `TreeReference` | The wrapper added nothing. |
| `RecordAudioActions` static listener | `FormDef.recordAudioListener` | No global state. |
| `QuickTriggerable` and identity-hash-ordered sets in `TriggerableDag` | `Triggerable` (identity equality) in insertion-ordered sets | JavaRosa's evaluation order within a DAG level, and the node order of its cycle message, change from run to run; DartRosa uses registration order, one of JavaRosa's possible orders. |
| `FormDef.initialize(boolean, InstanceInitializationFactory)` | `initialize({required bool newInstance})` | JavaRosa never uses the factory. |
| `createNewRepeat(FormIndex)`, `deleteRepeat(FormIndex)`, `canCreateRepeat(ref, FormIndex)` | reference-based `createRepeatInstance`, `deleteRepeatInstance`, `canCreateRepeat(ref, repeat, multiplicity)`; the `FormIndex` forms come with navigation (P4) | Same logic after the index-to-reference step. |
| Global `PropertyManager` | `PropertyManager` interface on `FormDef.preloader`, also read by `property()` | No global state. |
| `EventNotifier` | `FormDef.addEventListener` receiving `EvaluationEvent`s | Same events and messages. |
| `RuntimeException("Error evaluating field …")` | `TriggerableEvaluationException` with the same message | Typed exception. |
| Filter-strategy cache keys (`Object.toString()` of unpacked values) | Java formatting for numbers and booleans; dates use Dart's `toString` | Keys only need to be consistent within a run; a date node side never equals a string context side in either. |
| `FormEntryController.EVENT_*`, `ANSWER_*`, `FormEntryModel.REPEAT_STRUCTURE_*` int constants | `FormEntryEvent` (with JavaRosa's `code`), `AnswerStatus`, `RepeatStructure` enums | Dart idiom. |
| `answerQuestion(index?, data, midSurvey)` overloads | `answerQuestion(data, {index, midSurvey})` (same for `saveAnswer`); `deleteRepeat(int)` is `deleteRepeatAt` | No overloading in Dart. |
| `Selection.attachChoice(QuestionDef)` mutates the selection | `QuestionDef.attachChoice(selection)` returns a bound selection | Immutable values. |
| `IQuestionWidget` / `FormElementStateListener` registration | `QuestionWidget` + `FormEntryCaption.register` | Same events. |
| `Scenario` overloads `answer(xpath, String/int/double/boolean/LocalDate/SelectChoice/String...)` and `answer(value)` | `answer(xpath, Object?)` dispatching on the value type; `answerCurrent(value)`; async `Scenario.init` / `fromXml`; `createNewRepeat()` (current index) is `createNewRepeatHere()` | No overloading; parsing is async. |
| `Scenario.serializeAndDeserializeForm/Instance` | come with serialization (P6) | |
| `FormEntryModel.getExtras()` (`Extras<Object>`) | `extras` map | |
| `FormDef.validate()` | `FormDefValidation.validate()` extension in the form-entry library | Keeps the model layer independent of navigation. |
| `Externalizable` `FormDef` serialization (binary object graph; Collect's `.formdef` cache) | `FormDefCodec`: source XML + draft instance + language, restored by re-parsing | Same observable state after restore; restoring costs a parse. |
| Static `XFormParser.setAnswerResolver` | `AnswerResolver` passed to `parse(instanceXml:)` / `loadXmlInstance` | No global state. |
| `XFormSerializingVisitor.createSerializedPayload` (`IDataPayload` / multipart classes) | `dataPointers` on the serializer; `Submission.attachments` in the session API | Payload transport is the app's job. |
| `org.javarosa.measure.Measure` static counters | zone-scoped `Measure.withMeasure` | No global state. |
| `SubmissionParser` class and `matchesCustomMethod` | inlined into `XFormParser` | JavaRosa's static `submissionParsers` list has no public registration, so only the default parser ever runs. |
| `QuestionDef.getChildren()` returns `null` | returns an empty list | Null-safe API; `addChild` still throws. |
| Dart `String.trim()` | `javaTrim` everywhere | Dart also strips Unicode spaces such as U+00A0; Java only characters `<= ' '`. |
| `XFormParseException` for malformed `jr:itext` refs etc. | same messages, `XFormParseException` type | JavaRosa throws a plain `RuntimeException` in a few places; both fail the parse. |
