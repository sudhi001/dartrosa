# DartRosa — Detailed Porting Plan

> Port of [getodk/javarosa](https://github.com/getodk/javarosa) (ODK XForms engine, Java, Apache-2.0) to idiomatic Dart,
> plus a Flutter renderer and the Collect-layer features needed for full ODK Collect form parity.

| | |
|---|---|
| Source baseline | `getodk/javarosa` @ master (v6.0.0, as used by Collect `libs.versions.toml`) — 328 main classes / ~44k LOC, 135 test classes / ~21k LOC, 95 test resources |
| Target | Dart ≥ 3.10 (sound null safety, sealed classes, records, patterns, extension types), Flutter ≥ 3.38 |
| License | Apache-2.0 (derivative work — keep JavaRosa `NOTICE.md` + attribution) |
| Spec references | [ODK XForms spec](https://getodk.github.io/xforms-spec/), [XLSForm spec](https://xlsform.org), [ODK Entities spec](https://getodk.github.io/xforms-spec/entities), XPath 1.0, XForms 1.1 (recalc) |
| Design reference | ODK Web Forms `@getodk/xforms-engine` (modern reactive engine by the ODK team) |

---

## 0. Table of contents

1. Goals, non-goals, success criteria
2. Architecture decisions (ADRs)
3. Dart / Flutter rules compliance — JavaRosa idiom → Dart idiom
4. Package layout & dependency policy
5. Public API design (core + Flutter)
6. Complete porting matrix (every JavaRosa package)
7. Complete functional inventory (checklists — nothing may be dropped)
8. Collect-layer features (outside JavaRosa, required for parity)
9. Compatibility traps (where a naive port silently diverges)
10. Test & conformance strategy (incl. 1:1 test-class port map)
11. Phased delivery plan with exit criteria
12. Flutter renderer (`dartrosa_flutter`) design
13. Performance, isolates, web
14. Risks & mitigations
15. Definition of Done

---

## 1. Goals, non-goals, success criteria

### Goals
- **G1 — Behavioural parity with JavaRosa**: same input form + same sequence of user actions ⇒ identical instance XML, relevance, readonly, required, validity, constraint messages, navigation events, and submission output.
- **G2 — Idiomatic Dart**: passes `dart analyze` with strict lints; follows *Effective Dart*; no Java-isms (no `I`-prefixed interfaces, no getter/setter methods, no int constants for enums, no static mutable singletons).
- **G3 — Pure-Dart core**: no Flutter, no `dart:io`, no `dart:mirrors` in `dartrosa` ⇒ runs on Android, iOS, Web, desktop, server, CLI.
- **G4 — Simple, small public API**: one entry point to parse, one session object to fill; everything else in `lib/src`.
- **G5 — Extensible without forking**: every JavaRosa plugin point (PLUGINS.md) has a Dart equivalent, configured per-instance (no globals).
- **G6 — Flutter renderer** covering every ODK control type and Collect appearance, overridable per widget.

### Non-goals (v1)
- Binary compatibility with JavaRosa's `Externalizable` serialized `FormDef` cache (replaced by our own cache format).
- Being a server client (OpenRosa / ODK Central sync) inside the core — delivered as a separate optional package (§8).
- XLSForm → XForm conversion in Dart (pyxform remains the converter; a Dart port is a possible later project — see §8.6).

### Success criteria
- 100 % of the JavaRosa test suite ported and green (§10.5).
- 0 diffs against the JVM oracle on the full conformance corpus (JavaRosa resources + Web Forms fixtures + ≥ 300 real-world XLSForms).
- Parse of a 1,000-question form < 300 ms on a mid-range Android device (AOT); answer→recompute < 16 ms (one frame) for typical forms.

---

## 2. Architecture decisions (ADRs)

| # | Decision | Rationale |
|---|---|---|
| ADR-1 | **Dart, not Rust** | Native to Flutter (no FFI bridge for a chatty, fine-grained reactive engine), single toolchain, runs on web via dart2js/dart2wasm, larger contributor pool. Rust only wins if the engine must be shared by Kotlin/Swift/Python hosts. |
| ADR-2 | **Port semantics, redesign structure** | JavaRosa carries J2ME-era layers (custom serialization, storage, services, logging, property manager, `StateMachine`). Behaviour is ported exactly; structure follows Dart idioms. |
| ADR-3 | **Immutable definition / mutable session split** | `FormDefinition` (parsed, immutable, shareable, cacheable, isolate-transferable) vs `FormSession` (one fill-in; owns the instance tree + reactive state). JavaRosa's `FormDef` mixes both. |
| ADR-4 | **Async only at the edges; synchronous engine** | Loading (form XML, external instances, media resolution) is `Future`-based. Once loaded, `answer()`, recompute, navigation are **synchronous and deterministic** — required for parity, testability and frame-budget UI updates. |
| ADR-5 | **Tree/state API is primary, cursor API is secondary** | Flutter is declarative: the UI rebuilds from state. The primary API exposes the form as a tree of observable nodes (like Web Forms). A `FormNavigator` (cursor: next/prev/jump, = JavaRosa `FormEntryController`) is built *on top* for one-question-per-screen UIs and for porting JavaRosa tests 1:1. |
| ADR-6 | **Reactivity without a state-management dependency** | Core exposes synchronous getters + `Stream<FormChange>` + per-node change notification via a tiny internal `Observable` (pure Dart). `dartrosa_flutter` adapts nodes to `ValueListenable`/`Listenable` so widgets use `ListenableBuilder`. Apps remain free to use Riverpod/Bloc/Provider on top. |
| ADR-7 | **No global state** | JavaRosa statics (`ReferenceManager.instance()`, `PrototypeManager`, `XFormUtils.setXFormParserFactory`, `XFormParser.registerActionHandler`, `Localization`, `PropertyManager`, `Logger`) become fields of an explicit, immutable `DartRosaConfig` passed to the parser/session. Tests run in parallel safely. |
| ADR-8 | **Sealed result types for expected outcomes, exceptions for faults** | `AnswerResult`, `FinalizeResult`, `NavigationEvent` are sealed classes consumed with `switch` patterns. Exceptions (`FormParseException`, `XPathException` family) only for malformed input or programmer errors. |
| ADR-9 | **Exact-compat numerics, dates, PRNG** | Port Java `Double.toString` formatting, Joda-equivalent date math, Park–Miller PRNG and Fisher–Yates exactly (see §9). |
| ADR-11 | **XPath lives inside `dartrosa`** (decided in P1) | JavaRosa's XPath code depends directly on the instance model, references and answer types. A separate package would need an artificial abstraction layer and would force the sealed `AnswerValue` hierarchy into the XPath package. Layering is kept by directory: `lib/src/xpath` depends only on model interfaces. |
| ADR-10 | **Pluggable resource resolution** | `jr://…` URIs resolved through an injected async `ResourceResolver` (replaces `ReferenceManager` static roots). `dart:io` implementation lives in a separate entry point via conditional import. |

---

## 3. Dart / Flutter rules compliance — JavaRosa idiom → Dart idiom

Every row is a mandatory porting rule, enforced in code review and by lints.

| JavaRosa (Java) pattern | DartRosa rule | Lint / enforcement |
|---|---|---|
| `IFormElement`, `IAnswerData`, `IFunctionHandler` (I-prefix) | `FormElement`, `AnswerValue`, `XPathFunction` — use `abstract interface class` / `sealed class` | Effective Dart: *don't prefix interfaces* |
| `getLabel()`, `setLanguage(x)`, `isRelevant()` | Getters/setters: `label`, `language = x`, `isRelevant` | `use_setters_to_change_properties`, `avoid_returning_this` |
| `public static final int CONTROL_INPUT = 1` | `enum ControlType { input, selectOne, … }` (enhanced enums with fields) | `prefer_enums` (custom), review |
| `int answerQuestion()` returning `ANSWER_OK/REQUIRED/CONSTRAINT` | `sealed class AnswerResult` → `AnswerAccepted`, `AnswerRequired`, `AnswerConstraintViolated(String? message)` | exhaustive `switch` |
| `int stepToNextEvent()` returning `EVENT_*` bit flags | `sealed class FormEvent` → `BeginningOfForm`, `QuestionEvent`, `GroupEvent`, `RepeatEvent`, `PromptNewRepeat`, `RepeatJuncture`, `EndOfForm` | exhaustive `switch` |
| `IAnswerData` + `UncastData`, `getValue(): Object` | `sealed class AnswerValue` with typed subclasses; `final` fields; value equality (`==`/`hashCode`) | `@immutable`, `avoid_equals_and_hash_code_on_mutable_classes` |
| `null`-as-meaning everywhere | Sound null safety; `null` only where "absent" is semantically valid | compiler |
| Checked exceptions / `throws` | Unchecked exception classes extending `Exception`/`Error` correctly; expected outcomes are results | `only_throw_errors` |
| Static singletons & registries | Constructor-injected `DartRosaConfig` | review; no top-level mutable vars (`avoid_global_state` custom rule) |
| `Externalizable`, `PrototypeFactory`, reflection (`Class.forName`) | Explicit codecs; no reflection; tree-shakable | no `dart:mirrors` |
| `Vector`, `Hashtable`, `OrderedMap`, `SortedIntSet` custom collections | `List`, `Map` (insertion-ordered `LinkedHashMap` by default), `SplayTreeSet`, `package:collection` | — |
| Listener interfaces (`FormElementStateListener`, `EventNotifier`) | `Stream`s + `Observable` | — |
| `InputStream`/`Reader` | `String` / `Uint8List` / `Stream<List<int>>` | — |
| Joda-Time | `DateTime` + own `LocalDate`/`LocalTime`/offset value types (extension types or small classes) + injected `Clock` | `package:clock` |
| Overloads (`answerQuestion(idx, data)` / `answerQuestion(data)`) | One method with optional named params | Effective Dart |
| Long parameter lists | Named parameters, `required` where mandatory | `always_put_required_named_parameters_first` |
| Package-private classes | `lib/src/**` + curated barrel `lib/dartrosa.dart`; `@internal`/`@visibleForTesting` from `package:meta` | `implementation_imports` |
| Mutable public fields | `final` fields; mutation only through session methods | `prefer_final_fields`, `prefer_final_locals` |
| `toString()` used for logic | Explicit `serialize()`/`displayText` | review |
| Logging via static `Logger` | `package:logging` `Logger('dartrosa.xpath')` (no output unless the app attaches a listener) | — |
| Threads | Isolates only for parsing large forms (`Isolate.run`; on web runs inline) — engine is single-isolate | — |

**Code style:** `dart format` (page width 80), `analysis_options.yaml` = `package:lints/recommended.yaml` + strict-casts, strict-inference, strict-raw-types + a curated set from `very_good_analysis`. Public API 100 % dartdoc'd (`public_member_api_docs`). Files `snake_case.dart`, one public type per file where practical.

---

## 4. Package layout & dependency policy

```
dartrosa/                              (melos/pub workspace monorepo)
├─ packages/
│  ├─ dartrosa/                        pure Dart core: XPath (lib/src/xpath), XForm parser, definition, instance, DAG, session, navigator,
│  │                                   actions/events, secondary instances, i18n, serialization, plugins
│  ├─ dartrosa_io/                     dart:io ResourceResolver (file system), form-cache store
│  ├─ dartrosa_entities/               ODK Entities parse + finalization processors (Collect parity)
│  ├─ dartrosa_external_data/          pulldata(), search() (Collect parity; CSV indexed via sqlite optional)
│  ├─ dartrosa_encryption/             encrypted submissions (RSA-OAEP + AES-CFB, ODK format)
│  ├─ dartrosa_flutter/                Flutter renderer: FormView, widgets, theming, delegates
│  ├─ dartrosa_openrosa/   (phase 9)   OpenRosa formList/manifest/submission + ODK Central client
│  └─ dartrosa_cli/                    validate, inspect, run scenarios, dump instance, benchmark
├─ conformance/
│  ├─ forms/                           JavaRosa test resources, Web Forms fixtures, real XLSForms (+ generated XML)
│  ├─ scenarios/                       *.scenario.yaml (form + actions + expectations)
│  └─ jvm_oracle/                      Kotlin/Gradle harness running the same scenarios through real JavaRosa
├─ example/                            Flutter demo app (form list, fill, save, resume, submit to file)
└─ docs/                               this plan, ADRs, compatibility matrix, migration guide from JavaRosa
```

### Dependency policy (core packages)
Allowed, all pure Dart and widely maintained: `xml`, `meta`, `collection`, `clock`, `logging`, `crypto` (md5/sha1/sha256/sha384/sha512 for `digest()`), `csv`.
`dartrosa_encryption`: `pointycastle`. Ed25519 for `extract-signed()`: `cryptography` (or a vendored pure-Dart verifier) — isolated behind an interface so the core stays light.
**Forbidden in core:** Flutter, `dart:io`, `dart:html`/`package:web`, code generation that users must run, state-management libraries, `intl` (date formatting is ODK-specific; month/day names come from a pluggable `DateSymbols` with an English default; `dartrosa_flutter` supplies locale symbols).

---

## 5. Public API design

### 5.1 Core (`package:dartrosa/dartrosa.dart`)

```dart
// 1. Configure once (immutable, no globals)
final config = DartRosaConfig(
  resolver: MyResourceResolver(),          // jr://images, jr://file, jr://file-csv, jr://instance/last-saved …
  functions: [MyCustomFunction()],         // = FormEntryController.addFunctionHandler
  filterStrategies: const [],              // = addFilterStrategy
  parseProcessors: [EntitiesParseProcessor()],          // = XFormParser.addProcessor
  finalizationProcessors: [EntitiesFinalizer()],        // = addPostProcessor
  instanceProviders: const [],             // = ExternalInstanceParser.addInstanceProvider / addFileInstanceParser
  actionHandlers: [SetGeopointHandler(location: myLocationSource)],
  clock: const Clock(),                    // deterministic tests
  properties: DeviceProperties(deviceId: '…', username: '…', email: '…', phoneNumber: '…'),
);

// 2. Parse (async: resolves secondary instances) → immutable, cacheable
final FormDefinition def = await FormDefinition.parse(xml, config: config);

// 3. Start or resume a session (sync from here on)
final FormSession session = def.createSession(
  existingInstance: savedXml,              // null = new; non-null = edit/resume
  language: 'Français',
);

// 4a. Declarative tree API (primary — for Flutter)
for (final node in session.root.visibleChildren) {
  switch (node) {
    case QuestionNode q:  print('${q.label.text} = ${q.value}');
    case GroupNode g:     print('group ${g.label?.text}');
    case RepeatNode r:    print('repeat with ${r.instances.length}');
    case NoteNode n:      print(n.label.text);
  }
}
final AnswerResult r = session.answer(question.ref, const IntegerValue(5));
session.changes.listen((FormChange c) { /* changed refs: value/relevance/validity/readonly/required/choices */ });
session.addRepeatInstance(repeat.ref);
session.removeRepeatInstance(instance.ref);

// 4b. Cursor API (secondary — JavaRosa FormEntryController semantics)
final nav = session.navigator;
switch (nav.next()) {
  case QuestionEvent(:final prompt): …
  case PromptNewRepeat(:final repeat): nav.addRepeat();
  case EndOfForm(): …
}

// 5. Finalize & serialize
switch (session.finalize()) {
  case FinalizeSuccess(:final submission):  // submission.xml, submission.instanceId, submission.attachments
  case FinalizeFailure(:final failures):    // List<ValidationFailure(ref, kind, message)>
}
final String draftXml = session.saveDraft(); // incomplete, no finalization processors
```

Key public types (all others in `lib/src`):
`DartRosaConfig`, `FormDefinition`, `FormSession`, `FormNavigator`, `FormNode` (sealed: `GroupNode`, `RepeatNode`, `RepeatInstanceNode`, `QuestionNode`, `NoteNode`, `TriggerNode`), `NodeRef`, `AnswerValue` (sealed), `AnswerResult` (sealed), `FormEvent` (sealed), `FinalizeResult` (sealed), `ValidationFailure`, `LocalizedText` (text + media forms), `SelectChoice`, `ControlType`, `DataType`, `Appearance`, `ResourceResolver`, `XPathFunction`, `FilterStrategy`, `ParseProcessor`, `FinalizationProcessor`, `InstanceProvider`, `ActionHandler`, `FormParseException`, `XPathException` (sealed family).

### 5.2 Flutter (`package:dartrosa_flutter/dartrosa_flutter.dart`)

```dart
XFormView(
  session: session,
  mode: XFormMode.pager,                    // or .scroll (all visible), .fieldListAware (default)
  delegates: XFormDelegates(
    camera: …, video: …, audio: …, file: …, barcode: …, signature: …, drawing: …, annotate: …,
    location: …, map: …, externalApp: …, printer: …,
  ),
  widgetOverrides: { WidgetKey(ControlType.selectOne, 'likert'): (ctx, node) => MyLikert(node) },
  onFinalize: (FinalizeResult r) {},
)
```
`XFormTheme` is a `ThemeExtension`; all strings via `XFormLocalizations` (`LocalizationsDelegate`) so apps translate UI chrome; form content language comes from the form's itext.

---

## 6. Complete porting matrix (every JavaRosa package)

Disposition: **PORT** = behaviour ported 1:1 (idiomatic structure) · **REDESIGN** = same capability, different shape · **REPLACE** = covered by Dart SDK / package · **DROP** = legacy, not needed (reason given).

| JavaRosa package (LOC) | Classes | Disposition → DartRosa location |
|---|---|---|
| `xpath/parser` (755) + `xpath/parser/ast` (842) | Lexer, Parser, Token, XPathSyntaxException, ASTNode* | **PORT** faithfully (JavaRosa's token-condensing parser, so associativity, quirks and error messages match) → `dartrosa/lib/src/xpath/` |
| `xpath/expr` (3,913) | XPathArith/Bool/Cmp/Eq/Union/UnaryOp/NumNeg/Filter/Path/PathEval/Step/QName/StringLiteral/NumericLiteral/VariableReference/FuncExpr/FuncExprGeo, DigestAlgorithm, Encoding | **PORT** → sealed `XPathExpr` AST + evaluator in `dartrosa/lib/src/xpath/`; functions split into `functions/{core,string,number,date,geo,select,crypto,random,repeat}.dart` |
| `xpath` (856) | XPathNodeset, XPathLazyNodeset, XPathConditional, XPathParseTool, IExprDataType, exceptions (Arity, TypeMismatch, Unhandled, Unsupported, MissingInstance) | **PORT** → `Nodeset` (lazy), sealed `XPathException` family |
| `core/model` (5,787) | FormDef, FormIndex, GroupDef, QuestionDef, RangeQuestion, SelectChoice, ItemsetBinding, DataBinding, DataType(Classes), ControlType, Constants, SubmissionProfile, TriggerableDag, QuickTriggerable, ValidateOutcome, IFormElement, IDataReference, XFormExtension, FormElementStateListener, CoreModelModule, filter strategies (ComparisonExpressionCache, EqualityExpressionIndex, IdempotentExpressionCache, CompareToNodeExpression) | **REDESIGN**: `FormDef` → `FormDefinition` (immutable) + `FormSession` (state); `TriggerableDag` → `DependencyGraph`; filter strategies **PORT** (they are performance-critical for big choice lists); `CoreModelModule` **DROP** (prototype registration) |
| `core/model/condition` (1,391) + `pivot` | Condition, Constraint, Recalculate, Triggerable, EvaluationContext, IFunctionHandler, IFallbackFunctionHandler, ChoiceNameFunctionHandler, FilterStrategy, RawFilterStrategy, ConditionAction; Pivot/RangeHint/*RangeHint/ConstraintHint/CmpPivot | **PORT**; pivots/range hints **PORT** (used by `requestConstraintHint` — renderer can show "value must be between X and Y") |
| `core/model/instance` (3,211) + `geojson` + `utils` | TreeElement, TreeReference, TreeReferenceLevel, AbstractTreeElement, DataInstance, FormInstance, ExternalDataInstance, XmlExternalInstance, CsvExternalInstance, GeoJsonExternalInstance(+Feature/Geometry), SecondaryInstanceCSVParserBuilder, InstanceInitializationFactory, InvalidReferenceException; CachingInstanceTemplateManager, CompactInstanceWrapper, DefaultAnswerResolver, IAnswerResolver, InstanceTemplateManager, ITreeVisitor, ModelReferencePayload, TreeElementChildrenList, TreeElementNameComparator | **PORT** (TreeReference semantics — anchor/contextualize/genericize/parent/isAncestorOf — exactly); visitors → Dart pattern matching; `CompactInstanceWrapper`/`ModelReferencePayload` **DROP** (SMS/compact transport) |
| `core/model/data` (2,358) + `helper` | IAnswerData + Boolean/Date/DateTime/Decimal/GeoPoint/GeoShape/GeoTrace/Integer/Long/MultipleItems/MultiPointer/Pointer/SelectMulti/SelectOne/String/Time/Uncast data; AnswerDataFactory; AnswerDataUtil, BasicDataPointer, Selection, InvalidDataException | **REDESIGN** → sealed immutable `AnswerValue` hierarchy (+ `UncastValue`); `Pointer`/`MultiPointer` (binary attachment pointers) → `AttachmentValue` |
| `core/model/actions` (+ setgeopoint, recordaudio) | Action, ActionController, Actions, SetValueAction, SetGeopointAction(+Handler, Stub*), RecordAudioAction(+Handler, Listener, Actions) | **PORT** event model; setgeopoint/recordaudio become `ActionHandler`s whose platform side is a delegate (location/audio) |
| `core/model/utils` (1,379) | DateUtils, PreloadUtils, QuestionPreloader, IPreloadHandler, IInstanceProcessor, IInstanceVisitor, IInstanceSerializingVisitor | **PORT** (DateUtils is a compat hotspot — §9) |
| `core/model/util/restorable` | Restorable, RestoreUtils, IXFormyFactory, IRecordFilter | **DROP** (J2ME record restore) |
| `core/model/osm` | OSMTag, OSMTagItem | **PORT** (`odk:tag` children of OSM upload control) |
| `core/services/locale` (1,300) | Localizer, Localization, LocalizationUtils, Localizable, LocaleDataSource, TableLocaleSource, ResourceFileDataSource, LocaleTextException | **PORT** `Localizer` (itext, default lang, text forms, fallback) → `src/i18n/`; static `Localization` **DROP** |
| `core/services` (604) + `properties` + `storage` + `transport/payload` | Logger, PropertyManager, IPropertyManager, PrototypeManager, ProgramFlow, UnavailableServiceException; JavaRosaPropertyRules, Property; Storage*; *Payload | Properties → **REDESIGN** `DeviceProperties` in config (needed for `property()` preload & `jr:preload="property"`: deviceid, subscriberid, simserial, phonenumber, username, email); Logger → **REPLACE** `package:logging`; storage, payload, PrototypeManager, ProgramFlow → **DROP** (app concern / reflection) |
| `core/reference` (816) | ReferenceManager, Reference, ReferenceFactory, PrefixedRootFactory, RootTranslator, ResourceReference(+Factory), ReferenceDataSource, InvalidReferenceException | **REDESIGN** → injected `ResourceResolver` + `RootTranslator`-style prefix mapping (`jr://images/` → form media dir) |
| `core/util` (2,118) | ArrayUtilities, Base64, CacheTable, CodeTimer, DataUtil, **Ed25519**, Extras, **GeoUtils**, Map, MathUtils, MemoryUtils, MultiInputStream, OrderedMap, PropertyUtils, SHA1, SortedIntSet, StopWatch, StreamsUtil, TrivialTransitions*, exceptions | GeoUtils, Ed25519 (verify), Extras (typed plugin extras) → **PORT**; Base64/SHA1/collections/streams/timers → **REPLACE** (`dart:convert`, `crypto`, SDK); MemoryUtils/StateMachine helpers → **DROP** |
| `core/util/externalizable` (1,905) | Externalizable, ExtUtil, ExtWrap*, PrototypeFactory, … | **REPLACE** with explicit versioned `FormDefinitionCodec` (binary, no reflection) — optional cache |
| `core/api`, `core/data`, `core/io`, `core/log` | Constants, ILogger, IModule, State, StateMachine, IDataPointer, BufferedInputStream, Std, StreamsUtil, LogEntry/serializers, FatalException, WrappedException | **DROP/REPLACE** (SDK + `package:logging`); `IDataPointer` → `AttachmentValue` |
| `form/api` (1,906) | FormEntryController, FormEntryModel, FormEntryPrompt, FormEntryCaption, FormEntryFinalizationProcessor | **REDESIGN** → `FormSession` (state) + `FormNavigator` (cursor) + `QuestionNode`/`CaptionView`; **every public method mapped in §7.12** |
| `model/xform` (1,012) | XFormSerializingVisitor, CompactSerializingVisitor, SMSSerializingVisitor, DataModelSerializer, XFormsModule, XPathReference | XForm serializer → **PORT** (submission XML incl. namespaces, attributes, `jr:template` stripping, non-relevant pruning); Compact/SMS → **PORT as optional** `dartrosa_compact` (low priority, still in scope: never drop a capability silently); XFormsModule → **DROP** |
| `xform/parse` (4,377) | XFormParser, XFormParserFactory/IXFormParserFactory, XFormParserReporter, FormInstanceParser, StandardBindAttributesProcessor, SubmissionParser, RangeParser, ExternalInstanceParser(+Factory), TypeMappings, RandomizeHelper, FisherYates, ParkMiller, ElementChildDeleter, XmlTextConsolidator, IElementHandler, IXFormParserFunctions, Constants, XFormParseException | **PORT** (handler table becomes a const map per config; `XFormParserReporter` warnings → `List<ParseWarning>` on `FormDefinition`) |
| `xform/util` (928) | XFormUtils, XFormAnswerDataParser, XFormAnswerDataSerializer, XFormSerializer, InterningKXmlParser | **PORT** answer (de)serializers exactly; XFormUtils static factories → **DROP** (config); KXml interning → **REPLACE** `package:xml` + string interning in parser |
| `xml` + `xml/util` | ElementParser, TreeElementParser, InternalDataInstanceParser, InvalidStructureException, UnfullfilledRequirementsException | **PORT** |
| `debug` | EvaluationResult, Event, EventNotifier(Silent) | **PORT** as optional `FormSession.debugEvents` stream (trace which triggerables fired) — useful for devtools |
| `measure` | Measure | **PORT** as internal benchmark counters (`@visibleForTesting`) |
| `formmanager`, `formmanager/view` | FormModule, IQuestionWidget | **DROP** (UI is `dartrosa_flutter`) |
| `test` (1,634 — test helpers shipped in main) | Scenario, FormParseInit, XFormsElement DSL (Tag/BindBuilder/Empty/StringLiteral), ResourcePathHelper, TempFileUtils | **PORT** into `package:dartrosa/testing.dart` (public test-support library so app developers can test their forms) |

---

## 7. Complete functional inventory (checklists)

> Every box must be ticked, tested, and oracle-verified before v1.0. Source = JavaRosa unless noted.

### 7.1 XForm document structure
- [ ] `h:html` / `h:head` / `h:title` / `h:body`; namespaces: XForms, XHTML, `jr` (`http://openrosa.org/javarosa`), `odk` (`http://www.opendatakit.org/xforms`), `orx` (`http://openrosa.org/xforms`), `entities`, arbitrary user namespaces preserved in serialization
- [ ] `<model>` with `odk:xforms-version`, `entities:entities-version`, `jr:version` / `version`, `id`, `uiVersion`
- [ ] Primary `<instance>` (first instance) — elements **and attributes** as data nodes
- [ ] Secondary instances: inline `<instance id>`, `src="jr://file/x.xml"`, `jr://file-csv/x.csv`, `jr://file/x.geojson`, `jr://instance/last-saved` (+ custom via `InstanceProvider`)
- [ ] Repeat templates: `jr:template=""` and implicit templates (first repeat instance)
- [ ] `<itext>` / `<translation lang default="true()">` / `<text id>` / `<value form="…">`
- [ ] `<bind>` (all attributes §7.3), multiple binds same nodeset (merge/override rules as JavaRosa)
- [ ] Top-level `<setvalue>`, `<odk:setgeopoint>`, `<odk:recordaudio>` and nested-in-control actions
- [ ] `<submission>` (`orx:submission`): `action`, `method`, `base64RsaPublicKey`, `orx:auto-send`, `orx:auto-delete` (SubmissionParser)
- [ ] `meta` handler (head meta), `title` handler
- [ ] `XmlTextConsolidator` (merge adjacent text nodes), `ElementChildDeleter`, whitespace rules identical to JavaRosa
- [ ] Parse warnings (XFormParserReporter): unknown elements/attributes, deprecated constructs, `jr-insert` deprecation

### 7.2 Body controls (ControlType)
- [ ] `input` (incl. passthrough attrs `rows`, `query`) — CONTROL_INPUT
- [ ] `textarea` — CONTROL_TEXTAREA
- [ ] `secret` — CONTROL_SECRET
- [ ] `select1` — CONTROL_SELECT_ONE
- [ ] `select` — CONTROL_SELECT_MULTI
- [ ] `odk:rank` — CONTROL_RANK
- [ ] `range` (`start`, `end`, `step`, extra attrs e.g. `odk:tick-interval`, `odk:tick-labelset`, `odk:placeholder`) — CONTROL_RANGE + RangeParser
- [ ] `upload` with `mediatype` image/* audio/* video/* application/*, OSM (`osm/*` + `odk:tag`/`label`) → IMAGE_CHOOSE, AUDIO_CAPTURE, VIDEO_CAPTURE, FILE_CAPTURE, OSM_CAPTURE, UPLOAD
- [ ] `trigger` (acknowledge) — CONTROL_TRIGGER
- [ ] Standalone `label` element — CONTROL_LABEL
- [ ] CONTROL_SUBMIT, CONTROL_UNTYPED (parity — represented even if unused by ODK)
- [ ] `group` (with/without `ref`, `appearance` e.g. `field-list`, `table-list`, `intent`), nested groups
- [ ] `repeat` (`nodeset`, `jr:count`, `jr:noAddRemove`, `appearance`), nested repeats, repeat inside field-list
- [ ] Repeat UI captions: `jr:addCaption`, `addEmptyCaption`, `delCaption`, `doneCaption`, `doneEmptyCaption`, `chooseCaption`, `entryHeader`, `delHeader`, `mainHeader` (FormEntryCaption.getRepeatText)
- [ ] `<label>`, `<hint>`, guidance hint (`form="guidance"`), `<output value="…"/>` inside labels/hints/choices (live re-evaluation)
- [ ] `<item>` (`label`, `value`), `<itemset nodeset>` with `<label ref>`/`<value ref>`, `jr:itext(...)` labels in itemsets, `randomize="true()"` + `seed`
- [ ] Choice media (image/audio/video/big-image forms on choice itext)
- [ ] `appearance` string on every control passed through verbatim (renderer interprets)
- [ ] Unknown control attributes preserved in `promptAttributes`/`additionalAttributes`

### 7.3 Bind attributes (StandardBindAttributesProcessor)
- [ ] `nodeset`, `type` (§7.4), `readonly`, `required`, `relevant`, `constraint`, `calculate`
- [ ] `jr:constraintMsg` (literal or `jr:itext('id')`), `jr:requiredMsg`
- [ ] `jr:preload`, `jr:preloadParams` (§7.8)
- [ ] `saveIncomplete` (ODK spec: triggers save on change — exposed as flag to app)
- [ ] Unknown/namespaced bind attributes kept (`getBindAttributes`) — e.g. `orx:max-pixels`, `odk:length`, `entities:saveto`, `odk:allow-mock-accuracy`
- [ ] Attribute-node binds (`/data/item/@id`)
- [ ] Inheritance: non-relevant and readonly propagate to descendants

### 7.4 Data types (TypeMappings → DataType)
- [ ] string, int/integer, long, decimal/double/float, boolean, date, time, dateTime, gYear/gMonth/gDay/gYearMonth/gMonthDay (map as JavaRosa does), base64Binary/hexBinary/anyURI/binary (→ binary), select1/select (listItem/listItems → choice/choice-list), geopoint, geotrace, geoshape, barcode, unsupported/null
- [ ] AnswerValue types: `StringValue`, `IntegerValue`, `LongValue`, `DecimalValue`, `BooleanValue`, `DateValue`, `TimeValue`, `DateTimeValue`, `SelectOneValue`, `SelectMultiValue`, `MultipleItemsValue`, `GeoPointValue` (lat, lon, alt, accuracy), `GeoTraceValue`, `GeoShapeValue`, `AttachmentValue` (pointer), `UncastValue`
- [ ] `AnswerDataFactory` rules (control+type → value class), cast/uncast round-trip exactly as `XFormAnswerDataParser`/`XFormAnswerDataSerializer`
- [ ] Invalid-data handling (`InvalidDataException` → `AnswerRejected` result)

### 7.5 XPath language
- [ ] Lexer/parser for full XPath 1.0 syntax used by ODK: absolute/relative location paths, `.`/`..`, `*`, `@attr`, predicates (multiple, nested), filter expressions, unions `|`, variables, numeric/string literals, all operators (`or and = != < <= > >= + - * div mod` unary `-`)
- [ ] Axes as JavaRosa supports (child, attribute, self, parent, descendant-or-self via `//` where supported) — unsupported axes raise `XPathUnsupportedException` identically
- [ ] `instance('id')/…`, `current()` (+ JavaRosa notes: `current()` in calculate = node itself; in itemset predicate = question node), relative refs with `../` across repeats
- [ ] Type system & coercion: string(), number(), boolean() conversions incl. NaN, ±Infinity, empty nodeset, date→number (days since epoch, fractional), string→date
- [ ] Comparison semantics: nodeset vs scalar existential comparisons, date comparisons, `=` on booleans
- [ ] Node ordering in nodesets (document order), lazy nodesets (`XPathLazyNodeset`), `count`, `sum`
- [ ] Error model: `XPathArityException`, `XPathTypeMismatchException`, `XPathUnhandledException` (unknown function), `XPathUnsupportedException`, `XPathMissingInstanceException`, `XPathSyntaxException` with position
- [ ] Reference analysis for DAG: collect referenced paths incl. inside predicates, `current()` paths, function args; `isIdempotent` analysis (predicate caching)
- [ ] Pivot / range-hint extraction from constraints (CmpPivot, Date/Decimal/Integer/StringLength range hints)

### 7.6 XPath function library — all functions implemented by JavaRosa
**Core / boolean / node:** `true` `false` `boolean` `not` `if` `coalesce` `count` `count-non-empty` `position` `instance` `depend` (non-standard) `boolean-from-string` `checklist` `weighted-checklist` `once`
**Number / math:** `number` `int` `round` (1- and 2-arg) `abs` `pow` `exp` `exp10` `log` `log10` `sqrt` `sin` `cos` `tan` `asin` `acos` `atan` `atan2` `pi` `min` `max` `sum` `random`
**String:** `string` `concat` `join` `substr` `substring-before` `substring-after` `contains` `starts-with` `ends-with` `string-length` `normalize-space` `translate` `regex` `uuid` (0- and 1-arg length) `digest` (MD5, SHA-1, SHA-256, SHA-384, SHA-512 × base64/hex) `base64-decode` `extract-signed` (Ed25519)
**Select:** `selected` `is-selected` `selected-at` `count-selected` `jr:choice-name` `randomize` (1- and 2-arg seeded; Park–Miller + Fisher–Yates exact)
**Date/time:** `today` `now` `date` `date-time` `decimal-date-time` `decimal-time` `format-date` `format-date-time` (ODK `%Y %y %m %n %b %d %e %H %h %M %S %3 %a` + localized names)
**Geo:** `area` `distance` (geopoint/geotrace/geoshape, multiple args or nodeset) `enclosed-area` `geofence`
**Repeat:** `indexed-repeat` (multi-level pairs, relative refs)
**Device / form:** `property` (non-standard: deviceid etc.) `version` (form version)
**Itext:** `jr:itext` (handler with form variants)
**Not implemented by JavaRosa** (`floor`, `ceiling`, `last`, `local-name`, `name`, `substring`, `lang`, `id`…): DartRosa **matches JavaRosa** (raises `XPathUnhandledException`) by default; optional `compat: XPathCompat.extended` flag may enable them later — never on by default.
**Collect-provided (see §8):** `pulldata`, `search()` appearance-driven itemsets.
**Custom:** `XPathFunction` plugin interface with arity validation + fallback handler (`IFallbackFunctionHandler`).

### 7.7 Dependency graph / recalculation (TriggerableDag, dag.md)
- [ ] Triggerables: `Condition` (relevant, readonly, required → true/false actions), `Recalculate` (calculate), `Constraint` (validation, not in DAG ordering)
- [ ] Trigger index: reference → triggerables, with generic (repeat-agnostic) references and contextualization per repeat instance
- [ ] Topological order computed at parse time; cycle detection with JavaRosa-equivalent error message (lists the cycle)
- [ ] Initialize on new form; initialize on loaded instance (respecting `once()` / already-filled calculations)
- [ ] Trigger on value change (cascade), on repeat insert, on repeat delete (incl. `position()`-dependent and `count()`-dependent recompute), on language change (itext-dependent outputs)
- [ ] `QuickTriggerable` dedup; children-of-relevance propagation; readonly calculate behaviour (ReadOnlyCalculateTest)
- [ ] Constraint evaluation only on answer + finalize; `required` checked on navigation/finalize as JavaRosa
- [ ] Revalidate whole form (`xforms-revalidate`) on finalize → list of failures with first-failure index
- [ ] Predicate/filter strategies: Raw, ComparisonExpressionCache, EqualityExpressionIndex, IdempotentExpressionCache — results must equal Raw strategy (property test)
- [ ] Debug trace stream (EvaluationResult/Event)

### 7.8 Preloaders (QuestionPreloader / PreloadUtils)
- [ ] `jr:preload="timestamp"` params `start` | `end` (end set at finalize)
- [ ] `jr:preload="date"` params `today`
- [ ] `jr:preload="property"` params `deviceid`, `subscriberid`, `simserial`, `phonenumber`, `username`, `email` (from `DeviceProperties`)
- [ ] `jr:preload="uid"` (instanceID — `uuid:` prefix)
- [ ] Custom `PreloadHandler` registration
- [ ] `meta/instanceID`, `meta/deprecatedID` (set when editing a finalized instance), `meta/instanceName` (calculate)

### 7.9 Actions & events
- [ ] Events: `odk-instance-first-load`, `odk-instance-load`, `xforms-ready` (deprecated alias), `odk-new-repeat`, `jr-insert` (deprecated alias), `xforms-value-changed`, `xforms-revalidate`
- [ ] Top-level vs nested (in-control, in-repeat) event listeners; event ordering relative to DAG initialization exactly as `InstanceLoadEventsTest` / `MultipleEventsTest` / `OdkNewRepeatEventTest`
- [ ] `setvalue` (ref, value attr or text content, relative refs inside repeats)
- [ ] `odk:setgeopoint` (stub in core; real location via delegate) incl. `xforms-value-changed` trigger
- [ ] `odk:recordaudio` (background audio; `odk:quality`) — handler + listener interface, platform via delegate
- [ ] Custom action registration (`ActionHandler`) — per config, not static

### 7.10 Secondary instances
- [ ] XML external (`XmlExternalInstance`), CSV (`CsvExternalInstance` — header row → element names, quoting, BOM, delimiter), GeoJSON (`FeatureCollection` → item with `geometry` as ODK geo string, properties, `id`), last-saved, internal
- [ ] Lazy/partial parse for large files where JavaRosa does; missing instance → `XPathMissingInstanceException` only when referenced
- [ ] Choice filters (itemset predicates) incl. `current()`, cascading selects, dynamic re-evaluation (DynamicSelectUpdateTest, SelectOneChoiceFilterTest, SelectMultipleChoiceFilterTest)
- [ ] Clearing now-invalid select answers when choices change (as JavaRosa)
- [ ] Instance provider plugin (`addInstanceProvider` / `addFileInstanceParser`)

### 7.11 Localization (Localizer)
- [ ] Languages list (form order), default language (`default="true()"` or first), set language at runtime
- [ ] Text forms: default/long, `short`, `image`, `big-image`, `audio`, `video`, `guidance`, `markdown`/raw HTML subset passthrough
- [ ] Fallback rules (missing form → default form; missing lang → default lang) identical
- [ ] `jr:itext()` in XPath, `<output>` substitution in localized text, choice labels
- [ ] Constraint/required messages per language
- [ ] Date-name localization for `format-date` (DateUtilsFormatLocalizationTests)

### 7.12 Form entry API — 1:1 mapping of JavaRosa public surface
| JavaRosa | DartRosa |
|---|---|
| `FormEntryController.answerQuestion(index?, data, midSurvey)` | `session.answer(ref, value, {bool validate = true})` → `AnswerResult` |
| `saveAnswer(index?, data, midSurvey)` (no constraint check) | `session.setValue(ref, value)` |
| `stepToNextEvent()` / `stepToPreviousEvent()` | `navigator.next()` / `navigator.previous()` → `FormEvent` |
| `jumpToIndex(index)` | `navigator.jumpTo(ref)` |
| `descendIntoRepeat`, `descendIntoNewRepeat`, `newRepeat(index?)`, `jumpToNewRepeatPrompt` | `navigator.enterRepeat(…)`, `session.addRepeatInstance(ref)`, `navigator.jumpToNewRepeatPrompt()` |
| `deleteRepeat(…)` (3 overloads) | `session.removeRepeatInstance(ref)` → returns adjusted `NodeRef` |
| `finalizeFormEntry()`, `addPostProcessor()` | `session.finalize()`, `config.finalizationProcessors` |
| `setLanguage()` | `session.language = …` |
| `addFilterStrategy()`, `addFunctionHandler()` | `config.filterStrategies`, `config.functions` |
| `FormEntryModel.getEvent/getFormIndex/setQuestionIndex/incrementIndex/decrementIndex` | `navigator.current`, `navigator.position`, `NodeRef.next/previous` |
| `getQuestionPrompt/getCaptionPrompt/getCaptionHierarchy` | `QuestionNode`, `CaptionView`, `node.ancestors` |
| `getLanguages/getLanguage/getFormTitle` | `def.languages`, `session.language`, `def.title` (localized) |
| `getCompletedRelevantQuestionCount/getTotalRelevantQuestionCount/getNumQuestions` | `session.progress` (record: completed, totalRelevant, total) |
| `isIndexReadonly/isIndexRelevant/isIndexCompoundContainer/isIndexCompoundElement/getCompoundIndices` | `node.isReadonly`, `node.isRelevant`, `GroupNode.isFieldList`, `node.fieldListChildren` |
| `getRepeatStructure` | `RepeatNode.structure` (simple/complex) |
| `getExtras` | `session.extras` / `def.extras` (typed `Extras` map keyed by `Type`) |
| `FormEntryPrompt.getAnswerValue/getAnswerText` | `q.value` / `q.displayValue` |
| `getQuestionText/getLongText/getShortText/getSpecialFormQuestionText/getAudioText/getImageText/getHelpText/getConstraintText` | `q.label` (`LocalizedText` with `.text`, `.short`, `.image`, `.bigImage`, `.audio`, `.video`), `q.hint`, `q.guidanceHint`, `q.constraintMessage`, `q.requiredMessage` |
| `getSelectChoices/getSelectChoiceText/getSelectItemText/getSpecialFormSelectChoiceText/getSpecialFormSelectItemText` | `q.choices` (`List<SelectChoice>` each with `LocalizedText label`, `value`, `index`) — re-evaluated lazily for itemsets |
| `getControlType/getDataType/getAppearanceHint/getPromptAttributes/getBindAttributes` | `q.controlType`, `q.dataType`, `q.appearance`, `q.attributes`, `q.bindAttributes` |
| `isRequired/isReadOnly/getMultiplicity/getIndex/getFormElement/getRepeatText/getRepetitionText/repeats()` | `q.isRequired`, `q.isReadonly`, `instance.index`, `q.ref`, `repeat.captions` |
| `requestConstraintHint(hint)` | `q.constraintHint` (range record or null) |
| `register/unregister/formElementStateChanged` | `node.changes` stream / `ValueListenable` adapter |

### 7.13 Navigation semantics (FormNavigationTestCase, FormIndexTest)
- [ ] Event sequence including group entry, field-list as one screen, repeat juncture, "add another?" prompt suppressed by `jr:count`/`noAddRemove`
- [ ] Skipping non-relevant nodes; relevance changes mid-navigation
- [ ] `FormIndex` ordering/compare/next/prev over nested repeats; serialization of index for resume (FormIndexSerializationTest → `NodeRef.toPathString()/parse`)
- [ ] Jump to beginning/end, jump into repeat instance, delete current repeat and land on correct index

### 7.14 Serialization & instance lifecycle
- [ ] Submission XML (XFormSerializingVisitor): only relevant nodes (non-relevant pruned), attributes, namespaces/prefixes, `jr:template` removed, empty elements, encoding UTF-8, answer serialization per type
- [ ] Draft save (all nodes incl. non-relevant values preserved as JavaRosa), load draft → identical state
- [ ] Edit finalized submission: new `instanceID`, old moved to `deprecatedID`
- [ ] Attachments list from binary answers (for multipart submission)
- [ ] Compact & SMS serializers (`dartrosa_compact`, optional)
- [ ] Form-definition cache (`FormDefinitionCodec`, versioned; invalidated by package version + form hash)

### 7.15 Plugin points (PLUGINS.md parity)
- [ ] Parse processors (element/attribute hooks; attach extras)
- [ ] Custom parser factory (wrap/chain) → `ParserExtension` list
- [ ] Finalization processors
- [ ] Instance providers / file instance parsers
- [ ] Function handlers + fallback handler
- [ ] Filter strategies (predicate evaluation)
- [ ] Action handlers
- [ ] Preload handlers

---

## 8. Collect-layer features (not in JavaRosa — needed for "everything" parity)

| Feature | Where it lives in Collect | DartRosa package |
|---|---|---|
| `pulldata('csv', col, keyCol, key)` | Collect external data handlers | `dartrosa_external_data` (in-memory index; optional sqlite for huge CSVs) |
| `search('csv' …)` appearance-driven itemsets | Collect | `dartrosa_external_data` |
| Entities: `entities:create/update`, `entities:saveto`, `entities:label`, `entities-version`, entity lists as secondary instances, offline entity updates | Collect `entities` module (parse + finalization processors) | `dartrosa_entities` |
| Encrypted submissions (RSA public key from `<submission>`, per-file AES, `submission.xml` manifest, `encryptedXmlFile`, signature) | Collect `EncryptionUtils` | `dartrosa_encryption` |
| `jr://instance/last-saved` population | Collect | core `InstanceProvider` + app hook |
| Form media `jr://images|audio|video|file|file-csv` resolution | Collect `ReferenceManager` roots | `dartrosa_io` resolver |
| Real `setgeopoint` / background `recordaudio` | Collect | `dartrosa_flutter` delegates |
| Audit log (`meta/audit` with `odk:location-*`, `odk:track-changes`, `odk:identify-user`, `odk:track-changes-reasons`) | Collect | `dartrosa_flutter` (audit service) + core change stream |
| External app launch (`intent` on groups/questions, `ex:` appearance) | Collect | `dartrosa_flutter` `externalApp` delegate |
| Form list / manifest / submission (OpenRosa), ODK Central API, form updates | Collect | `dartrosa_openrosa` (phase 9) |
| XLSForm → XForm | pyxform (Python) | out of scope v1; document "convert with pyxform / XLSForm Online / Central"; possible future `dartrosa_xlsform` |

---

## 9. Compatibility traps (must be handled explicitly)

| Trap | Why it bites | Plan |
|---|---|---|
| **Decimal → string** | Java `Double.toString` (`1.0E10`, `0.001`, `1.0`) ≠ Dart `toString` (`10000000000.0`, `0.001`). Affects calculate results stored in instance and `string()` | Port JavaRosa's exact number formatting (`DataUtil`/serializer rules); golden tests over 10k random doubles vs oracle |
| **64-bit ints on web** | Dart web ints are 53-bit (JS doubles). `long` type, `int()` truncation, digests | Use `BigInt` path for `LongValue` on web or document limit; tests run on VM **and** `dart test -p chrome` |
| **Dates & time zones** | JavaRosa uses Joda + device default TZ; dates are days-since-epoch numbers, times carry offsets, DST edges | Own `LocalDate/LocalTime/OffsetDateTime` value types; injectable `TimeZoneProvider` + `Clock`; port all `DateUtils*Tests` incl. SCTO tests; run suite in ≥ 4 TZs (UTC, America/New_York, Asia/Kolkata, Pacific/Chatham) |
| **Regex dialect** | `regex()` uses Java regex; Dart uses ECMAScript regex | Document differences; translate common Java-only constructs (possessive quantifiers, `\p{…}` handled with `unicode: true`); oracle-diff the regex corpus |
| **`randomize()` order** | Seeded order must equal Collect's so data is reproducible | Port `ParkMiller` and `FisherYates` bit-exactly (FisherYatesExamplesTest) |
| **Sorting/collation** | Java `String.compareTo` = UTF-16 code unit order; Dart `compareTo` same — keep, never use locale collation | test |
| **Floating-point math functions** | `pow`, `log`, trig produce same IEEE results but formatting differs | covered by number formatting |
| **Geo math** | `area`/`distance` use specific earth radius & algorithm in GeoUtils | Port GeoUtils exactly; GeoAreaTest/GeoDistanceTest |
| **Whitespace & text consolidation** | Labels with mixed text/`<output>`; trimming rules | Port XmlTextConsolidator + getXMLText(trim) semantics |
| **XML namespaces on output** | Collect/Central expect specific prefixes | Serializer golden files |
| **Empty vs missing values** | `""` vs null in nodesets, `count-non-empty`, `coalesce` | XPathEvalTest port |
| **Deprecated aliases** | `xforms-ready`, `jr-insert` still in real forms | Support + parse warning |

---

## 10. Test & conformance strategy

### 10.1 Layers
1. **Unit tests** per Dart library (lexer, parser, each function, each AnswerValue codec, TreeReference ops, DAG).
2. **Scenario tests** — port of JavaRosa `Scenario` DSL into `package:dartrosa/testing.dart`:
   ```dart
   final scenario = await Scenario.init('Some form', html(head(title('t'), model(mainInstance(...), bind('/data/a').type('int'))), body(input('/data/a'))));
   scenario.next();
   expect(scenario.answer('/data/a', 5), isA<AnswerAccepted>());
   expect(scenario.answerOf('/data/b'), const IntegerValue(10));
   ```
   The XFormsElement builder DSL (`TagXFormsElement`, `BindBuilderXFormsElement`, …) is ported so JavaRosa tests translate almost mechanically.
3. **Differential oracle** — `conformance/jvm_oracle` (Kotlin + JavaRosa 6.0.0) and `dartrosa_cli run` both execute `*.scenario.yaml` and emit a canonical JSON trace (events, values, relevance, validity, choices, serialized XML). CI diffs them. Any diff fails the build.
4. **Corpus test** — ≥ 300 real XLSForms (public KoboToolbox/ODK examples, HOT `osm-fieldwork`, WHO VA, child vaccination…) converted with pyxform; random-walk fuzzer answers questions with type-valid random values and compares traces with the oracle.
5. **Property tests** — filter strategies ≡ raw strategy; serialize(parse(x)) round-trip; DAG order invariant to bind order.
6. **Platform matrix** — `dart test` on VM, `-p chrome` (dart2js) and `--compiler dart2wasm`; Flutter widget & golden tests; integration test on Android + iOS emulators.
7. **Benchmarks** — `benchmark_harness`: parse, first-load, answer cascade, 1,000-instance repeat add, 100k-row CSV choice filter. Regression gate ±10 %.

### 10.2 Coverage gate
Line coverage ≥ 90 % for `dartrosa`; 100 % of public API members exercised.

### 10.5 1:1 JavaRosa test-class port map (all 130+ classes)
| Suite (phase) | JavaRosa test classes |
|---|---|
| XPath parse/eval (P1) | XPathParseTest, XPathEvalTest, XPathPathExprTest, XPathFilterExprTest, XPathBinaryOpExprTest, XPathUnaryOpExprTest, XPathFuncExprTest, XPathFuncAsSomethingTest, XPathConditionalTriggersTest, XPathNodesetShuffleTest, XPathProcessorTest, MultiplePredicateTest, CurrentTest, CurrentFieldRefTest, CurrentGroupCountRefTest, RelativeRefTest, TriggersForRelativeRefsTest, EvaluationContextExpandReferenceTest, CompareToNodeExpressionTest |
| Functions (P1) | DigestTest, EncodingEncodeTest, EncodingDecodeTest, Base64DecodeTest, ExtractSignedTest, RandomizeTest, RandomizeTypesTest, RandomizeHelperTest, FisherYatesTest, FisherYatesExamplesTest, ParkMillerTest, ToDateTest, DateTimeTest, GeoAreaTest, GeoDistanceTest, GeoUtilsTest, XPathFuncExprGeoPointDataTest, ChoiceNameTest, IndexedRepeatTest, IndexedRepeatRelativeRefsTest |
| Dates (P1/P2) | DateUtilsFormatTests, DateUtilsFormatSanityCheckTests, DateUtilsFormatLocalizationTests, DateUtilsParseDateTimeTests, DateUtilsParseTimeTests, DateUtilsGetXmlStringValueTest, DateUtilsSCTOTests |
| References & tree (P2) | TreeReferenceAnchorTest, TreeReferenceAnchorHarnessTest, TreeReferenceContextualizeTest, TreeReferenceEqualsTest, TreeReferenceGenericizeTest, TreeReferenceIsAncestorOfTest, TreeReferenceParentTest, TreeElementTests, TreeElementParserTest, TreeElementNameComparatorTest, SameRefDifferentInstancesIssue449Test, ReferenceManagerTest, ReferenceManagerTestUtils |
| Parsing (P2) | XFormParserTest, BindAttributeProcessorTest, SubmissionParserTest, AttributesTestCase, ChildProcessingTest, ExternalSecondaryInstanceParseTest, TextFormTests, QuestionDefTest, SelectChoiceTest, DataTypeClassesTest, FormDefTest, FormParseInit-based tests, LocalizerTest |
| Answer data (P2) | StringDataTests, IntegerDataTests, DateDataTests, TimeDataTests, TimeDataLimitationsTest, SelectOneDataTests, MultipleItemsDataTests, GeoPointDataTests, GeoShapeDataTest, GeoTraceDataTest, AnswerDataUtilTest, NumericEncodingTest, QuestionDataElementTests, QuestionDataGroupTests, XFormAnswerDataSerializerTest |
| DAG (P3) | TriggerableDagTest, RecalculateTest, ReadOnlyCalculateTest, PredicateCachingTest, SelectCachingTest, DynamicSelectUpdateTest |
| Form entry & navigation (P4) | FormEntryControllerTest, FormEntryModelTest, FormEntryPromptTest, FormNavigationTestCase, FormIndexTest, FormIndexSerializationTest, RepeatTest, ConstraintTextTest, SelectOneQuestionTest, OptionalChoicesQuestionTest, SelectOneChoiceFilterTest, SelectMultipleChoiceFilterTest |
| Actions & events (P4) | SetValueActionTest, SetGeopointActionTest, RecordAudioActionTest, InstanceLoadEventsTest, MultipleEventsTest, OdkNewRepeatEventTest, QuestionPreloaderTest |
| Secondary instances (P5) | CsvExternalInstanceTest, GeoJsonExternalInstanceTest, GeojsonGeometryTest, InstancePluginTest |
| Serialization (P6) | XFormSerializingVisitorTest, CompactSerializingVisitorTest, FormDefSerializationTest (→ codec round-trip), ExternalizableTest (→ codec), BufferedInputStreamTests (→ drop, SDK) |
| Real-world forms (P6) | ChildVaccinationTest, WhoVATest |

Tests whose subject is dropped (BufferedInputStreamTests, ExternalizableTest) are replaced by equivalent tests of the replacement (codec), never just deleted.

---

## 11. Phased delivery plan

Estimates: 1 senior Dart engineer full-time (≈ 0.6× with 2 engineers working in parallel on renderer/collect-layer from P5). Each phase ends with a tagged pre-release on pub.dev (`0.x`).

| Phase | Scope | Deliverables | Exit criteria | Est. |
|---|---|---|---|---|
| **P0 Foundations** | Monorepo (pub workspaces + melos), CI (analyze, format, test VM/chrome/wasm, coverage, oracle job), lint config, ADRs, JVM oracle harness, Scenario DSL skeleton, corpus import (pyxform conversion script) | repo, CI green, oracle produces traces for JavaRosa resources | CI runs oracle on 95 resources | 2 wk |
| **P1 XPath** | §7.5, §7.6 (all functions), dates/number formatting compat (§9) | `dartrosa` 0.1 (XPath) | XPath+Functions+Dates suites green; 10k-double formatting golden; VM+web | 5 wk |
| **P2 Parse & model** | §7.1–7.4, §7.11, TreeReference, answer codecs, reporter warnings | `dartrosa` 0.1 (parse-only) | References/Parsing/Answer-data suites green; parse of all corpus forms equals oracle structure dump | 5 wk |
| **P3 DAG** | §7.7, §7.8 | 0.2 | DAG suite green; property tests; cycle messages equal | 3 wk |
| **P4 Session & navigation** | §7.9, §7.12, §7.13, tree API + navigator, AnswerResult, finalize (no serialization yet) | 0.3 — **MVP engine** | Form-entry + Actions suites green; random-walk oracle diff = 0 on corpus subset without secondary instances | 4 wk |
| **P5 Secondary instances** | §7.10, InstanceProvider, filter strategies, last-saved | 0.4 | Secondary-instance suites green; 100k-row CSV filter < 50 ms | 3 wk |
| **P6 Serialization & lifecycle** | §7.14, codec cache, drafts/edit, compact/SMS (optional pkg), real-world tests | 0.5 | Serialization suites + ChildVaccination/WhoVA green; full-corpus oracle diff = 0 | 3 wk |
| **P7 Flutter renderer** | §12 (parallel from P4) | `dartrosa_flutter` 0.1 → 0.5 | Widget + golden tests for every ControlType × appearance; a11y checks; example app fills all corpus forms | 8 wk (parallel) |
| **P8 Collect layer** | §8: external data, entities, encryption, audit, intents | packages 0.1 | Entities spec fixtures pass; encrypted submission decrypts with ODK Briefcase/Central | 5 wk (parallel) |
| **P9 Server & polish** | `dartrosa_openrosa`, docs site, migration guide, perf hardening, 1.0 API freeze | 1.0.0 | §15 DoD met | 4 wk |

Critical path ≈ 25 weeks (P0–P6 + P9); with a second engineer on P7/P8 in parallel, **1.0 ≈ 7 months**.

---

## 12. Flutter renderer (`dartrosa_flutter`) design

### 12.1 Principles (Flutter rules)
- Widgets are **stateless where possible**; ephemeral UI state (text controller, focus, scroll) in `State`; form state lives only in `FormSession` — single source of truth, no duplicated state.
- Each node is exposed as a `ValueListenable<NodeSnapshot>` (immutable snapshot record) → `ValueListenableBuilder`/`ListenableBuilder` rebuild **only that question** on change (no whole-form `setState`).
- No state-management package dependency; provide `XFormScope` (`InheritedWidget`/`InheritedNotifier`) for descendant access.
- `const` constructors everywhere possible; keys (`ValueKey(ref)`) on repeat instances so deletion doesn't reuse wrong state.
- Platform features **never** called directly — all through `XFormDelegates` (abstract classes); default implementations shipped in an optional `dartrosa_flutter_plugins` package (image_picker, geolocator, mobile_scanner, record, file_picker, signature) so the core renderer has zero plugin dependencies and stays testable.
- Material 3 by default, fully themable via `XFormTheme` (`ThemeExtension`); Cupertino-friendly (adaptive widgets).
- Accessibility: `Semantics` labels from question label + required/constraint state, focus traversal order = form order, min 48dp targets, text scaling, screen-reader announcement on validation errors.
- i18n: RTL via `Directionality` derived from form language (ar, fa, he, ur…); UI chrome via `XFormLocalizations` delegate.
- Labels: ODK markdown subset (`*em*`, `**strong**`, `#` headers, links) + `<span style="color|font-family">` → rendered `TextSpan`s; media (image tap → big-image, audio play button, video).

### 12.2 Layout modes
- `pager` — one screen per navigator event (Collect-like), field-list groups render all children on one page, swipe/next/prev, "add repeat?" dialog, jump-to index (hierarchy view).
- `scroll` — whole visible tree (Enketo/Web Forms-like) with collapsible groups and repeat add/remove buttons.
- Validation display: inline error under question; on finalize, jump to first failure.

### 12.3 Widget catalogue (ControlType × appearance)
| Control | Default | Appearances to support |
|---|---|---|
| text input | TextField | `multiline`, `numbers`, `url`, `masked`, `ex:` (external app), `printer:`, `thousands-sep` (numeric) |
| integer/decimal | numeric TextField | `thousands-sep`, `counter`-style via intent, `bearing` (decimal) |
| date / time / dateTime | pickers | `no-calendar`, `month-year`, `year`, `ethiopian`, `coptic`, `islamic`, `bikram-sambat`, `myanmar`, `persian` |
| select one | radio list | `minimal` (dropdown), `quick` (auto-advance), `autocomplete`, `columns`, `columns-N`, `columns-pack`, `no-buttons`, `likert`, `label`, `list-nolabel`, `list`, `image-map` (SVG), `map`, `quickcompact`, `search(…)` |
| select multiple | checkbox list | `minimal`, `autocomplete`, `columns*`, `no-buttons`, `label`, `list-nolabel`, `image-map`, `map` |
| rank | reorderable list | — |
| range | Slider | `vertical`, `picker`, `rating`, `no-ticks` |
| geopoint / geotrace / geoshape | location capture | `maps`, `placement-map`, `hidden-answer`, accuracy thresholds (`accuracyThreshold`, `unacceptableAccuracyThreshold`) |
| image | camera/gallery | `signature`, `draw`, `annotate`, `new`, `new-front`, `selfie`, `orx:max-pixels` |
| audio / video / file | capture/pick + preview | `new`, `new-front`, `quality` |
| barcode | scanner | `front` |
| trigger / note | acknowledge / read-only text | — |
| OSM | external OSM app via delegate | — |
| group | section / page | `field-list`, `table-list`, `intent` |
| repeat | list of instances | `jr:count`, `noAddRemove`, `field-list` |

Unknown appearances fall back to the default widget and emit a debug warning. Every widget is replaceable via `widgetOverrides` (open/closed).

### 12.4 Renderer tests
Widget tests per control/appearance, golden tests (light/dark, LTR/RTL, text scale 1.0/2.0), integration tests driving the corpus forms end-to-end, `flutter test --platform chrome`.

---

## 13. Performance, isolates, web

- Parse via `Isolate.run` in `dartrosa_io`/`dartrosa_flutter` helpers (`FormDefinition` is plain immutable data, so it transfers); on web parsing runs inline (or in a web worker later).
- Engine is single-isolate and synchronous (ADR-4); target < 16 ms per answer cascade. Use incremental DAG evaluation, cached compiled XPath, interned names, `EqualityExpressionIndex` for big itemsets.
- Large CSVs: streaming parse, columnar storage, hash index on filtered columns.
- Memory: share `FormDefinition` between sessions; instance tree nodes are compact (no per-node maps for absent properties).
- Web/WASM: no `dart:io`; `LongValue` precision note; test on dart2js & dart2wasm.

---

## 14. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Subtle semantic divergence (coercion, dates, numbers) | Wrong data collected | Oracle on every PR; corpus random-walk; multi-TZ runs |
| Spec evolution (new functions, entities versions) | Parity drift | Track `getodk/xforms-spec`, `javarosa`, `web-forms` releases; monthly sync issue; scenario per change |
| Over-engineering the API | Hard to adopt | Public API review gate per phase; ≤ ~30 public types in core |
| Renderer scope explosion (appearances) | Delay | Catalogue (§12.3) is the contract; overrides let apps fill gaps |
| Performance on low-end devices | Poor UX | Benchmarks from P1, AOT profiling on a 2 GB RAM Android device |
| Licensing / trademark | Legal | Apache-2.0, NOTICE, no "ODK" in package names, credit JavaRosa |

---

## 15. Definition of Done (v1.0)

- [ ] Every checklist item in §7 and §8 ticked with linked tests
- [ ] 100 % of JavaRosa test classes ported (§10.5) and green on VM, Chrome, WASM
- [ ] Oracle diff = 0 on full conformance corpus (≥ 300 forms + random walks)
- [ ] `dart analyze` clean with strict config; `dart format` clean; public API 100 % documented; pana score 160/160
- [ ] No global mutable state; no `dart:io`/Flutter imports in core (enforced by a CI import-lint)
- [ ] Benchmarks within targets (§1)
- [ ] Example app fills, saves, resumes, edits, finalizes, encrypts and exports every corpus form
- [ ] Docs: getting started, API reference, JavaRosa → DartRosa migration guide, compatibility matrix, plugin guide
