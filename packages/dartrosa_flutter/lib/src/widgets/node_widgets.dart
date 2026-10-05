// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';
import '../theme.dart';
import '../xform_scope.dart';
import 'common.dart';
import 'external_app_inputs.dart';
import 'label.dart';
import 'question_widget.dart';
import 'select_widgets.dart';

/// The key of [node]'s widget (see [nodeWidget]).
Key nodeKey(FormNode node) => ValueKey(switch (node) {
  QuestionNode() => 'q:${node.index}',
  GroupNode() => 'g:${node.index}',
  RepeatNode() => 'r:${node.index}',
  RepeatInstanceNode() => 'i:${node.index}',
  RootNode() => 'root',
});

/// The widget for any [node]: a question, group, repeat or repeat
/// instance.
Widget nodeWidget(FormNode node) => switch (node) {
  QuestionNode() => QuestionWidget(node, key: nodeKey(node)),
  GroupNode() => GroupWidget(node, key: nodeKey(node)),
  RepeatNode() => RepeatWidget(node, key: nodeKey(node)),
  RepeatInstanceNode() => RepeatInstanceWidget(node, key: nodeKey(node)),
  RootNode() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final child in node.visibleChildren) nodeWidget(child)],
  ),
};

/// A group: its label and its relevant children.
class GroupWidget extends StatelessWidget {
  /// Creates the widget for [node].
  const GroupWidget(this.node, {super.key});

  /// The group.
  final GroupNode node;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: XFormScope.of(context).controller.listenableFor(node.ref),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final label = node.label;
    var children = isTableList(node)
        ? _tableList(context)
        : [for (final child in node.visibleChildren) nodeWidget(child)];
    if (intentOf(node) != null &&
        XFormScope.of(context).delegates.canLaunchExternalApps) {
      children = [
        IntentGroup.of(
          node,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ];
    }
    if (label.text == null || label.text!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return XFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          XFormLabel(label, style: Theme.of(context).textTheme.titleLarge),
          ...children,
        ],
      ),
    );
  }

  /// The rows of a `table-list` group: a header of the first select's
  /// choice labels, then one row of buttons per select.
  List<Widget> _tableList(BuildContext context) {
    final children = node.visibleChildren;
    final header = children
        .whereType<QuestionNode>()
        .where(_isSelect)
        .firstOrNull;
    return [
      if (header != null)
        ChoiceRowInput(
          header,
          showLabels: true,
          showButtons: false,
          leading: const SizedBox.shrink(),
        ),
      for (final (i, child) in children.indexed) ...[
        // Lines between the rows help follow a row across a wide table.
        if (i > 0) const Divider(height: 1),
        if (child is QuestionNode && _isSelect(child))
          QuestionWidget(child, inTableList: true, key: nodeKey(child))
        else
          nodeWidget(child),
      ],
    ];
  }

  static bool _isSelect(QuestionNode q) =>
      q.controlType == ControlType.selectOne ||
      q.controlType == ControlType.selectMulti;
}

/// A repeat: its instances and an "add" button while instances can be
/// added.
class RepeatWidget extends StatelessWidget {
  /// Creates the widget for [node].
  const RepeatWidget(this.node, {super.key});

  /// The repeat.
  final RepeatNode node;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: XFormScope.of(
      context,
    ).controller.listenableFor(node.ref?.genericize()),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final instances = node.instances;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final instance in instances)
          if (instance.isRelevant) nodeWidget(instance),
        if (node.canAddInstance)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(
                XFormLocalizations.of(context).addRepeat(node.label.text),
              ),
              onPressed: () => controller.addRepeatInstance(node),
            ),
          ),
      ],
    );
  }
}

/// One repeat instance: header, remove button and children.
class RepeatInstanceWidget extends StatelessWidget {
  /// Creates the widget for [node].
  const RepeatInstanceWidget(this.node, {super.key});

  /// The repeat instance.
  final RepeatInstanceNode node;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: XFormScope.of(context).controller.listenableFor(node.ref),
    builder: (context, _) => _build(context),
  );

  /// Asks before deleting the instance and its answers.
  Future<bool> _confirmRemove(BuildContext context) async {
    final strings = XFormLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final name = node.header ?? '${node.position + 1}';
    // The dialog is a route outside the form: keep the form's direction.
    final direction = Directionality.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: direction,
        child: AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: Text(strings.removeRepeatTitle(name)),
          content: Text(strings.removeRepeatMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(material.cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: XFormTheme.of(context).errorColorOf(context),
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.remove),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  Widget _build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final repeat = node.element as GroupDef;
    return XFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.header ?? '${node.position + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!repeat.noAddRemove)
                IconButton(
                  tooltip: XFormLocalizations.of(context).remove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await _confirmRemove(context)) {
                      controller.removeRepeatInstance(node);
                    }
                  },
                ),
            ],
          ),
          for (final child in node.visibleChildren) nodeWidget(child),
        ],
      ),
    );
  }
}
