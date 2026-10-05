import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../localizations.dart';
import '../theme.dart';
import '../xform_scope.dart';
import 'external_app_inputs.dart';
import 'label.dart';
import 'question_widget.dart';
import 'select_widgets.dart';

/// The widget for any [node]: a question, group, repeat or repeat
/// instance.
Widget nodeWidget(FormNode node) => switch (node) {
  QuestionNode() => QuestionWidget(node, key: ValueKey('q:${node.index}')),
  GroupNode() => GroupWidget(node, key: ValueKey('g:${node.index}')),
  RepeatNode() => RepeatWidget(node, key: ValueKey('r:${node.index}')),
  RepeatInstanceNode() => RepeatInstanceWidget(
    node,
    key: ValueKey('i:${node.index}'),
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
    var children =
        (node.appearance?.toLowerCase().contains('table-list') ?? false)
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
      for (final child in children)
        if (child is QuestionNode && _isSelect(child))
          QuestionWidget(
            child,
            inTableList: true,
            key: ValueKey('q:${child.index}'),
          )
        else
          nodeWidget(child),
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
  Widget build(BuildContext context) {
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
                  onPressed: () => controller.removeRepeatInstance(node),
                ),
            ],
          ),
          for (final child in node.visibleChildren) nodeWidget(child),
        ],
      ),
    );
  }
}
