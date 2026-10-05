# Migrating from JavaRosa

DartRosa ports JavaRosa 6.0.0's behaviour exactly (the conformance suite
diffs it against real JavaRosa on 401 forms), but its structure follows
Dart idioms. This guide maps JavaRosa types and calls to DartRosa, lists
what behaves differently and what was intentionally left out.

DartRosa offers two APIs over the same engine:

| Library | What it is | Use it when |
|---|---|---|
| `package:dartrosa/dartrosa.dart` | The session API: `FormDefinition`, `FormSession`, `FormNavigator`, the `FormNode` tree, `AnswerValue`s, typed results | New code, Flutter apps |
| `package:dartrosa/javarosa.dart` | The JavaRosa-compatible surface: `FormDef`, `FormEntryController`/`Model`/`Prompt`/`Caption`, `XFormParser` and its processors, `TreeElement`, XPath AST, filter strategies, `Localizer`, `FormDefCodec` | Porting JavaRosa code or plugins 1:1, or needing the full surface |
| `package:dartrosa/testing.dart` | `Scenario` and the `XFormsElement` form-building DSL | Testing forms the way JavaRosa's tests do |

The two compose: `FormDefinition.formDef` is the underlying `FormDef`, and
the session API is built on `FormEntryController`. Most apps import both
`dartrosa.dart` and, for plugin work, `javarosa.dart`.

## Class map

"Library" says which import exports the Dart type (`dartrosa`, `javarosa`,
`testing`); "internal" means it exists under `lib/src` but is not exported.

### Forms, entry and navigation

| JavaRosa | DartRosa | Library | Notes |
|---|---|---|---|
| `XFormUtils.getFormFromInputStream` / `getFormFromFormXml` / `getFormRaw` | `FormDefinition.parse(xml, config:)` → `Future<FormDefinition>`; or `XFormParser(resolver:).parse(xml)` → `Future<FormDef>` | dartrosa / javarosa | Asynchronous (secondary instances are read through a `ResourceResolver`). |
| `XFormUtils.setXFormParserFactory`, `IXFormParserFactory` | `DartRosaConfig.parseProcessors`, `DartRosaConfig.plugins` (`FormLoadPlugin.createParseProcessors`) | dartrosa | No static factory; processors are per configuration. |
| `XFormParser` | `XFormParser` | javarosa | `addProcessor`, `registerActionHandler`, `onWarning` are instance methods. |
| `XFormParser.Processor` subinterfaces (`BindAttributeProcessor`, `FormDefProcessor`, `ModelAttributeProcessor`, `QuestionProcessor`, `XPathProcessor`, `ExternalDataInstanceProcessor`) | same names, top-level interfaces | javarosa | |
| `XFormParseException` | `XFormParseException` | dartrosa | |
| `FormDef` | `FormDef` (mutable form + instance); `FormDefinition` (session factory) | javarosa / dartrosa | `FormDef.validate()` is the `FormDefValidation.validate()` extension. |
| `FormEntryController` | `FormEntryController`; or `FormSession` + `FormNavigator` | javarosa / dartrosa | See the method map below. |
| `FormEntryModel` | `FormEntryModel`; or `FormSession` / `FormNavigator` | javarosa / dartrosa | |
| `FormEntryPrompt` | `FormEntryPrompt`; or `QuestionNode` | javarosa / dartrosa | |
| `FormEntryCaption` | `FormEntryCaption`; or `FormNode.label` (`LocalizedText`), `RepeatInstanceNode.header` | javarosa / dartrosa | |
| `FormEntryFinalizationProcessor` | `FormEntryFinalizationProcessor` | javarosa | Register through `DartRosaConfig.finalizationProcessors` (= `addPostProcessor`). |
| `FormIndex` | `FormIndex` | dartrosa | |
| `IFormElement`, `GroupDef`, `QuestionDef`, `RangeQuestion` | `FormElement`, `GroupDef`, `QuestionDef`, `RangeQuestion` | dartrosa | |
| `SelectChoice`, `Selection` | `SelectChoice`, `Selection` | dartrosa | `Selection.attachChoice(q)` is `QuestionDef.attachChoice(selection)`, returning a new selection. |
| `Constants.CONTROL_*` | `ControlType` enum | dartrosa | |
| `Constants.DATATYPE_*`, `DataTypeClasses` | `DataType` enum | dartrosa | |
| `SubmissionProfile` | `SubmissionProfile` (on `FormDef`) | internal type, reachable from `FormDef` | |

