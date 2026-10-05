// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../markdown.dart';
import '../theme.dart';
import '../xform_scope.dart';
import 'common.dart';
import 'image_map.dart';
import 'map_inputs.dart';

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
    final uri = choiceImage(node, choice);
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
    this.adaptive = false,
    super.key,
  });

  /// The question's appearance.
  final Appearance appearance;

  /// The choice widgets.
  final List<Widget> children;

  /// Whether choices without a column appearance go in columns when the
  /// layout is at least [adaptiveMinWidth] wide: as many columns of
  /// [adaptiveColumnWidth] (times the text scale) as fit, at most four.
  /// For short text choices, which would otherwise leave most of a wide
  /// line empty.
  final bool adaptive;

  /// The narrowest layout that gets [adaptive] columns.
  static const adaptiveMinWidth = 560.0;

  /// The width of an [adaptive] column, at text scale 1.
  static const adaptiveColumnWidth = 240.0;

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
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!adaptive) return column;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width < adaptiveMinWidth) return column;
        final columns = (width / (adaptiveColumnWidth * textScale))
            .floor()
            .clamp(1, 4);
        return columns < 2 ? column : _grid(columns);
      },
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
        // The radio button or check box takes keyboard focus.
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(8),
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
    final uri = choiceImage(node, choice);
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
              canRequestFocus: false,
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

/// The choices of a select laid out for [appearance]: tiles with radio
/// buttons or check boxes, or without them (`no-buttons`).
class _ChoiceTiles extends StatelessWidget {
  const _ChoiceTiles({
    required this.node,
    required this.appearance,
    required this.choices,
    required this.selected,
    required this.onTap,
    this.adaptiveColumns = true,
  });

  /// Whether short choices may go in columns on wide layouts (not in a
  /// dialog, which sizes itself to its content).
  final bool adaptiveColumns;

  final QuestionNode node;
  final Appearance appearance;
  final List<SelectChoice> choices;
  final Set<String> selected;
  final ValueChanged<SelectChoice> onTap;

  @override
  Widget build(BuildContext context) {
    final multi = node.controlType == ControlType.selectMulti;
    final noButtons = appearance.has('no-buttons');
    return ChoiceLayout(
      appearance: appearance,
      adaptive:
          adaptiveColumns &&
          XFormTheme.of(context).adaptiveChoiceColumns &&
          _shortChoices(context, node, choices),
      children: [
        for (final c in choices)
          noButtons
              ? _ButtonlessTile(
                  node: node,
                  choice: c,
                  selected: selected.contains(c.value),
                  multi: multi,
                  onTap: () => onTap(c),
                )
              : _ChoiceTile(
                  node: node,
                  choice: c,
                  selected: selected.contains(c.value),
                  multi: multi,
                  onTap: () => onTap(c),
                ),
      ],
    );
  }
}

/// Whether [choices] of [node] suit columns: four or more, text only,
/// none longer than 24 characters.
bool _shortChoices(
  BuildContext context,
  QuestionNode node,
  List<SelectChoice> choices,
) {
  if (choices.length < 4) return false;
  final delegates = XFormScope.of(context).delegates;
  for (final c in choices) {
    final uri = choiceImage(node, c);
    if (uri != null && delegates.image(uri) != null) return false;
    final label = odkMarkdownToPlainText(node.choiceLabel(c) ?? c.value);
    if (label.length > 24) return false;
  }
  return true;
}

/// Shows [builder]'s choices among [choices] filtered by a search field
/// (`autocomplete`).
class _Filtered extends StatefulWidget {
  const _Filtered({
    required this.node,
    required this.choices,
    required this.builder,
  });

  final QuestionNode node;
  final List<SelectChoice> choices;
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
      for (final c in widget.choices)
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
    final choices = choicesOf(context, node);
    final selected = selectedValues(node);
    final enabled = showButtons && !node.isReadonly;
    void tap(SelectChoice c) => multi
        ? toggleSelection(context, node, c.value)
        : selectChoice(context, node, selected.contains(c.value) ? null : c);
    final row = Row(
      children: [
        if (leading case final leading?) Expanded(flex: 2, child: leading),
        for (final c in choices)
          Expanded(
            child: MergeSemantics(
              child: InkWell(
                onTap: enabled ? () => tap(c) : null,
                canRequestFocus: !showButtons,
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
    return _SelectOneGroup(
      node: node,
      choices: choices,
      selected: selected.firstOrNull,
      child: row,
    );
  }
}

/// The [RadioGroup] of a select one's radio buttons in [child].
class _SelectOneGroup extends StatelessWidget {
  const _SelectOneGroup({
    required this.node,
    required this.choices,
    required this.selected,
    required this.child,
  });

  final QuestionNode node;
  final List<SelectChoice> choices;
  final String? selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: selected,
    onChanged: (value) => selectChoice(
      context,
      node,
      choices.where((c) => c.value == value).firstOrNull,
    ),
    child: child,
  );
}

/// [child] after [warning] (the choices failed to load), if any.
class _WithWarning extends StatelessWidget {
  const _WithWarning({required this.warning, required this.child});

  final String? warning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    if (warning == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          warning,
          style: TextStyle(color: XFormTheme.of(context).errorColorOf(context)),
        ),
        child,
      ],
    );
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
    final (:choices, :warning) = loadChoices(context, node);
    return _WithWarning(warning: warning, child: _input(context, choices));
  }

