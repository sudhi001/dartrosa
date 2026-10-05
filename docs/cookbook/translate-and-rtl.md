# Translate the form and support right-to-left

**Type:** recipe. **Package:** `dartrosa_flutter`.

Two things get translated in a form app, from two places:

* **The form's text** (questions, hints, choices, constraint messages)
  comes from the form's own translations: the `label::French (fr)`
  columns of the XLSForm. The person picks one of the form's languages.
* **Your app's text and the renderer's buttons** ("Next", "Finalize",
  "Sorry, this response is required!") come from Flutter localization:
  `XFormLocalizations`, in English by default.

This recipe lets the person switch the form's language, starts in the
device's language when the form has it, and lays out right-to-left
languages correctly, using the following steps:

1. Add a language menu.
2. Start in the device's language.
3. Let right-to-left languages lay themselves out.
4. Translate the renderer's buttons.

## 1. Add a language menu

`session.definition.languages` lists the form's languages, and setting
`session.language` switches every label at once. `XFormView` listens to
the session, so it redraws by itself:

```dart
// A menu of the form's own languages (its translations).
class FormLanguageMenu extends StatelessWidget {
  const FormLanguageMenu({required this.session, super.key});

  final FormSession session;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.translate),
    tooltip: 'Form language',
    // XFormView rebuilds in the new language and direction.
    onSelected: (language) => session.language = language,
    itemBuilder: (context) => [
      for (final language in session.definition.languages)
        CheckedPopupMenuItem(
          value: language,
          checked: language == session.language,
          child: Text(language),
        ),
    ],
  );
}
```

Put it in the `AppBar`'s `actions`, next to the form's title. Drafts
hold answers, not the language, so remember the person's choice in your
app's settings and pass it to `createSession(language: ...)`.

## 2. Start in the device's language

Language names in forms are whatever the designer wrote; pyxform's
convention is a name followed by a code, such as `French (fr)`. Match the
code against the device locale:

```dart
/// The form language matching [locale], if the form has one. pyxform
/// names languages like `French (fr)`.
String? formLanguageFor(Locale locale, List<String> languages) {
  for (final language in languages) {
    final code = RegExp(r'\(([\w-]+)\)').firstMatch(language)?[1];
    if (code?.split('-').first == locale.languageCode) return language;
  }
  return null;
}
```

Then start the session in it:
`definition.createSession(language: formLanguageFor(Localizations.localeOf(context), definition.languages))`.
With `null`, the form's default language is used.

## 3. Right-to-left

There is nothing to do. When the form's current language is written right
to left (Arabic, Persian, Hebrew, Urdu, Pashto and others, recognized by
code or by name), `XFormView` lays the whole form out right to left:
text, choice lists, the pager's buttons (Alt+→ and Alt+← swap too) and
the outline. `textDirectionOfLanguage('Arabic (ar)')` returns
`TextDirection.rtl` if you need the same decision for your own widgets
around the form.

## 4. Translate the renderer's buttons

Subclass `XFormLocalizations`, override the strings you need, and
register a `LocalizationsDelegate` with your app's other delegates. The
full example is in
[Show a form in Flutter, step 5](../guides/render-a-form-in-flutter.md#5-match-your-apps-look-and-language).

## How it works

`session.language` changes the language of the engine's localizer; the
session emits a `language` change, and `XFormController` notifies every
question widget. Constraint messages and choice labels in the form's
translations follow, as do `jr:itext` media (a different picture or
recording per language).

## Related

* [Concepts: languages](../CONCEPTS.md#languages)
* [Non-Gregorian calendars](../guides/non-gregorian-calendars.md), for
  dates in local calendars
* [ODK form language docs](https://docs.getodk.org/form-language/)
