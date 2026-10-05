// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../appearance.dart';
import '../localizations.dart';
import '../markdown.dart';
import '../theme.dart';
import '../xform_scope.dart';
import 'common.dart';
import 'date_input.dart';
import 'external_app_inputs.dart';
import 'label.dart';
import 'map_inputs.dart';
import 'question_focus.dart';
import 'range_input.dart';
import 'select_widgets.dart';
import 'special_inputs.dart';
import 'text_input.dart';

/// A question: label, hint, the input widget for its control type and
/// appearance, and the error of a rejected answer.
///
/// Rebuilds only when its node changes (see
/// `XFormController.listenableFor`): when the group or list around it
/// rebuilds, the question keeps what it built.
class QuestionWidget extends StatefulWidget {
  /// Creates the widget for [node].
  const QuestionWidget(this.node, {this.inTableList = false, super.key});

  /// The question.
  final QuestionNode node;

  /// Whether the question is a row of a `table-list` group (selects show
  /// as `list-nolabel`).
  final bool inTableList;

  /// The override for [node] in [overrides]: by control type and the
  /// whole appearance, by control type and any appearance token, or by
  /// control type.
  static QuestionWidgetBuilder? overrideFor(
    QuestionNode node,
    Map<String, QuestionWidgetBuilder> overrides,
  ) {
    if (overrides.isEmpty) return null;
    final type = node.controlType.name;
    final raw = node.appearance?.toLowerCase().trim();
    return overrides['$type:$raw'] ??
        Appearance.parse(
          raw,
        ).tokens.map((t) => overrides['$type:$t']).nonNulls.firstOrNull ??
        overrides[type];
  }

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  /// The form's scope the question was built in.
  XFormScope? _scope;

  /// What the node notifies.
  Listenable? _listenable;

  /// The last build, reused until the node, its scope or a dependency
  /// changes.
  Widget? _built;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _built = null;
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant QuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parents rebuild with new node objects for the same nodes.
    if (oldWidget.node.index != widget.node.index ||
        oldWidget.inTableList != widget.inTableList) {
      _built = null;
    }
    _subscribe();
  }

  @override
  void dispose() {
    _listenable?.removeListener(_changed);
    super.dispose();
  }

  /// Listens to the node in the current scope; forgets the last build if
  /// the scope changed.
  void _subscribe() {
    final scope = XFormScope.of(context);
    final previous = _scope;
    if (previous == null ||
        !identical(previous.controller, scope.controller) ||
        !identical(previous.delegates, scope.delegates) ||
        !identical(previous.overrides, scope.overrides) ||
        previous.guidanceHints != scope.guidanceHints) {
      _built = null;
    }
    _scope = scope;
    final listenable = scope.controller.listenableFor(widget.node.ref);
    if (identical(listenable, _listenable)) return;
    _listenable?.removeListener(_changed);
    _listenable = listenable..addListener(_changed);
    _built = null;
  }

  void _changed() => setState(() => _built = null);

  @override
  Widget build(BuildContext context) => _built ??= _build(context);

  Widget _build(BuildContext context) {
    final node = widget.node;
    final scope = _scope!;
    final override = QuestionWidget.overrideFor(node, scope.overrides);
    if (override != null) return override(context, node);
    final appearance = Appearance.parse(node.appearance)..warnUnknown();
    final error = scope.controller.errorFor(
      node.index,
      XFormLocalizations.of(context),
    );
    final isSelect =
        node.controlType == ControlType.selectOne ||
        node.controlType == ControlType.selectMulti;
    final inRow =
        isSelect &&
        (widget.inTableList ||
            appearance.has('label') ||
            appearance.has('list-nolabel'));
    return _QuestionSemantics(
      node: node,
      invalid: error != null,
      child: QuestionErrorScope(
        hasError: error != null,
        child: inRow
            ? _ChoiceRowQuestion(
                node: node,
                error: error,
                labelsOnly: !widget.inTableList && appearance.has('label'),
              )
            : _StackedQuestion(
                node: node,
                appearance: appearance,
                error: error,
              ),
      ),
    );
  }
}

/// A semantics container labelled with the question label and whether
/// it is required, marked invalid while its answer is rejected.
class _QuestionSemantics extends StatelessWidget {
  const _QuestionSemantics({
    required this.node,
    required this.invalid,
    required this.child,
  });

