# Cookbook

**Audience:** developers who know the basics and want to do one thing.
**Type:** how-to recipes.

Each recipe solves one task in a few steps, in the style of the
[Flutter cookbook](https://docs.flutter.dev/cookbook): what you will do,
numbered steps with code, and how it works. The code of every recipe is
compiled and run by the tests in `packages/*/test/docs/cookbook_test.dart`
(and `testing_recipe_test.dart`).

New to DartRosa? Start with the [quick start](../QUICKSTART.md) and the
[concepts](../CONCEPTS.md).

## Flutter renderer

| Recipe | You will |
|---|---|
| [Replace a question widget](replace-a-question-widget.md) | Draw a select as stars, keeping validation |
| [Theme the form](theme-the-form.md) | Use brand colors, light and dark mode, spacing and a maximum width |
| [Translate the form and support right-to-left](translate-and-rtl.md) | Switch the form's language, start in the device's language, lay out Arabic right to left |
| [Connect the camera, location and barcode scanner](device-features.md) | Plug your app's plugins into capture questions |
| [Choose pager, scroll or outline](choose-a-layout.md) | Pick a layout per screen size and open the outline from a button |

For every question type and appearance with screenshots, see the
[widget catalog](../widgets/README.md).

## Engine (pure Dart)

| Recipe | You will |
|---|---|
| [Add a custom XPath function](add-an-xpath-function.md) | Call your own Dart function from constraints and calculations |
| [Use CSV lists and entities offline](csv-and-entities.md) | Register households, then offer them as choices in a follow-up form |
| [Validate submissions on the server](validate-on-the-server.md) | Check received submissions against their form, with the same rules as the app |
| [Test your forms](test-your-forms.md) | Write unit tests for a form's rules, with the session API or JavaRosa's `Scenario` |

## Missing a recipe?

Open an issue on [GitHub](https://github.com/sudhi001/dartrosa/issues)
saying what you were trying to do. The longer guides cover more ground:
[Show a form in Flutter](../guides/render-a-form-in-flutter.md),
[Save and resume drafts](../guides/save-and-resume-drafts.md),
[Encrypt and submit](../guides/encrypt-and-submit.md),
[CSV data and entities](../guides/external-data-and-entities.md),
[Non-Gregorian calendars](../guides/non-gregorian-calendars.md) and
[Plugins](../PLUGINS.md).