  Widget _input(BuildContext context, List<SelectChoice> choices) {
    final appearance = Appearance.parse(node.appearance);
    if (appearance.has('image-map')) return ImageMapInput(node);
    if (appearance.has('map') && XFormScope.of(context).delegates.canShowMaps) {
      return SelectFromMapInput(node);
    }
    if (appearance.has('autocomplete')) {
      return _Filtered(
        node: node,
        choices: choices,
        builder: (filtered) => _SelectOneChoices(
          node: node,
          appearance: appearance,
          choices: filtered,
        ),
      );
    }
    if (appearance.has('minimal')) {
      return _SelectOneDropdown(node: node, choices: choices);
    }
    if (appearance.has('list')) {
      return ChoiceRowInput(node, showLabels: true, showButtons: true);
    }
    return _SelectOneChoices(
      node: node,
      appearance: appearance,
      choices: choices,
    );
  }
}

/// The choices of a select one as tiles or a Likert scale; tapping the
/// selected choice clears it.
class _SelectOneChoices extends StatelessWidget {
  const _SelectOneChoices({
    required this.node,
    required this.appearance,
    required this.choices,
  });

  final QuestionNode node;
  final Appearance appearance;
  final List<SelectChoice> choices;

  @override
  Widget build(BuildContext context) {
    final selected = selectedValues(node).firstOrNull;
    void tap(SelectChoice c) =>
        selectChoice(context, node, c.value == selected ? null : c);
    return _SelectOneGroup(
      node: node,
      choices: choices,
      selected: selected,
      child: appearance.has('likert')
          ? _Likert(node: node, choices: choices, onTap: tap)
          : _ChoiceTiles(
              node: node,
              appearance: appearance,
              choices: choices,
              selected: {?selected},
              onTap: tap,
            ),
    );
  }
}

/// A drop-down of a select one's choices (`minimal`).
class _SelectOneDropdown extends StatelessWidget {
  const _SelectOneDropdown({required this.node, required this.choices});

  final QuestionNode node;
  final List<SelectChoice> choices;

  @override
  Widget build(BuildContext context) {
    final selected = selectedValues(node).firstOrNull;
    final scope = XFormScope.of(context);
    // Named by the question for screen readers while nothing is selected.
    return Semantics(
      label: odkMarkdownToPlainText(node.label.text ?? ''),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selected),
        initialValue: selected,
        isExpanded: true,
        // Items with images are taller than the default height; the field
        // shows the selected label only.
        itemHeight: null,
        selectedItemBuilder: (context) => [
          for (final c in choices)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                odkMarkdownToPlainText(node.choiceLabel(c) ?? c.value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        items: [
          for (final c in choices)
            DropdownMenuItem(
              value: c.value,
              // The menu is a route outside the form's scope.
              child: XFormScope(
                controller: scope.controller,
                delegates: scope.delegates,
                overrides: scope.overrides,
                guidanceHints: scope.guidanceHints,
                child: ChoiceContent(node, c),
              ),
            ),
        ],
        onChanged: node.isReadonly
            ? null
            : (value) => selectChoice(
                context,
                node,
                choices.where((c) => c.value == value).firstOrNull,
              ),
      ),
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
    final (:choices, :warning) = loadChoices(context, node);
    return _WithWarning(warning: warning, child: _input(choices));
  }

  Widget _input(List<SelectChoice> choices) {
    final appearance = Appearance.parse(node.appearance);
    if (appearance.has('image-map')) return ImageMapInput(node);
    if (appearance.has('minimal')) {
      return _SelectMultiDialogField(node: node, choices: choices);
    }
    if (appearance.has('autocomplete')) {
      return _Filtered(
        node: node,
        choices: choices,
        builder: (filtered) => _SelectMultiChoices(
          node: node,
          appearance: appearance,
          choices: filtered,
        ),
      );
    }
    if (appearance.has('list')) {
      return ChoiceRowInput(node, showLabels: true, showButtons: true);
    }
    return _SelectMultiChoices(
      node: node,
      appearance: appearance,
      choices: choices,
    );
  }
}

/// The choices of a select multiple as tiles.
class _SelectMultiChoices extends StatelessWidget {
  const _SelectMultiChoices({
    required this.node,
    required this.appearance,
    required this.choices,
    this.adaptiveColumns = true,
  });

  final QuestionNode node;
  final Appearance appearance;
  final List<SelectChoice> choices;
  final bool adaptiveColumns;

  @override
  Widget build(BuildContext context) => _ChoiceTiles(
    node: node,
    appearance: appearance,
    choices: choices,
    selected: selectedValues(node),
    onTap: (c) => toggleSelection(context, node, c.value),
    adaptiveColumns: adaptiveColumns,
  );
}

/// A field listing a select multiple's selected labels that opens a
/// dialog of check boxes (`minimal`).
class _SelectMultiDialogField extends StatelessWidget {
  const _SelectMultiDialogField({required this.node, required this.choices});

  final QuestionNode node;
  final List<SelectChoice> choices;

  Future<void> _openDialog(BuildContext context) {
    final scope = XFormScope.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => XFormScope(
        controller: scope.controller,
        delegates: scope.delegates,
        overrides: scope.overrides,
        guidanceHints: scope.guidanceHints,
        child: AlertDialog(
          content: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: scope.controller.listenableFor(node.ref),
              builder: (context, _) => _SelectMultiChoices(
                node: node,
                appearance: Appearance.parse(null),
                choices: choicesOf(context, node),
                adaptiveColumns: false,
              ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedValues(node);
    final text = [
      for (final c in choices)
        if (selected.contains(c.value)) node.choiceLabel(c) ?? c.value,
    ].join(', ');
    return InkWell(
      onTap: node.isReadonly ? null : () => _openDialog(context),
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