### Answers (`IAnswerData` → sealed `AnswerValue`)

All answers are immutable, non-nullable values with value equality.
`getValue()` is `value`, `getDisplayText()` is `displayText`,
`uncast()` is `uncast()`.

| JavaRosa | DartRosa (`dartrosa`) |
|---|---|
| `IAnswerData` | `AnswerValue` (sealed) |
| `UncastData` | `UncastValue` |
| `StringData` | `StringValue` |
| `IntegerData` | `IntegerValue` |
| `LongData` | `LongValue` |
| `DecimalData` | `DecimalValue` |
| `BooleanData` | `BooleanValue` |
| `DateData` / `TimeData` / `DateTimeData` | `DateValue` / `TimeValue` / `DateTimeValue` (over `DateTime`) |
| `SelectOneData` | `SelectOneValue` |
| `MultipleItemsData` / `SelectMultiData` | `MultipleItemsValue` / `SelectMultiValue` |
| `GeoPointData` / `GeoTraceData` / `GeoShapeData` | `GeoPointValue` / `GeoTraceValue` / `GeoShapeValue` |
| `PointerAnswerData` / `MultiPointerAnswerData`, `IDataPointer` | `PointerValue` / `MultiPointerValue`, `DataPointer` |
| `IExprDataType` | `ExprDataType` |
| `AnswerDataFactory`, `XFormAnswerDataParser` | applied by `FormSession.answer` when given an `UncastValue`; `XFormParser`'s `AnswerResolver` for loaded instances |

### Instance model and XPath

| JavaRosa | DartRosa | Library | Notes |
|---|---|---|---|
| `TreeReference`, `TreeReferenceLevel` | `TreeReference`, `TreeReferenceLevel` | dartrosa (`TreeReference`) | Immutable: `anchor`, `contextualize`, `genericize`, `parent`, `isAncestorOf`, `extend` return new references. |
| `TreeElement`, `AbstractTreeElement` | `TreeElement` | javarosa | `accept(ITreeVisitor)` → `selfAndDescendants`. |
| `DataInstance`, `FormInstance`, `ExternalDataInstance` | same names | javarosa | |
| `XPathReference`, `IDataReference` | `TreeReference` | dartrosa | The wrapper added nothing. |
| `XPathParseTool.parseXPath` | `parseXPath` | javarosa | |
| `XPathExpression` and `XPath*Expr` AST classes | same names | javarosa | |
| `XPathNodeset` / `XPathLazyNodeset` | `XPathNodeset` | javarosa | |
| `XPathException` family (`XPathSyntaxException`, `XPathTypeMismatchException`, `XPathUnhandledException`, `XPathArityException`, `XPathUnsupportedException`, `XPathMissingInstanceException`) | same names | dartrosa | |
| `EvaluationContext` | `EvaluationContext` | javarosa | |
| `IFunctionHandler` | `XPathFunctionHandler` (`name`, `prototypes`, `rawArgs`, `eval(args, context)`) | javarosa | Register with `DartRosaConfig.functions`. |
| `IFallbackFunctionHandler` | `XPathFallbackFunctionHandler` | javarosa | |
| `FilterStrategy`, `RawFilterStrategy`, the `ComparisonExpressionCache` / `EqualityExpressionIndex` / `IdempotentExpressionCache` strategies | `FilterStrategy`, `RawFilterStrategy`, `ComparisonExpressionCacheFilterStrategy`, `EqualityExpressionIndexFilterStrategy`, `IdempotentExpressionCacheFilterStrategy` | javarosa | Add yours with `DartRosaConfig.filterStrategies`. |
| `Condition`, `Recalculate`, `Constraint`, `Triggerable`, `TriggerableDag` | same names | javarosa | `QuickTriggerable` folded into `Triggerable`. |
| Pivots / range hints (`CmpPivot`, `IntegerRangeHint`, …, `ConstraintHint`) | same names | javarosa | |
| `EventNotifier` / `Event` / `EvaluationResult` | `FormDef.addEventListener` with `EvaluationEvent` / `EvaluationResult`; `FormSession.changes` (`Stream<FormChange>`) | javarosa / dartrosa | |

