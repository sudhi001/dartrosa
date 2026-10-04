import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../markdown.dart';
import '../xform_scope.dart';
import 'common.dart';
import 'image_map.dart';

/// A choice's image (through the app's delegates) and label.
class ChoiceContent extends StatelessWidget {
  /// Creates the content of [choice] of [node].
  const ChoiceContent(
    this.node,
    this.choice, {
    this.showLabel = true,
    this.center = false,
    super.key,
  });

  /// The select question.
  final QuestionNode node;

  /// The choice.
  final SelectChoice choice;

  /// Whether to show the label (it remains the image's semantic label).
  final bool showLabel;

  /// Whether to center the content.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final label = node.choiceLabel(choice) ?? choice.value;
    final uri = node.choiceMedia(choice, 'image');
    final image = uri == null
        ? null
        : XFormScope.of(context).delegates.image(uri);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (image != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: Image(image: image, semanticLabel: label),
          ),
        if (showLabel)
          XFormMarkdown(
            label,
            textAlign: center ? TextAlign.center : TextAlign.start,
          ),
      ],
    );
  }
}

/// Lays out choice widgets for an appearance: one per line, `columns-N`,
/// `columns` (as many ~180dp columns as fit) or `columns-pack`.
class ChoiceLayout extends StatelessWidget {
  /// Creates a layout of [children] for [appearance].
  const ChoiceLayout({
    required this.appearance,
    required this.children,
    super.key,
  });

  /// The question's appearance.
  final Appearance appearance;

  /// The choice widgets.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (appearance.has('columns-pack')) {
      return Wrap(spacing: 8, runSpacing: 4, children: children);
    }
    final count = appearance.columnCount;
    if (count != null) return _grid(count);
    if (appearance.has('columns')) {
      return LayoutBuilder(
        builder: (context, constraints) => _grid(
          constraints.maxWidth.isFinite
              ? (constraints.maxWidth / 180).floor().clamp(1, 20)
              : 2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _grid(int columns) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i += columns)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + columns; j++)
              Expanded(
                child: j < children.length ? children[j] : const SizedBox(),
              ),
          ],
        ),
    ],
  );
}

