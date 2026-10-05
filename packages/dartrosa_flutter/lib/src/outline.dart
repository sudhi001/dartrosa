// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The form outline: groups and questions with their state, the current
// position and a way to jump to any of them, like ODK Collect's
// hierarchy ("jump to") screen. XFormView shows it as a side panel on
// wide windows and as a bottom sheet elsewhere.

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'localizations.dart';
import 'markdown.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'window_size.dart';
import 'xform_controller.dart';

/// One line of the outline.
@immutable
final class OutlineEntry {
  /// Creates the entry of [node] at [depth], on pager [screen].
  const OutlineEntry(this.node, this.depth, this.screen);

  /// A question, a labelled group, a repeat or a repeat instance.
  final FormNode node;

  /// How deep it is nested in labelled groups and repeats.
  final int depth;

  /// The pager screen showing it: the outermost `field-list` (or
  /// `table-list`) group around it, else the question itself; `null` for
  /// group and repeat headers outside such a group.
  final FormIndex? screen;
}

/// Whether the pager shows [node] as one screen (`field-list`, or
/// `table-list`, which implies it).
bool isScreenGroup(FormNode node) =>
    node is GroupNode && (node.isFieldList || isTableList(node));

/// The outermost screen group of [node] (or [node] itself), if any.
FormNode? screenGroupOf(FormNode node) {
  for (final ancestor in node.ancestors) {
    if (isScreenGroup(ancestor)) return ancestor;
  }
  return isScreenGroup(node) ? node : null;
}

/// The first relevant question in [node] (itself if it is one).
QuestionNode? firstQuestionIn(FormNode node) {
  if (!node.isRelevant) return null;
  if (node is QuestionNode) return node;
  final children = switch (node) {
    ContainerNode() => node.children,
    RepeatNode() => node.instances,
    QuestionNode() => const <FormNode>[],
  };
  for (final child in children) {
    if (firstQuestionIn(child) case final q?) return q;
  }
  return null;
}

/// The relevant nodes of the form under [root], in form order.
List<OutlineEntry> outlineEntries(RootNode root) {
  final entries = <OutlineEntry>[];
  void visit(FormNode node, int depth, FormIndex? screen) {
    if (!node.isRelevant) return;
    switch (node) {
      case QuestionNode():
        entries.add(OutlineEntry(node, depth, screen ?? node.index));
      case RepeatNode():
        entries.add(OutlineEntry(node, depth, screen));
        for (final instance in node.instances) {
          visit(instance, depth + 1, screen);
        }
      case RepeatInstanceNode():
        entries.add(OutlineEntry(node, depth, screen));
        for (final child in node.children) {
          visit(child, depth + 1, screen);
        }
      case GroupNode():
        final ownScreen = screen ?? (isScreenGroup(node) ? node.index : null);
        final labelled = node.label.text?.isNotEmpty ?? false;
        if (labelled) entries.add(OutlineEntry(node, depth, ownScreen));
        for (final child in node.children) {
          visit(child, labelled ? depth + 1 : depth, ownScreen);
        }
      case RootNode():
        for (final child in node.children) {
          visit(child, depth, screen);
        }
    }
  }

  visit(root, 0, null);
  return entries;
}

/// Whether [node] takes an answer from the person filling the form (not
/// a note or a read-only question).
bool isAnswerable(QuestionNode node) => !node.isNote && !node.isReadonly;

/// Counts over an outline: the pager's screens and the answers.
@immutable
final class OutlineSummary {
  const OutlineSummary._(
    this.screens,
    this.answerable,
    this.answered,
    this.missing,
  );

  /// The summary of [entries], with errors from [controller].
  factory OutlineSummary.of(
    List<OutlineEntry> entries,
    XFormController controller,
  ) {
    final screens = <FormIndex>[];
    var answerable = 0;
    var answered = 0;
    var missing = 0;
    for (final entry in entries) {
      final node = entry.node;
      if (node is! QuestionNode) continue;
      final screen = entry.screen;
      if (screen != null && (screens.isEmpty || screens.last != screen)) {
        screens.add(screen);
      }
      if (!isAnswerable(node)) continue;
      answerable++;
      if (node.value != null) {
        answered++;
      } else if (node.isRequired) {
        missing++;
      }
    }
    return OutlineSummary._(screens, answerable, answered, missing);
  }

  /// The pager's screens in order (questions, and `field-list` groups).
  final List<FormIndex> screens;

  /// The number of questions taking an answer.
  final int answerable;

  /// How many of them have one.
  final int answered;

  /// How many required questions have none.
  final int missing;

  /// The 0-based position of [screen] among [screens], or -1.
  int positionOf(FormIndex? screen) =>
      screen == null ? -1 : screens.indexOf(screen);
}

/// The outline of the form of [controller]: progress, then every group
/// and question; tapping one calls [onSelected].
class FormOutline extends StatefulWidget {
  /// Creates the outline.
  const FormOutline({
    required this.controller,
    required this.currentScreen,
    required this.onSelected,
    this.onClose,
    this.closeIcon = Icons.close,
    this.scrollController,
    super.key,
  });

  /// The form's controller.
  final XFormController controller;

  /// The pager screen shown, highlighted in the outline.
  final ValueListenable<FormIndex?> currentScreen;

  /// Called with the node tapped.
  final ValueChanged<FormNode> onSelected;