### Plugins, resources, i18n

| JavaRosa | DartRosa | Library | Notes |
|---|---|---|---|
| `ReferenceManager.instance()` (global), `RootTranslator`, `PrefixedRootFactory`, `ReferenceFactory`, `Reference` | per-instance `ReferenceManager`, `RootTranslator`, `PrefixedRootFactory`, `ReferenceFactory`, `Reference`; `ReferenceManagerResolver` adapts one to `ResourceResolver` | dartrosa | No global state; `Reference` has `uri`/`localUri` only (no streams). |
| (stream reading through `Reference`) | `ResourceResolver` (`Future<Uint8List> read(uri)`), `MapResourceResolver`, `ResourceNotFoundException` | dartrosa | Pass as `DartRosaConfig.resolver`. |
| `org.javarosa.core.reference.InvalidReferenceException` | `InvalidReferenceUriException` | internal | Renamed to avoid clashing with the tree `InvalidReferenceException`. |
| `ExternalInstanceParser`, `ExternalInstanceParser.InstanceProvider`, `.FileInstanceParser`, `XFormUtils.setExternalInstanceParserFactory` | `ExternalInstanceParser` (`addInstanceProvider`, `addFileInstanceParser`), top-level `InstanceProvider`, `FileInstanceParser` | javarosa | Pass as `DartRosaConfig.externalInstanceParser`. |
| `IPreloadHandler`, `QuestionPreloader` | `PreloadHandler` (dartrosa), `QuestionPreloader` (javarosa) | | Register with `DartRosaConfig.preloadHandlers`. |
| `PropertyManager` (global), `IPropertyManager` | `PropertyManager` interface, `MapPropertyManager` | dartrosa | `DartRosaConfig.properties`. |
| `SetGeopointAction`, `RecordAudioActions` static listener | `SetGeopointAction` via `DartRosaConfig.setGeopointAction`; `FormDef.recordAudioListener` | dartrosa config / javarosa | |
| `Localizer` | `Localizer` (`FormDef.localizer`) | javarosa | Static `Localization` is not ported. |
| `Extras<T>` (`FormDef.getExtras`, `FormEntryModel.getExtras`) | `Extras<T>` with `put(extra)` / `get<U>()` keyed by type (`FormDef.extras`); `FormSession.extras` / `FormEntryModel.extras` is a `Map<Object, Object?>` | javarosa | |
| `XFormSerializingVisitor` | `FormSession.saveDraft()` (all values) and `FormSession.finalize()` → `Submission.xml` (relevant values) | dartrosa | The visitor itself is internal; `createSerializedPayload` → `Submission.attachments`. |
| `CompactSerializingVisitor`, `SMSSerializingVisitor`, `DataModelSerializer` | same names | internal | Ported and tested, not exported. |
| `Externalizable` `FormDef` serialization, `PrototypeManager`, `ExtUtil`, `XFormUtils.getFormFromSerializedResource` | `FormDefCodec.encode(FormDef)` → `Uint8List`, `FormDefCodec.decode(bytes, {resolver, parser})` → `Future<FormDef>`, `FormDefCodec.cacheKey(xml)` | javarosa | Stores source XML + full instance + language; restores by re-parsing (see below). |
| `Measure` static counters | `Measure.withMeasure` (zone-scoped) | internal | |

### Test support

| JavaRosa | DartRosa (`testing`) | Notes |
|---|---|---|
| `org.javarosa.test.Scenario` | `Scenario` | `Scenario.init(XFormsElement)` / `Scenario.fromXml(xml)` are async. `answer(xpath, value)` takes any value type instead of overloads; `answerCurrent(value)`; `createNewRepeat()` at the current index is `createNewRepeatHere()`. |
| `XFormsElement` DSL (`html`, `head`, `model`, `mainInstance`, `t`, `bind`, `input`, `select1`, `repeat`, …; `TagXFormsElement`, `BindBuilderXFormsElement`, `StringLiteralXFormsElement`, `EmptyXFormsElement`) | same functions and classes | Bind builders use cascades: `bind('/data/a')..type('int')..required()`. |