/// A choice with a radio button or check box.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.node,
    required this.choice,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final QuestionNode node;
  final SelectChoice choice;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = !node.isReadonly;
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (multi)
                Checkbox(
                  value: selected,
                  onChanged: enabled ? (_) => onTap() : null,
                )
              else
                Radio<String>(
                  value: choice.value,
                  enabled: enabled,
                  toggleable: true,
                ),
              Flexible(child: ChoiceContent(node, choice)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A choice without a button (`no-buttons`): its image, or its label if
/// it has none, highlighted when selected.
class _ButtonlessTile extends StatelessWidget {
  const _ButtonlessTile({
    required this.node,
    required this.choice,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final QuestionNode node;
  final SelectChoice choice;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uri = node.choiceMedia(choice, 'image');
    final hasImage =
        uri != null && XFormScope.of(context).delegates.image(uri) != null;
    return Semantics(
      button: true,
      checked: multi ? selected : null,
      selected: selected,
      inMutuallyExclusiveGroup: !multi,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: node.isReadonly ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: ChoiceContent(
                    node,
                    choice,
                    showLabel: !hasImage,
                    center: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Likert scale: choices side by side, buttons above their labels.
class _Likert extends StatelessWidget {
  const _Likert({
    required this.node,
    required this.choices,
    required this.onTap,
  });

  final QuestionNode node;
  final List<SelectChoice> choices;
  final ValueChanged<SelectChoice> onTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final c in choices)
        Expanded(
          child: MergeSemantics(
            child: InkWell(
              onTap: node.isReadonly ? null : () => onTap(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Radio<String>(
                      value: c.value,
                      enabled: !node.isReadonly,
                      toggleable: true,
                    ),
                    ChoiceContent(node, c, center: true),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Shows [builder]'s choices filtered by a search field
/// (`autocomplete`).
class _Filtered extends StatefulWidget {
  const _Filtered({required this.node, required this.builder});

  final QuestionNode node;
  final Widget Function(List<SelectChoice> choices) builder;

  @override
  State<_Filtered> createState() => _FilteredState();
}

class _FilteredState extends State<_Filtered> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final query = _query.trim().toLowerCase();
    final choices = [
      for (final c in node.choices)
        if (query.isEmpty ||
            (node.choiceLabel(c) ?? c.value).toLowerCase().contains(query))
          c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          enabled: !node.isReadonly,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: MaterialLocalizations.of(context).searchFieldLabel,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        widget.builder(choices),
      ],
    );
  }
}

/// The choices of [node] side by side in equal cells (`label`,
/// `list-nolabel`, `list`, and the rows of a `table-list` group), after
/// an optional [leading] cell twice as wide.
class ChoiceRowInput extends StatelessWidget {
  /// Creates a row of [node]'s choices.
  const ChoiceRowInput(
    this.node, {
    required this.showLabels,
    required this.showButtons,
    this.leading,
    super.key,
  });

  /// The select question.
  final QuestionNode node;

  /// Whether to show the choice labels.
  final bool showLabels;

  /// Whether to show radio buttons or check boxes.
  final bool showButtons;

  /// A first cell, e.g. the question label.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final multi = node.controlType == ControlType.selectMulti;
    final selected = selectedValues(node);
    final enabled = showButtons && !node.isReadonly;
    void tap(SelectChoice c) => multi
        ? answerSelections(
            context,
            node,
            selected.contains(c.value)
                ? ({...selected}..remove(c.value))
                : {...selected, c.value},
          )
        : _selectOne(context, node, selected.contains(c.value) ? null : c);
    final row = Row(
      children: [
        if (leading != null) Expanded(flex: 2, child: leading!),
        for (final c in node.choices)
          Expanded(
            child: MergeSemantics(
              child: InkWell(
                onTap: enabled ? () => tap(c) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showButtons)
                      multi
                          ? Checkbox(
                              value: selected.contains(c.value),
                              onChanged: enabled ? (_) => tap(c) : null,
                            )
                          : Radio<String>(
                              value: c.value,
                              enabled: enabled,
                              toggleable: true,
                            ),
                    if (showLabels)
                      ChoiceContent(node, c, center: true)
                    else
                      Semantics(
                        label: node.choiceLabel(c) ?? c.value,
                        child: const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (multi || !showButtons) return row;
    return RadioGroup<String>(
      groupValue: selected.firstOrNull,
      onChanged: (value) => _selectOne(
        context,
        node,
        node.choices.where((c) => c.value == value).firstOrNull,
      ),
      child: row,
    );
  }
}

void _selectOne(BuildContext context, QuestionNode node, SelectChoice? c) {
  if (node.isReadonly) return;
  final result = answerQuestion(
    context,
    node,
    c == null ? null : SelectOneValue(Selection.ofChoice(c)),
  );
  if (c != null &&
      result is AnswerAccepted &&
      Appearance.parse(node.appearance).has('quick')) {
    XFormPagerScope.advanceOf(context)?.call();
  }
}

/// Select one: radio buttons, or the widget for its appearance
/// (`minimal`, `quick`, `autocomplete`, `columns*`, `no-buttons`,
/// `likert`, `list`).
class SelectOneInput extends StatelessWidget {
  /// Creates the input for [node].
  const SelectOneInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final appearance = Appearance.parse(node.appearance);
    if (appearance.has('image-map')) return ImageMapInput(node);
    if (appearance.has('autocomplete')) {
      return _Filtered(
        node: node,
        builder: (choices) => _body(context, appearance, choices),
      );
    }
    if (appearance.has('minimal')) return _dropdown(context);
    if (appearance.has('list')) {
      return ChoiceRowInput(node, showLabels: true, showButtons: true);
    }
    return _body(context, appearance, node.choices);
  }

  Widget _dropdown(BuildContext context) {
    final selected = selectedValues(node).firstOrNull;
    final choices = node.choices;
    return DropdownButtonFormField<String>(
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      items: [
        for (final c in choices)
          DropdownMenuItem(value: c.value, child: ChoiceContent(node, c)),
      ],
      onChanged: node.isReadonly
          ? null
          : (value) => _selectOne(
              context,
              node,
              choices.where((c) => c.value == value).firstOrNull,
            ),
    );
  }

  Widget _body(
    BuildContext context,
    Appearance appearance,
    List<SelectChoice> choices,
  ) {
    final selected = selectedValues(node).firstOrNull;
    void tap(SelectChoice c) =>
        _selectOne(context, node, c.value == selected ? null : c);
    final Widget body;
    if (appearance.has('likert')) {
      body = _Likert(node: node, choices: choices, onTap: tap);
    } else {
      final noButtons = appearance.has('no-buttons');
      body = ChoiceLayout(
        appearance: appearance,
        children: [
          for (final c in choices)
            noButtons
                ? _ButtonlessTile(
                    node: node,
                    choice: c,
                    selected: c.value == selected,
                    multi: false,
                    onTap: () => tap(c),
                  )
                : _ChoiceTile(
                    node: node,
                    choice: c,
                    selected: c.value == selected,
                    multi: false,
                    onTap: () => tap(c),
                  ),
        ],
      );
    }
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) => _selectOne(
        context,
        node,
        node.choices.where((c) => c.value == value).firstOrNull,
      ),
      child: body,
    );
  }
}

/// Select multiple: check boxes, or the widget for its appearance
/// (`minimal`, `autocomplete`, `columns*`, `no-buttons`, `list`).
class SelectMultiInput extends StatelessWidget {
  /// Creates the input for [node].
  const SelectMultiInput(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final appearance = Appearance.parse(node.appearance);
    if (appearance.has('image-map')) return ImageMapInput(node);
    if (appearance.has('minimal')) return _minimal(context, appearance);
    if (appearance.has('autocomplete')) {
      return _Filtered(
        node: node,
        builder: (choices) => _body(context, appearance, choices),
      );
    }
    if (appearance.has('list')) {
      return ChoiceRowInput(node, showLabels: true, showButtons: true);
    }
    return _body(context, appearance, node.choices);
  }

  Widget _body(
    BuildContext context,
    Appearance appearance,
    List<SelectChoice> choices,
  ) {
    final selected = selectedValues(node);
    final noButtons = appearance.has('no-buttons');
    void tap(SelectChoice c) => answerSelections(
      context,
      node,
      selected.contains(c.value)
          ? ({...selected}..remove(c.value))
          : {...selected, c.value},
    );
    return ChoiceLayout(
      appearance: appearance,
      children: [
        for (final c in choices)
          noButtons
              ? _ButtonlessTile(
                  node: node,
                  choice: c,
                  selected: selected.contains(c.value),
                  multi: true,
                  onTap: () => tap(c),
                )
              : _ChoiceTile(
                  node: node,
                  choice: c,
                  selected: selected.contains(c.value),
                  multi: true,
                  onTap: () => tap(c),
                ),
      ],
    );
  }

  /// A field listing the selected labels that opens a dialog of check
  /// boxes.
  Widget _minimal(BuildContext context, Appearance appearance) {
    final scope = XFormScope.of(context);
    final selected = selectedValues(node);
    final text = [
      for (final c in node.choices)
        if (selected.contains(c.value)) node.choiceLabel(c) ?? c.value,
    ].join(', ');
    return InkWell(
      onTap: node.isReadonly
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (dialogContext) => XFormScope(
                controller: scope.controller,
                delegates: scope.delegates,
                overrides: scope.overrides,
                child: AlertDialog(
                  content: SingleChildScrollView(
                    child: ListenableBuilder(
                      listenable: scope.controller.listenableFor(node.ref),
                      builder: (context, _) =>
                          _body(context, Appearance.parse(null), node.choices),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        MaterialLocalizations.of(dialogContext).okButtonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        isEmpty: text.isEmpty,
        child: Text(text),
      ),
    );
  }
}
