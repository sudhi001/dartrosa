## 0.2.0

- Adaptive layout by window size class (new `XFormWindowSize`): full width on phones; from 600dp a centered column, now capped by default at `XFormTheme.defaultMaxContentWidth` (720dp) when `maxContentWidth` is `null` (`double.infinity` fills the width).
- Form outline (groups, questions, answered / required / error state, current screen) to jump to any question: a side panel from 840dp, a bottom sheet elsewhere. New `XFormView.outline` (`XFormOutlineMode.adaptive`, `onRequest`, `none`), public `XFormViewState` with `showOutline()`, `hideOutline()`, `jumpTo(FormIndex)` and `isOutlinePanelVisible`; `XFormTheme.outlinePanelWidth`.
- Pager bottom bar: progress bar and position ("3 of 12", opening the outline), Back disabled on the first screen, Next with a trailing chevron, 48dp buttons on phones, icon buttons when labels don't fit; the end page sums up the answers.
- Keyboard: Page Down / Page Up and Alt+arrows move between pager screens, Enter in a one-line field moves to the next field or screen, Tab follows form order also for controls built later (image maps, lazy lists); image-map areas are focusable and selected with Enter / Space; rank questions get move up / down buttons.
- Errors: blocked Next and failed Finalize scroll to and focus the first question in error (a failed Finalize shows its whole `field-list` screen); text fields in error get a red outline; messages have an error icon.
- Desktop and web: visible scroll bars, selectable text (`SelectionArea`), time picker in input mode.
- Material 3 look: filled group cards (no shadow) unless the app's `CardTheme` or `XFormTheme` says otherwise, nested groups as sections, hints in `bodyMedium` / `onSurfaceVariant`, `table-list` row dividers, short choices in columns on wide forms (`XFormTheme.adaptiveChoiceColumns`).
- Removing a repeat instance asks for confirmation.
- Non-Gregorian date dialog: the month gets its own line on narrow screens with large text, and the content scrolls.
- `XFormController.formChanges`: notified on every change, for form-wide summaries.
- Allows `xml` 7.x (was 6.x only).

## 0.1.0

- Initial release: Flutter renderer for DartRosa.
- `XFormView` in pager (Collect-like) and scroll modes, widgets for every ODK control type and the Collect appearances listed in the README.
- Platform features through `XFormDelegates`; `widgetOverrides`, `XFormTheme`, `XFormLocalizations`, accessibility and RTL support.
- Image-map areas are selectable by screen readers (`SvgImageMap.areaBounds`); the `minimal` dropdown is named after its question.
- Answer rows move their buttons below the answer when the row doesn't fit (narrow screens, large text); pager pages scroll.
- Error text uses `XFormTheme.errorColor` everywhere.
- Non-Gregorian date dialog: day and year spinners sized to their values, so the year isn't cut off on phones.
- `XFormTheme.maxContentWidth` (default `null`, full width): caps the form's content and centers it on wide screens, in pager and scroll modes.
- Answering a question rebuilds only that question and the nodes whose relevance, read-only or required state it changes (previously every visible question rebuilt on any relevance or constraint check); scroll mode keeps the other questions when one is shown or hidden.
- Image maps reuse the highlighted SVG while the selection is unchanged.
- Tests run with Flutter's leak tracker; the example app disposes its workspace.
