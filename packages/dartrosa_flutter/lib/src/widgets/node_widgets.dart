import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../xform_scope.dart';
import 'label.dart';
import 'question_widget.dart';

/// The widget for any [node]: a question, group, repeat or repeat
/// instance.
Widget nodeWidget(FormNode node) => switch (node) {
  QuestionNode() => QuestionWidget(node, key: ValueKey('q:${node.ref}')),
  GroupNode() => GroupWidget(node, key: ValueKey('g:${node.ref}')),
  RepeatNode() => RepeatWidget(node, key: ValueKey('r:${node.ref}')),
  RepeatInstanceNode() => RepeatInstanceWidget(
    node,
    key: ValueKey('i:${node.ref}'),
  ),
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
  Widget build(BuildContext context) {
    final label = node.label;
    final children = [
      for (final child in node.visibleChildren) nodeWidget(child),
    ];
    if (label.text == null || label.text!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            XFormLabel(label, style: Theme.of(context).textTheme.titleLarge),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A repeat: its instances and an "add" button while instances can be
/// added.
class RepeatWidget extends StatelessWidget {
  /// Creates the widget for [node].
  const RepeatWidget(this.node, {super.key});

  /// The repeat.
  final RepeatNode node;

  @override
  Widget build(BuildContext context) {
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
              label: Text('Add ${node.label.text ?? 'another'}'.trim()),
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
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final repeat = node.element as GroupDef;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => controller.removeRepeatInstance(node),
                  ),
              ],
            ),
            for (final child in node.visibleChildren) nodeWidget(child),
          ],
        ),
      ),
    );
  }
}
