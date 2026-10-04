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

Status: first renderer increment (Phase 7). Supported: text, integer,
decimal and long inputs (`multiline`, `numbers`), secret, select one
(radio, `minimal` dropdown), select multiple, rank, trigger, range, date /
time / dateTime pickers, geopoint, barcode and media through delegates,
notes, groups, repeats. See `docs/PORTING_PLAN.md` §12 for the full
appearance catalogue still to come.

Run the example: `cd example && flutter create . && flutter run`.