  final QuestionNode node;
  final bool invalid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = odkMarkdownToPlainText(node.label.text ?? '');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: node.isRequired
          ? '$label, ${XFormLocalizations.of(context).required}'
          : label,
      validationResult: invalid
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      child: child,
    );
  }
}

/// A select shown as one row: label and error, then its choices
/// (`label`, `list-nolabel`, `table-list` rows).
class _ChoiceRowQuestion extends StatelessWidget {
  const _ChoiceRowQuestion({
    required this.node,
    required this.error,
    required this.labelsOnly,
  });

  final QuestionNode node;
  final String? error;
  final bool labelsOnly;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ChoiceRowInput(
        node,
        showLabels: labelsOnly,
        showButtons: !labelsOnly,
        leading: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: XFormLabel(node.label, required: node.isRequired),
            ),
            if (error != null) _Error(error),
          ],
        ),
      ),
    );
  }
}

/// Label, hints, input and error, one under the other.
class _StackedQuestion extends StatelessWidget {
  const _StackedQuestion({
    required this.node,
    required this.appearance,
    required this.error,
  });

  final QuestionNode node;
  final Appearance appearance;
  final String? error;

  /// Whether [node] is a note: read-only text without a value (ODK
  /// Collect shows the value of a read-only text, in place of the field)
  /// and without an appearance that shows a widget anyway (`printer` when
  /// printing is available, `url`).
  bool _isNote(BuildContext context) =>
      node.isNote &&
      (node.value?.displayText ?? '').isEmpty &&
      !(appearance.has('printer') &&
          XFormScope.of(context).delegates.canPrint) &&
      !appearance.has('url');

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: XFormTheme.of(context).questionSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: XFormLabel(node.label, required: node.isRequired),
          ),
          XFormHint(node),
          if (!_isNote(context))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _QuestionInput(node: node, appearance: appearance),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _Error(error),
            ),
        ],
      ),
    );
  }
}

/// The input widget for [node]'s control type, data type and appearance.
class _QuestionInput extends StatelessWidget {
  const _QuestionInput({required this.node, required this.appearance});

  final QuestionNode node;
  final Appearance appearance;

  @override
  Widget build(BuildContext context) {
    switch (node.controlType) {
      case ControlType.selectOne:
        return SelectOneInput(node);
      case ControlType.selectMulti:
        return SelectMultiInput(node);
      case ControlType.rank:
        return _Rank(node);
      case ControlType.trigger:
        return _Trigger(node);
      case ControlType.range:
        return RangeInput(node);
      case ControlType.imageChoose ||
          ControlType.audioCapture ||
          ControlType.videoCapture ||
          ControlType.fileCapture ||
          ControlType.upload ||
          ControlType.osmCapture:
        return _Media(node);
      default:
    }
    final delegates = XFormScope.of(context).delegates;
    final ex = appearance.has('ex:') && delegates.canLaunchExternalApps;
    // Text and numbers: the widget for the appearance, in ODK Collect's
    // order (integer: `counter`, `ex:`; decimal: `ex:`, `bearing`; text:
    // `printer`, `ex:`, `numbers`, `url`), else a text field.
    switch (node.dataType) {
      case DataType.date || DataType.time || DataType.dateTime:
        return DateTimeInput(node);
      case DataType.geopoint || DataType.geotrace || DataType.geoshape:
        return _Geo(node, appearance: appearance);
      case DataType.barcode:
        return _Barcode(node);
      case DataType.integer || DataType.long:
        if (appearance.has('counter')) return CounterInput(node);
        if (ex) return ExternalAppInput(node);
      case DataType.decimal:
        if (ex) return ExternalAppInput(node);
        if (appearance.has('bearing') && delegates.canReadBearing) {
          return BearingInput(node);
        }
      case DataType.text:
        if (appearance.has('printer') && delegates.canPrint) {
          return PrinterInput(node);
        }
        if (ex) return ExternalAppInput(node);
        if (!appearance.has('numbers') && appearance.has('url')) {
          return UrlInput(node);
        }
      default:
    }
    return TextQuestionInput(node);
  }
}

