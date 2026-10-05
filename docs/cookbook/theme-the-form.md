# Theme the form

**Type:** recipe. **Package:** `dartrosa_flutter`.

`XFormView` uses your app's Material theme: its colors, text styles,
buttons and input decoration. On top of that, an `XFormTheme` theme
extension controls what is specific to forms: page padding, the space
between questions, group cards, the error color and how wide the form
gets on tablets and desktops.

This recipe gives a form your brand color in light and dark mode and a
narrower column, using the following steps:

1. Describe the form's look in an `XFormTheme`.
2. Add it to both the light and the dark `ThemeData`.
3. Optionally, change it for one form only.

## 1. Describe the form's look

```dart
// The form's spacing, cards and width; colors and text come from
// ThemeData.
const formTheme = XFormTheme(
  pagePadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  questionSpacing: 16,
  cardElevation: 0,
  maxContentWidth: 640, // double.infinity: use the whole width
);
```

| Field | Default | What it changes |
|---|---|---|
| `pagePadding` | 16 on every side | Space around each pager screen or the scrolling page |
| `questionSpacing` | 12 | Space above and below each question |
| `errorColor` | the color scheme's `error` | Validation messages |
| `cardColor`, `cardElevation` | from `CardTheme`, else `surfaceContainerLow` and 0 | The cards around groups and repeat instances |
| `cardShape`, `cardMargin`, `cardPadding` | the card default, 8 above and below, 16 inside | The same cards |
| `maxContentWidth` | 720 | The widest the questions get; wider windows center them |
| `adaptiveChoiceColumns` | `true` | Short choice lists in columns on wide screens |
| `outlinePanelWidth` | 320 | The outline side panel on windows 840dp and wider |

## 2. Use it in light and dark mode

Seed both themes with your brand color so Material 3 derives matching
light and dark palettes, and give both the same `XFormTheme`:

```dart
Widget brandedApp(Widget home) => MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: const Color(0xFF00695C), // your brand color
    extensions: const [formTheme],
  ),
  darkTheme: ThemeData(
    colorSchemeSeed: const Color(0xFF00695C),
    brightness: Brightness.dark,
    extensions: const [formTheme],
  ),
  themeMode: ThemeMode.system, // follow the device
  home: home,
);
```

Without an `XFormTheme` in the theme, the defaults in the table apply.

## 3. Change it for one form

Wrap that form's `XFormView` in a `Theme`:

```dart
// A different look for one form only.
Theme(
  data: Theme.of(context).copyWith(
    extensions: [
      XFormTheme.of(
        context,
      ).copyWith(errorColor: Colors.deepOrange),
    ],
  ),
  child: XFormView(session: session),
);
```

## How it works

`XFormTheme` is a `ThemeExtension`, so it animates with theme changes and
can differ per subtree like any Flutter theme. The renderer reads
`XFormTheme.of(context)` and falls back to the defaults when there is
none. Everything else (fonts, button shapes, text field borders) comes
from your `ThemeData`, so a theme you already have applies to forms too.

`maxContentWidth` matters on tablets, desktops and the web: lines of
text stay readable and controls stay close together. Phones (narrower
than 600dp) always use the full width.

## Related

* [Choose pager, scroll or outline](choose-a-layout.md)
* [Replace a question widget](replace-a-question-widget.md), for changes
  a theme can't make
* [Widget catalog](../widgets/README.md), with light and dark screenshots
