# Choose pager, scroll or outline

**Type:** recipe. **Package:** `dartrosa_flutter`.

`XFormView` has two layouts and an outline:

| | Pager (`XFormMode.pager`, the default) | Scroll (`XFormMode.scroll`) |
|---|---|---|
| Shows | One question, or one `field-list` group, per screen | Every relevant question on one page |
| Moving on | **Next** checks the screen first; repeats ask "Add another?" | Free scrolling; repeats have Add and Remove buttons |
| Like | ODK Collect | Enketo and ODK Web Forms |
| Best for | Phones, long forms, people new to smartphones, forms designed for Collect | Short forms, tablets and desktops, data entry from paper |

The **outline** lists every group and question with its state
(answered, required, in error) and jumps to any of them, like Collect's
"jump to" screen. By default (`XFormOutlineMode.adaptive`) it is a side
panel on windows 840dp and wider and a bottom sheet, opened from the
pager's position button ("3 of 12"), elsewhere.

This recipe picks the layout by window size and opens the outline from
an app bar button, using the following steps:

1. Choose the mode from the window size class.
2. Keep a key on the view and open the outline from a button.

## 1. Choose the mode

`XFormWindowSize` gives the Material 3 window size class: `compact`
(under 600dp), `medium`, `expanded` (840dp and wider), `large` and
`extraLarge`.

```dart
// One question per screen on phones; the whole form on one page where
// there is room.
XFormMode modeFor(BuildContext context) =>
    XFormWindowSize.of(context) >= XFormWindowSize.expanded
    ? XFormMode.scroll
    : XFormMode.pager;
```

## 2. Open the outline from a button

`XFormViewState.showOutline()` opens the outline sheet, and
`jumpTo(index)` shows a given question. Reach them with a `GlobalKey`:

```dart
class OutlinedFormPage extends StatefulWidget {
  const OutlinedFormPage({required this.session, super.key});

  final FormSession session;

  @override
  State<OutlinedFormPage> createState() => _OutlinedFormPageState();
}

class _OutlinedFormPageState extends State<OutlinedFormPage> {
  final _form = GlobalKey<XFormViewState>();
  late final XFormMode _mode = modeFor(context);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.session.definition.title ?? ''),
      actions: [
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'Outline',
          // Every group and question, with its state; tap one to go there.
          onPressed: () => _form.currentState?.showOutline(),
        ),
      ],
    ),
    body: XFormView(
      key: _form,
      session: widget.session,
      mode: _mode, // chosen once, so the person keeps their place
      outline: XFormOutlineMode.onRequest, // no side panel
    ),
  );
}
```

The mode is chosen once, when the page opens: rotating a tablet or
resizing a window then doesn't move the person to another layout in the
middle of a question. `XFormOutlineMode.none` turns the outline off, as
Collect does when "jump to" is disabled.

## How it works

`XFormView` measures the width it is given (not the device), so it also
adapts inside a split view or a dialog. From 600dp it centers the
questions in a column at most `XFormTheme.maxContentWidth` wide (720dp by
default). With a keyboard, Page Down and Page Up (or Alt+→ and Alt+←)
move between pager screens, and Enter moves to the next field.

## Related

* [Show a form in Flutter: on tablets and desktops](../guides/render-a-form-in-flutter.md#on-tablets-and-desktops),
  with screenshots
* [Theme the form](theme-the-form.md), for `maxContentWidth` and the
  outline panel's width
* [Widget catalog](../widgets/README.md)
