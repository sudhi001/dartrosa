# Replace a question widget

**Type:** recipe. **Package:** `dartrosa_flutter`.

`XFormView` draws every ODK question type, but your app may want its own
look for some of them: a star rating, a slider in your brand style, a
lookup against your own database. You can replace the widget of any
question by its control type and appearance, and still get validation,
required markers and error messages.

This recipe draws `select_one` questions with the appearance `likert` as
stars, using the following steps:

1. Write the widget.
2. Answer through the form's controller.
3. Register it in `widgetOverrides`.

## 1. Write the widget

The builder receives the `QuestionNode`: its label, choices, current
value, and whether it is required or read-only. `XFormLabel` draws the
label the way the other questions do (with its image and the required
marker).

## 2. Answer through the controller

Answer with `XFormScope.of(context).controller.answer(...)`, not with
`session.answer`: the controller remembers a refused answer, so
`errorFor` returns its message ("Sorry, this response is required!", or
the form's constraint message), and the outline and the pager's checks
see it.

```dart
// Stars for a select_one with the appearance "likert": one per choice.
class StarRating extends StatelessWidget {
  const StarRating({required this.node, super.key});

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final selected = switch (node.value) {
      SelectOneValue(:final selection) => node.choices.indexWhere(
        (choice) => choice.value == selection.value,
      ),
      _ => -1,
    };
    // Set when the last answer (or finalize) was refused.
    final error = controller.errorFor(
      node.index,
      XFormLocalizations.of(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XFormLabel(node.label, required: node.isRequired),
        Row(
          children: [
            for (final (i, choice) in node.choices.indexed)
              IconButton(
                tooltip: node.choiceLabel(choice),
                icon: Icon(i <= selected ? Icons.star : Icons.star_border),
                onPressed: node.isReadonly
                    ? null
                    : () => controller.answer(
                        node.index,
                        SelectOneValue(Selection(choice.value)),
                      ),
              ),
          ],
        ),
        if (error != null)
          Text(
            error,
            style: TextStyle(
              color: XFormTheme.of(context).errorColorOf(context),
            ),
          ),
      ],
    );
  }
}
```

The widget is rebuilt whenever the question's value or state changes
(another answer making it read-only, a language change), so it can read
everything from `node` in `build`.

## 3. Register it

```dart
// Keep the map in a constant or a field: a new map on every build makes
// every question widget rebuild.
final overrides = <String, QuestionWidgetBuilder>{
  'selectOne:likert': (context, node) => StarRating(node: node as QuestionNode),
};
```

Then pass `widgetOverrides: overrides` to `XFormView`.

## How the key is matched

The key is the name of a `ControlType` (`input`, `selectOne`,
`selectMulti`, `range`, `rank`, `trigger`, `imageChoose`, ...), optionally followed by `:` and an
appearance. For a question, `XFormView` tries, in order:

1. the control type with the whole appearance (`selectOne:likert quick`);
2. the control type with each appearance word (`selectOne:likert`);
3. the control type alone (`selectOne`), which replaces every question of
   that type.

In XLSForm the appearance is the `appearance` column, so form designers
choose which questions get your widget.

## Related

* [Widget catalog](../widgets/README.md): what the built-in widgets look
  like, to decide what to replace.
* [Theme the form](theme-the-form.md), when you only want other colors
  or spacing.
* `XFormController` and `QuestionWidgetBuilder` in the
  [API reference](https://pub.dev/documentation/dartrosa_flutter/latest/).
