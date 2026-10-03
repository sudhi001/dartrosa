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

## Unseeded `randomize()` and other run-dependent values

Not a behavioural deviation: traces normalize them (see TRACE_FORMAT.md).
