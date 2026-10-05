## 0.0.1

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