## Method map: `FormEntryController` / `FormEntryModel` → session API

| JavaRosa | `javarosa.dart` | `dartrosa.dart` |
|---|---|---|
| `new FormEntryController(new FormEntryModel(formDef))` | `FormEntryController(FormEntryModel(formDef))` | `definition.createSession()` |
| `answerQuestion(index, data, midSurvey)` → `ANSWER_*` int | `answerQuestion(data, index:, midSurvey:)` → `AnswerStatus` | `session.answer(index, value)` → `AnswerResult` |
| `saveAnswer(index, data, midSurvey)` | `saveAnswer(data, index:, midSurvey:)` | `session.answer(index, value, validate: false)` |
| `stepToNextEvent()` / `stepToPreviousEvent()` → `EVENT_*` int | same names → `FormEntryEvent` | `navigator.next()` / `navigator.previous()` |
| `jumpToIndex(index)` | `jumpToIndex(index)` | `navigator.jumpTo(index)`, `jumpToBeginning()`, `jumpToEnd()` |
| `descendIntoNewRepeat()` | same | `navigator.addRepeatAndEnter()` |
| `newRepeat(index)` | `newRepeat([index])` | `session.addRepeatInstance(repeatIndex)` |
| `deleteRepeat(int)` / `deleteRepeat(FormIndex)` | `deleteRepeatAt(int)` / `FormDef.deleteRepeat(index)` | `session.removeRepeatInstance(index)` |
| `jumpToNewRepeatPrompt()` | same | `navigator.jumpToNewRepeatPrompt()` |
| `setLanguage(l)` / `getLanguage()` | `language = l` / `language` | `session.language = l` |
| `finalizeFormEntry()`; `FormDef.validate()` | `finalizeFormEntry()`; `formDef.validate()` → `ValidateOutcome?` | `session.finalize()` → `FinalizeSuccess(submission)` / `FinalizeFailure(failure)` |
| `addPostProcessor`, `addFunctionHandler`, `addFilterStrategy` | `addPostProcessor`; `FormDef.addFunctionHandler`, `addFilterStrategy` | `DartRosaConfig(finalizationProcessors:, functions:, filterStrategies:)` |
| `getModel().getFormIndex()` / `getEvent()` | `model.formIndex` / `model.event()` | `navigator.position` / `navigator.event` |
| `getQuestionPrompt()` / `getCaptionPrompt()` / `getCaptionHierarchy()` | `questionPrompt()` / `captionPrompt()` / `captionHierarchy()` | `navigator.current` (`QuestionNode`), `node.label`, `node.ancestors` |
| `isIndexRelevant` / `isIndexReadonly` | same names | `node.isRelevant` / `node.isReadonly` |
| `getLanguages()` / `getFormTitle()` | `languages` / `formTitle` | `definition.languages` / `definition.title` |
| `FormEntryPrompt.getAnswerValue()` / `getAnswerText()` | `answerValue` / `answerText` | `question.value` / `question.displayValue` |
| `getQuestionText()`, `getLongText()`, `getShortText()`, `getImageText()`, `getAudioText()`, `getSpecialFormQuestionText(f)` | `questionText()`, `longText`, `shortText`, `imageText`, `audioText`, `specialFormQuestionText(f)` | `node.label.text`, `.short`, `.image`, `.audio`, `.video`, `.bigImage`, `.guidance` |
| `getHelpText()` / `getConstraintText()` | `helpText` / `constraintText()` | `question.hint`, `question.guidanceHint`, `question.constraintMessage`, `question.requiredMessage` |
| `getSelectChoices()`, `getSelectChoiceText(c)`, `getSpecialFormSelectChoiceText(c, f)` | `selectChoices`, `selectChoiceText(c)`, `specialFormSelectChoiceText(c, f)` | `question.choices`, `question.choiceLabel(c)`, `question.choiceMedia(c, f)` |
| `getControlType()`, `getDataType()`, `getAppearanceHint()`, `getBindAttributes()` | `controlType`, `dataType`, `appearanceHint`, `bindAttributes` | `question.controlType`, `.dataType`, `.appearance`, `.bindAttributes`, `.attributes` |
| `isRequired()` / `isReadOnly()` | `isRequired` / `isReadOnly` | `question.isRequired` / `question.isReadonly` |
| `getRepetitionText(...)` | `repetitionText(newRepeat:)` | `RepeatInstanceNode.header` |