/// A validation error next to its question, with an error icon; read
/// out by screen readers when it appears.
class _Error extends StatelessWidget {
  const _Error(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = XFormTheme.of(context).errorColorOf(context);
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: color);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6, top: 1),
            // Scales with the text.
            child: Icon(
              Icons.error_outline,
              color: color,
              size: MediaQuery.textScalerOf(context).scale(18),
            ),
          ),
          Expanded(child: Text(message, style: style)),
        ],
      ),
    );
  }
}

/// Rank: a reorderable list.
class _Rank extends StatelessWidget {
  const _Rank(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final byValue = {for (final c in node.choices) c.value: c};
    final order = switch (node.value) {
      MultipleItemsValue(:final selections) => [
        for (final s in selections) ?byValue[s.value],
      ],
      _ => node.choices,
    };
    void move(int from, int to) {
      if (node.isReadonly) return;
      final list = [...order];
      final moved = list.removeAt(from);
      list.insert(to, moved);
      answerQuestion(
        context,
        node,
        MultipleItemsValue([for (final c in list) Selection.ofChoice(c)]),
      );
    }

    final strings = XFormLocalizations.of(context);
    final enabled = !node.isReadonly;
    // Dragging, or the move buttons (keyboard, mouse, screen readers).
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: move,
      children: [
        for (final (i, c) in order.indexed)
          ReorderableDelayedDragStartListener(
            key: ValueKey(c.value),
            index: i,
            enabled: enabled,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 8),
              leading: ReorderableDragStartListener(
                index: i,
                enabled: enabled,
                child: const Icon(Icons.drag_indicator),
              ),
              title: Text(node.choiceLabel(c) ?? c.value),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: strings.moveUp,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: enabled && i > 0 ? () => move(i, i - 1) : null,
                  ),
                  IconButton(
                    tooltip: strings.moveDown,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: enabled && i < order.length - 1
                        ? () => move(i, i + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Trigger: an acknowledgement (answer `OK`).
class _Trigger extends StatelessWidget {
  const _Trigger(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: node.value != null,
    enabled: !node.isReadonly,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(XFormLocalizations.of(context).acknowledge),
    onChanged: (on) =>
        answerQuestion(context, node, on! ? const StringValue('OK') : null),
  );
}

/// A value captured by a delegate, or typed when no delegate exists.
class _Captured extends StatelessWidget {
  const _Captured({
    required this.node,
    required this.available,
    required this.capture,
    required this.buttonLabel,
    required this.icon,
  });

  final QuestionNode node;
  final bool available;
  final Future<String?> Function() capture;
  final String buttonLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!available) return TextQuestionInput(node);
    return AnswerWithActions(
      answer: Text(node.displayValue ?? '—'),
      actions: [
        if (!node.isReadonly)
          FilledButton.tonalIcon(
            icon: Icon(icon),
            label: Text(buttonLabel),
            onPressed: () async {
              final text = await capture();
              if (text == null || !context.mounted) return;
              answerQuestion(context, node, UncastValue(text));
            },
          ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    final mediaType = switch (node.controlType) {
      ControlType.imageChoose => 'image/*',
      ControlType.audioCapture => 'audio/*',
      ControlType.videoCapture => 'video/*',
      ControlType.osmCapture => 'osm/*',
      _ => '*/*',
    };
    return _Captured(
      node: node,
      available: delegates.canCaptureMedia,
      capture: () => delegates.captureMedia(
        context,
        mediaType: mediaType,
        appearance: node.appearance,
      ),
      buttonLabel: XFormLocalizations.of(context).capture,
      icon: Icons.attach_file,
    );
  }
}

class _Geo extends StatelessWidget {
  const _Geo(this.node, {required this.appearance});

  final QuestionNode node;
  final Appearance appearance;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    if (delegates.canShowMaps &&
        (node.dataType != DataType.geopoint ||
            appearance.has('maps') ||
            appearance.has('placement-map'))) {
      return GeoMapInput(node);
    }
    return _Captured(
      node: node,
      available: delegates.canLocate && node.dataType == DataType.geopoint,
      capture: () => delegates.currentLocation(context),
      buttonLabel: XFormLocalizations.of(context).getLocation,
      icon: Icons.my_location,
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    return _Captured(
      node: node,
      available: delegates.canScanBarcode,
      capture: () => delegates.scanBarcode(context),
      buttonLabel: XFormLocalizations.of(context).scan,
      icon: Icons.qr_code_scanner,
    );
  }
}
