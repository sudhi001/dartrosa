# Intentional deviations from JavaRosa

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
| `TreeElement.populate` / `populateTemplate` | ported with the XForm parser and instance loading (P2/P6) | Need `FormDef`. |