## Before and after

JavaRosa:

```java
FormDef form = XFormUtils.getFormFromInputStream(in);
FormEntryController fec = new FormEntryController(new FormEntryModel(form));
fec.addFunctionHandler(new MyFunction());
form.initialize(true, new InstanceInitializationFactory());
while (fec.stepToNextEvent() != FormEntryController.EVENT_END_OF_FORM) {
  if (fec.getModel().getEvent() == FormEntryController.EVENT_QUESTION) {
    int status = fec.answerQuestion(new IntegerData(5), true);
    if (status == FormEntryController.ANSWER_CONSTRAINT_VIOLATED) {
      String msg = fec.getModel().getQuestionPrompt().getConstraintText();
    }
  }
}
```

DartRosa, session API:

```dart
final definition = await FormDefinition.parse(
  xml,
  config: DartRosaConfig(functions: [MyFunction()]),
);
final session = definition.createSession(); // initializes the instance
final nav = session.navigator;
while (nav.next() != FormEntryEvent.endOfForm) {
  if (nav.current case final QuestionNode q) {
    switch (session.answer(q.index, const IntegerValue(5))) {
      case AnswerConstraintViolated(:final message):
        messages.add(message);
      case AnswerAccepted() || AnswerRequired() || AnswerRejected():
        break;
    }
  }
}
```

DartRosa, JavaRosa-compatible API (closest to a line-by-line port):

```dart
final form = await XFormParser().parse(xml);
form.addFunctionHandler(MyFunction());
final fec = FormEntryController(FormEntryModel(form));
form.initialize(newInstance: true);
while (fec.stepToNextEvent() != FormEntryEvent.endOfForm) {
  if (fec.model.event() == FormEntryEvent.question) {
    final status = fec.answerQuestion(
      const IntegerValue(5),
      midSurvey: true,
    );
    if (status == AnswerStatus.constraintViolated) {
      messages.add(fec.model.questionPrompt().constraintText());
    }
  }
}
```

## Naming conventions

- **No `I` prefix**: `IFunctionHandler` → `XPathFunctionHandler`,
  `IAnswerData` → `AnswerValue`, `IFormElement` → `FormElement`,
  `IPreloadHandler` → `PreloadHandler`, `IFallbackFunctionHandler` →
  `XPathFallbackFunctionHandler`.
- **Getters and setters** instead of `getX()`/`setX()`/`isX()`:
  `getFormIndex()` → `formIndex`, `setLanguage(l)` → `language = l`,
  `getAnswerValue()` → `answerValue`. Methods that take arguments stay
  methods without the `get` prefix (`getSelectChoiceText(c)` →
  `selectChoiceText(c)`).
