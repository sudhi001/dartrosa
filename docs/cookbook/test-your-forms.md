# Test your forms

**Type:** recipe. **Package:** `dartrosa` (`package:dartrosa/testing.dart`).

A form is a program: its constraints, skip logic and calculations can be
wrong, and a change to one question can break another. Because the
engine is pure Dart, you can unit-test a form with `package:test`, in
milliseconds, on any machine, before it reaches the field.

This recipe shows two ways, using the following steps:

1. Test with the session API (the way your app uses the form).
2. Or test with `Scenario`, JavaRosa's test driver, by XPath.

## 1. With the session API

Load the real form file in `setUp` and answer it as the app would:

```dart
test('members must be between 1 and 29', () {
  final members = questions[1];
  expect(
    session.answer(members.index, const IntegerValue(40)),
    isA<AnswerConstraintViolated>().having(
      (r) => r.message,
      'message',
      'Between 1 and 29',
    ),
  );
  expect(
    session.answer(members.index, const IntegerValue(4)),
    isA<AnswerAccepted>(),
  );
});

test('the water source is asked only when there is water', () {
  final [_, _, water, source] = questions;
  session.answer(water.index, const SelectOneValue(Selection('no')));
  expect(source.isRelevant, isFalse);
  session.answer(water.index, const SelectOneValue(Selection('yes')));
  expect(source.isRelevant, isTrue);
});
```

And check the submission a complete filling produces:

```dart
test('a complete visit finalizes', () {
  final [name, members, water, _] = questions;
  session
    ..answer(name.index, const StringValue('Amina'))
    ..answer(members.index, const IntegerValue(4))
    ..answer(water.index, const SelectOneValue(Selection('no')));
  final result = session.finalize();
  expect(result, isA<FinalizeSuccess>());
  final xml = (result as FinalizeSuccess).submission.xml;
  expect(xml, contains('<members>4</members>'));
  expect(xml, isNot(contains('water_source')));
});
```

## 2. With `Scenario`

`package:dartrosa/testing.dart` is a port of JavaRosa's test support:
`Scenario` answers and reads questions by XPath, and a small DSL builds
forms in code (handy for testing a rule in isolation, or a custom
function). Its `AnswerResult` is JavaRosa's status enum, so hide the
session API's class of the same name:

```dart
import 'package:dartrosa/dartrosa.dart' hide AnswerResult;
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

XFormsElement waterForm() => html(
  head([
    title('Water'),
    model([
      mainInstance([
        t('data id="water"', [t('has_water'), t('source'), t('members')]),
      ]),
      bind('/data/source')..relevant("/data/has_water = 'yes'"),
      bind('/data/members')
        ..type('int')
        ..constraint('. > 0 and . < 30'),
    ]),
  ]),
  body([
    input('/data/has_water'),
    input('/data/source'),
    input('/data/members'),
  ]),
);
```

```dart
test('the constraint on members', () async {
  final scenario = await Scenario.init(waterForm());

  expect(
    scenario.answer('/data/members', 40),
    AnswerResult.constraintViolated,
  );
  expect(scenario.answer('/data/members', 4), AnswerResult.ok);
  expect(scenario.answerOf('/data/members'), const IntegerValue(4));
});

test('the source is skipped without water', () async {
  final scenario = await Scenario.init(waterForm());
  scenario.answer('/data/has_water', 'no');

  scenario.jumpToBeginningOfForm();
  scenario.next(); // has_water
  scenario.next(); // source is not relevant: members comes next
  expect(scenario.refAtIndex, getRef('/data/members[1]'));
});
```

`Scenario.fromXml(xml)` loads a form file instead of the DSL.

## Tips

* Keep each form's XML (from pyxform or ODK Central) in your test
  folder and convert it again when the XLSForm changes, so tests run
  against what the field gets.
* Dates and times use the machine's time zone, as on the phone. Run
  date-sensitive tests with a fixed `TZ` (`TZ=UTC dart test`) and fix
  "now" with `withClock` from `package:clock`.
* For the Flutter screens, write widget tests with `XFormView` and fake
  delegates; the [tutorial](../tutorials/build-a-data-collection-app.md#10-test-it)
  shows one.

## Related

* [Validate submissions on the server](validate-on-the-server.md)
* [Migrating from JavaRosa: test support](../MIGRATING_FROM_JAVAROSA.md#test-support)