  /// Closes or hides the outline; no close button when `null`.
  final VoidCallback? onClose;

  /// The close button's icon.
  final IconData closeIcon;

  /// Scrolls the list (a bottom sheet's); one of its own otherwise.
  final ScrollController? scrollController;

  @override
  State<FormOutline> createState() => _FormOutlineState();
}

class _FormOutlineState extends State<FormOutline> {
  ScrollController? _ownScroll;
  late Listenable _changes = _listenable();
  final _currentKey = GlobalKey(debugLabel: 'outline current');
  FormIndex? _revealed;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  Listenable _listenable() => Listenable.merge([
    widget.controller,
    widget.controller.formChanges,
    widget.currentScreen,
  ]);

  @override
  void didUpdateWidget(covariant FormOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.currentScreen, widget.currentScreen)) {
      _changes = _listenable();
    }
  }

  @override
  void dispose() {
    _ownScroll?.dispose();
    super.dispose();
  }

  /// Scrolls the current screen's first line into view once it changes.
  void _reveal(FormIndex? current, int index) {
    if (current == null || current == _revealed || index < 0) return;
    _revealed = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scroll = _scroll;
      final context = _currentKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0.3).ignore();
      } else if (scroll.hasClients) {
        // Not built yet (lazy list): jump near it, then align.
        final position = scroll.position;
        scroll.jumpTo(
          (index * 48.0).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _currentKey.currentContext;
          if (mounted && context != null) {
            Scrollable.ensureVisible(context, alignment: 0.3).ignore();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final controller = widget.controller;
      final entries = outlineEntries(controller.session.root);
      final summary = OutlineSummary.of(entries, controller);
      final current = widget.currentScreen.value;
      final firstCurrent = current == null
          ? -1
          : entries.indexWhere((e) => e.screen == current);
      _reveal(current, firstCurrent);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutlineHeader(
            summary: summary,
            onClose: widget.onClose,
            closeIcon: widget.closeIcon,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                return _OutlineTile(
                  key: i == firstCurrent ? _currentKey : null,
                  entry: entry,
                  controller: controller,
                  current: current != null && entry.screen == current,
                  onTap: () => widget.onSelected(entry.node),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// The outline's title, close button and progress.
class _OutlineHeader extends StatelessWidget {
  const _OutlineHeader({
    required this.summary,
    required this.onClose,
    required this.closeIcon,
  });

  final OutlineSummary summary;
  final VoidCallback? onClose;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) {
    final strings = XFormLocalizations.of(context);
    final theme = Theme.of(context);
    final onClose = this.onClose;
    final total = summary.answerable;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.outline,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: strings.hideOutline,
                  icon: Icon(closeIcon),
                  onPressed: onClose,
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The text under it says the same to screen readers.
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : summary.answered / total,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.answeredCount(summary.answered, total),
                  style: theme.textTheme.bodyMedium,
                ),
                if (summary.missing > 0)
                  Text(
                    strings.requiredLeft(summary.missing),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A line of the outline.
class _OutlineTile extends StatelessWidget {
  const _OutlineTile({
    required this.entry,
    required this.controller,
    required this.current,
    required this.onTap,
    super.key,
  });

  final OutlineEntry entry;
  final XFormController controller;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = XFormLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final node = entry.node;
    final label = _labelOf(node);
    final dense = isDesktopOrWeb(context);
    final padding = EdgeInsetsDirectional.only(
      start: 16.0 + 16 * entry.depth,
      end: 16,
    );
    if (node is! QuestionNode) {
      final target = firstQuestionIn(node);
      return ListTile(
        dense: dense,
        contentPadding: padding,
        selected: current,
        leading: Icon(switch (node) {
          RepeatNode() => Icons.repeat,
          RepeatInstanceNode() => Icons.subdirectory_arrow_right,
          _ => Icons.folder_outlined,
        }, size: 20),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        onTap: target == null ? null : onTap,
      );
    }
    final error = controller.failureFor(node.index) != null;
    final answered = node.value != null;
    final answerable = isAnswerable(node);
    final (icon, color, state) = error
        ? (
            Icons.error,
            XFormTheme.of(context).errorColorOf(context),
            strings.needsAttention,
          )
        : !answerable
        ? (Icons.notes, scheme.onSurfaceVariant, null)
        : answered
        ? (Icons.check_circle, scheme.primary, strings.answered)
        : (Icons.radio_button_unchecked, scheme.outline, strings.notAnswered);
    final required = node.isRequired && answerable;
    return ListTile(
      dense: dense,
      contentPadding: padding,
      selected: current,
      selectedTileColor: scheme.secondaryContainer,
      leading: Icon(icon, color: color, size: 20, semanticLabel: state),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            if (required)
              TextSpan(
                text: ' *',
                semanticsLabel: ', ${strings.required}',
                style: TextStyle(
                  color: XFormTheme.of(context).errorColorOf(context),
                ),
              ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  static String _labelOf(FormNode node) {
    final text = switch (node) {
      RepeatInstanceNode(:final header) => header ?? node.label.text,
      _ => node.label.text,
    };
    if (text != null && text.trim().isNotEmpty) {
      return odkMarkdownToPlainText(text).trim();
    }
    // Unlabelled: the instance node's name.
    final ref = '${node.ref ?? ''}';
    return ref.split('/').last.replaceAll(RegExp(r'\[\d+\]$'), '');
  }
}
