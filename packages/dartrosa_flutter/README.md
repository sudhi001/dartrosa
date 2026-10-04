# dartrosa_flutter

Flutter renderer for [DartRosa](../dartrosa), the pure-Dart ODK XForms
engine.

```dart
final definition = await FormDefinition.parse(xformXml);
final session = definition.createSession();

XFormView(
  session: session,
  mode: XFormMode.pager, // or XFormMode.scroll
  delegates: MyDelegates(), // camera, location, barcode, media in labels
  onFinalized: (submission) => upload(submission.xml),
);
```

- **Pager** mode shows one question (or `field-list` group) per screen,
  validates the screen before moving on, asks before adding repeat
  instances and ends with a finalize screen, like ODK Collect.
- **Scroll** mode shows every relevant question on one page with
  add/remove buttons for repeats.
- Widgets rebuild per question: each question listens only to its own
  node's changes (answers, recalculations, relevance).
- Platform features go through `XFormDelegates`; without one, capture
  questions fall back to typing the value. Any question widget can be
  replaced with `widgetOverrides` (keyed by control type and optionally
  appearance, e.g. `selectOne:likert`).

## Supported

| Control | Appearances |
|---|---|
| text | `multiline`, `numbers`, `masked` (also `secret`) |
| integer / decimal / long | `thousands-sep` (display only; the answer has no separators) |
| date | `no-calendar` (typed date), `month-year`, `year` (saved as the 1st) |
| time / dateTime | pickers |
| select one | radio list, `minimal` (drop-down), `quick` (auto-advance in pager mode), `autocomplete`, `columns`, `columns-N`, `columns-pack`, `no-buttons`, `likert`, `label`, `list-nolabel`, `list`; Collect's old names `compact`, `quickcompact`, `compact-N`, `horizontal`, `horizontal-compact`; `image-map`; `map` (through `XFormDelegates.selectFromMap`) |
| select multiple | check boxes, `minimal` (dialog), `autocomplete`, `columns*`, `no-buttons`, `label`, `list-nolabel`, `list`, `image-map` |
| rank, trigger, note | reorderable list, acknowledge, read-only text |
| range | slider, `vertical`, `picker`, `rating`, `no-ticks` |
| geopoint, barcode, image / audio / video / file | through `XFormDelegates` (typed value otherwise) |
| geopoint `maps` / `placement-map`, geotrace, geoshape | on the app's map through `XFormDelegates.geoFromMap` when `canShowMaps` (default widget otherwise); `hidden-answer` |
| group | card, `field-list` (one pager screen), `table-list` (one grid: choice labels as header, a row of buttons per select) |
| repeat | add / remove, "add another?" prompt in pager mode, `noAddRemove` |

Choice images use `delegates.image(uri)`. `image-map` selects show the
SVG of the question's image (read with `delegates.mediaBytes(uri)`): the
`g`, `path`, `rect`, `circle`, `ellipse` and `polygon` elements whose ids
are choice values are tapped to select them and filled when selected. Unsupported appearances fall
back to the default widget (with one `debugPrint` per appearance).

- **Labels, hints and choices** render ODK's markdown subset: `*em*`,
  `**strong**`, `#` headers, `[links](url)` (opened through
  `XFormDelegates.openLink`), `<span style="color: ...; font-family:
  ...">`. Guidance hints are shown per `XFormView.guidanceHints` (`yes`,
  `collapsed`, `no`).
- **Theme**: add an `XFormTheme` to `ThemeData.extensions` (page padding,
  question spacing, error color, card style).
- **Strings**: buttons, prompts and default messages come from
  `XFormLocalizations` (English); subclass it and register a
  `LocalizationsDelegate` for other languages.
- **Accessibility**: each question is a semantics node labelled with its
  label, "required" and its validation state; errors are live regions,
  and blocked Next / Finalize announce the error; focus follows form
  order; choice and button targets are at least 48dp.
- **RTL**: forms in ar, fa, he, ur, ps, sd, ug, yi or dv (by code or
  name, e.g. `Arabic (ar)`) are laid out right to left.

Golden tests (`test/golden_test.dart`, light/dark, LTR/RTL) use the
default test font; refresh them with `flutter test --update-goldens`.

Run the example: `cd example && flutter create . && flutter run`.
