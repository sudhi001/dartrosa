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

## Unseeded `randomize()` and other run-dependent values

Not a behavioural deviation: traces normalize them (see TRACE_FORMAT.md).
