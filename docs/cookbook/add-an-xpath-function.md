# Add a custom XPath function

**Type:** recipe. **Package:** `dartrosa`.

Form rules are XPath expressions, and ODK defines a large function
library (`if`, `regex`, `selected`, `pulldata`, dates, geometry, ...).
When a form needs something the library doesn't have, such as checking a
national ID's check digit, you can register a Dart function under a new
name and call it from constraints, calculations and relevance.

This recipe adds `luhn(.)`, which checks the check digit of a card or ID
number, using the following steps:

1. Write the function.
2. Register it in the `DartRosaConfig`.
3. Use it in the form.

## 1. Write the function

Extend `XPathFunctionHandler` (from `package:dartrosa/javarosa.dart`):
give it a name, the argument types it accepts, and `eval`.

```dart
// luhn('79927398713') is true: the number's check digit is right.
final class LuhnFunction extends XPathFunctionHandler {
  @override
  String get name => 'luhn';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    final text = args.single as String;
    if (!RegExp(r'^\d+$').hasMatch(text)) return false;
    var sum = 0;
    for (final (i, char) in text.split('').reversed.indexed) {
      final digit = int.parse(char) * (i.isOdd ? 2 : 1);
      sum += digit > 9 ? digit - 9 : digit;
    }
    return sum % 10 == 0;
  }
}
```

Arguments arrive converted to the prototype's types: `string` (a
`String`), `number` (a `double`), `boolean`, `date` (a `DateTime`) or
`any`. Return a `bool`, `double`, `String` or `DateTime`, never `null`.

## 2. Register it

Pass it in the configuration when parsing:

```dart
final definition = await FormDefinition.parse(
  cardForm,
  config: DartRosaConfig(functions: [LuhnFunction()]),
);
```

## 3. Use it in the form

In XLSForm, put `luhn(.)` in the `constraint` column (with a
`constraint_message`), or use it anywhere an expression goes, such as
`if(luhn(${number}), 'valid', 'invalid')` in a `calculation`. The answer
is then checked like any other constraint:

```dart
final session = definition.createSession();
final number = session.root.children.first as QuestionNode;
final wrong = session.answer(number.index, const StringValue('1234'));
// AnswerConstraintViolated('Check the card number')
final right = session.answer(
  number.index,
  const StringValue('79927398713'),
); // AnswerAccepted
```

## Things to know

* **Other apps don't have your function.** ODK Collect, Enketo, Web Forms
  and pyxform's validator reject a form that calls an unknown function.
  pyxform can only convert it with validation turned off, and the form
  works only in your app. Prefer built-in functions (`regex()` covers
  many format checks) when the form must also run elsewhere.
* Without the function registered, the form parses but
  `createSession()` fails with "cannot handle function 'luhn'".
* Built-in functions win over custom ones with the same name; the last
  registered custom handler for a name wins over earlier ones.
* `eval` runs on every recalculation that involves it: keep it fast and
  synchronous. For data lookups, use secondary instances or
  `pulldata()` instead ([CSV lists and entities](csv-and-entities.md)).

## Related

* [PLUGINS.md](../PLUGINS.md#xpath-functions-functions): raw arguments,
  fallback handlers and the other extension points
* [COMPATIBILITY.md](../COMPATIBILITY.md#functions): the built-in functions