- **Enums instead of int constants**: `EVENT_*` → `FormEntryEvent`
  (each value keeps JavaRosa's number as `code`), `ANSWER_*` →
  `AnswerStatus`, `REPEAT_STRUCTURE_*` → `RepeatStructure`,
  `CONTROL_*` → `ControlType`, `DATATYPE_*` → `DataType`.
- **No overloads**: optional/named parameters instead
  (`answerQuestion(data, {index, midSurvey})`); where two overloads did
  different things, the second got a new name (`deleteRepeat(int)` →
  `deleteRepeatAt`, `Scenario.createNewRepeat()` → `createNewRepeatHere()`).
- **lowerCamelCase constants**, `snake_case.dart` files, everything not in
  the three public libraries lives under `lib/src`.

## What behaves differently

### Asynchronous loading, synchronous engine

Parsing returns a `Future` because external secondary instances
(`jr://file/…`, `jr://file-csv/…`, last-saved) are read through the async
`ResourceResolver`. Once a form is loaded, answering, recalculation,
validation and navigation are synchronous, as in JavaRosa.
`FormDefCodec.decode` is also async for the same reason.

### Typed results instead of status codes

`FormSession.answer` returns a sealed `AnswerResult`: `AnswerAccepted`,
`AnswerRequired(message)`, `AnswerConstraintViolated(message)` or
`AnswerRejected(message)`. `AnswerRejected` is new: JavaRosa would throw
or silently cast when given text that isn't the question's type, a value
of another type, or a choice the question doesn't offer; the session API
rejects those without saving. `FormSession.finalize` returns
`FinalizeSuccess(Submission)` or `FinalizeFailure(ValidationFailure)`
instead of a boolean plus a separate validation call. The JavaRosa-
compatible `FormEntryController` keeps JavaRosa's semantics with the
`AnswerStatus` enum.

### Exceptions

Exceptions remain for malformed input and programmer errors:
`XFormParseException`, the `XPathException` family,
`TriggerableEvaluationException` (JavaRosa's `RuntimeException("Error
evaluating field …")`, same message), `ResourceNotFoundException`. Where
JavaRosa threw a plain `RuntimeException` during parsing, DartRosa throws
`XFormParseException` with the same message. A few JavaRosa crashes are
reported as the error they are (non-ASCII digits in XPath numbers,
undefined XPath variables); see
[`conformance/DEVIATIONS.md`](../conformance/DEVIATIONS.md).

### No global state

Everything JavaRosa keeps in statics (`ReferenceManager`,
`PropertyManager`, `Localization`, `XFormUtils` parser factories,
`XFormParser` action handlers and processors, `ExternalInstanceParser`
registries, the `RecordAudioActions` listener, `Measure` counters) is
per-instance, mostly gathered in the immutable `DartRosaConfig`.

### Java-exact values

- **Numbers**: decimals are formatted like Java's `Double.toString`
  (`1.0E10`, `1.0`), exported as `javaDoubleToString`; `int()`, `round()`
  and number parsing follow Java (`javaParseDouble`, `javaParseInt`).
  `String.trim()` is replaced by `javaTrim` (Java trims only characters
  `<= ' '`; Dart also strips Unicode spaces).
- **`randomize()`**: Park–Miller and Fisher–Yates are ported bit-exactly,
  so seeded orders equal Collect's.
- **Java `HashMap` order**: where JavaRosa's output depends on `HashMap`
  iteration order (namespace declarations on the submission's root
  element), DartRosa reproduces it (`javaHashMapOrder`), so submissions
  are byte-identical. Where JavaRosa's order is non-deterministic
  (identity-hash sets in the DAG), DartRosa uses registration order, one
  of JavaRosa's possible orders.

### Dates and times

- Values are Dart `DateTime`s; "now" comes from `package:clock`, so tests
  can fix it with `withClock`.
- **Hybrid Julian/Gregorian calendar**: like `java.util.GregorianCalendar`
  (which JavaRosa reaches through Joda's `LocalDateTime.toDate()`), dates
  before the Gregorian cutover (1582-10-15) are Julian, the ten skipped
  days are accepted leniently, and year 0 is 1 BC. Dart's `DateTime` is
  proleptic Gregorian, so DartRosa converts explicitly (`date_utils.dart`).
- **Local zone**: dates are local midnights and date/time fields are read
  in the device's zone, as in JavaRosa. Local wall times are converted to
  instants the way Joda does: in a DST gap the time moves forward, in an
  overlap the earlier instant wins; `decimal-time` uses the offset in
  effect now, as JavaRosa does. Dart cannot change the zone at runtime,
  so JavaRosa tests that call `TimeZone.setDefault` run only when the
  process `TZ` matches (CI runs the suite under several zones).
- **Locale** for `format-date` names (`%b`, `%a`) and week numbers is an
  explicit parameter defaulting to `en_US`, not the JVM default locale.

### `regex()`

Dart `RegExp` (ECMAScript dialect) anchored as `^(?:pattern)$`, with
leading `(?i)`, `(?s)`, `(?m)` flags translated. Java-only syntax
(possessive quantifiers, atomic groups, `\p{Alpha}`-style POSIX classes,
`\Q…\E`) does not compile. Common ODK patterns behave identically.

### 64-bit integers on the web

`LongValue` holds a Dart `int`: exact to 2^63 on the VM and native
targets, but only to 2^53 under dart2js (JavaScript numbers).

### Form caching

JavaRosa (and Collect's `.formdef` cache) serializes the `FormDef` object
graph with `Externalizable`. `FormDefCodec` instead stores the source
XML, the whole main instance (non-relevant values included) and the
language, and restores by parsing again and loading the instance; the
observable state is the same, but restoring costs a parse. Use
`FormDefCodec.cacheKey(xml)` to key a cache: it changes with the form or
the codec version.

### Other structural changes

Immutable `TreeReference` and answers; `TreeElement.accept(visitor)` →
`selfAndDescendants`; `FormDef.initialize(newInstance:)` without the
unused `InstanceInitializationFactory`; `XFormParser.setAnswerResolver`
(static) → `AnswerResolver` passed to `parse(instanceXml:)` /
`loadXmlInstance`; `QuestionDef.getChildren()` returns an empty list, not
`null`. The full list is in
[`conformance/DEVIATIONS.md`](../conformance/DEVIATIONS.md).

## Not ported, on purpose

From the porting plan (§6, "DROP" rows) and `DEVIATIONS.md`:

| JavaRosa | Why |
|---|---|
| `CoreModelModule`, `XFormsModule`, `PrototypeManager`, `PrototypeFactory`, `Class.forName` | Reflection-based prototype registration; Dart uses explicit types (tree-shakable, no `dart:mirrors`). |
| `Externalizable`, `ExtUtil`, `ExtWrap*` | Replaced by `FormDefCodec` (no binary compatibility with JavaRosa's cache — a non-goal). |
| `core/model/util/restorable` (`Restorable`, `RestoreUtils`, …) | J2ME record-store restore. |
| `CompactInstanceWrapper`, `ModelReferencePayload`, `core/services/transport/payload` | SMS / compact transport payloads; payload transport is the app's job (the compact and SMS *serializers* are ported). |
| `core/services/storage`, `ProgramFlow`, `IModule`, `State`, `StateMachine`, `MemoryUtils` | J2ME application framework; storage is an app concern. |
| Static `Localization`, `ResourceFileDataSource`, `ReferenceDataSource` | Global state and classpath/`jr://` locale files; apps create a `Localizer`. |
| `Logger`, `ILogger`, `core/log` | Replaced by `package:logging` (silent unless the app listens). |
| `Base64`, `SHA1`, `OrderedMap`, `SortedIntSet`, `CacheTable`, stream/timer utilities, `BufferedInputStream`, KXml interning | Replaced by `dart:convert`, `package:crypto`, SDK collections and `package:xml`. |
| `XFormUtils` static factories | Replaced by `FormDefinition.parse` / `XFormParser` with `DartRosaConfig`. |
| `formmanager`, `IQuestionWidget`-based UI | The UI is `dartrosa_flutter` (`QuestionWidget` + `FormEntryCaption.register` remain for listeners). |
| `Reference` stream methods (`getStream`, `getOutputStream`, `remove`, …) | The core does no I/O; apps read `Reference.localUri` or implement `ResourceResolver`. |
| `TreeElement.tryBatchChildFetch` | Dead code in JavaRosa 6.0.0. |
| `EvaluationContext.setPredicateProcessSet` | Progress counters for a UI JavaRosa doesn't have. |
| `Localizer.equals`, `TableLocaleSource.equals` | Only used by JavaRosa's serialization tests. |

XPath functions JavaRosa doesn't implement (`floor`, `ceiling`, `last`,
`name`, `substring`, …) are not implemented either: like JavaRosa,
DartRosa raises `XPathUnhandledException`, so forms that fail in Collect
fail the same way.
