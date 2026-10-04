import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../appearance.dart';
import '../localizations.dart';
import '../markdown.dart';
import '../theme.dart';
import '../xform_scope.dart';
import 'date_input.dart';
import 'label.dart';
import 'map_inputs.dart';
import 'range_input.dart';
import 'select_widgets.dart';
import 'text_input.dart';

/// A question: label, hint, the input widget for its control type and
/// appearance, and the error of a rejected answer. Rebuilds only when its
/// node changes.
class QuestionWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scope = XFormScope.of(context);
    final controller = scope.controller;
    return ListenableBuilder(
      listenable: controller.listenableFor(node.ref),
      builder: (context, _) {
        final override = overrideFor(node, scope.overrides);
        if (override != null) return override(context, node);
        final appearance = Appearance.parse(node.appearance)..warnUnknown();
        final error = controller.errorFor(
          node.index,
          XFormLocalizations.of(context),
        );
        final formTheme = XFormTheme.of(context);
        final errorColor = formTheme.errorColorOf(context);
        final isSelect =
            node.controlType == ControlType.selectOne ||
            node.controlType == ControlType.selectMulti;
        if (isSelect &&
            (inTableList ||
                appearance.has('label') ||
                appearance.has('list-nolabel'))) {
          final labelsOnly = !inTableList && appearance.has('label');
          return _semantics(
            context,
            error,
            Padding(
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
                    if (error != null) _Error(error, color: errorColor),
                  ],
                ),
              ),
            ),
          );
        }
        return _semantics(
          context,
          error,
          Padding(
            padding: EdgeInsets.symmetric(vertical: formTheme.questionSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: XFormLabel(node.label, required: node.isRequired),
                ),
                XFormHint(node),
                if (!node.isNote)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _input(context),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _Error(error, color: errorColor),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A semantics container labelled with the question label, whether it
  /// is required, and whether its answer is invalid.
  Widget _semantics(BuildContext context, String? error, Widget child) {
    final label = odkMarkdownToPlainText(node.label.text ?? '');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: node.isRequired
          ? '$label, ${XFormLocalizations.of(context).required}'
          : label,
      validationResult: error == null
          ? SemanticsValidationResult.none
          : SemanticsValidationResult.invalid,
      child: child,
    );
  }

  Widget _input(BuildContext context) => switch (node.controlType) {
    ControlType.selectOne => SelectOneInput(node),
    ControlType.selectMulti => SelectMultiInput(node),
    ControlType.rank => _Rank(node),
    ControlType.trigger => _Trigger(node),
    ControlType.range => RangeInput(node),
    ControlType.imageChoose ||
    ControlType.audioCapture ||
    ControlType.videoCapture ||
    ControlType.fileCapture ||
    ControlType.upload ||
    ControlType.osmCapture => _Media(node),
    _ => switch (node.dataType) {
      DataType.date ||
      DataType.time ||
      DataType.dateTime => DateTimeInput(node),
      DataType.geopoint || DataType.geotrace || DataType.geoshape => _Geo(node),
      DataType.barcode => _Barcode(node),
      _ => TextQuestionInput(node),
    },
  };
}

/// A validation error, read out by screen readers when it appears.
class _Error extends StatelessWidget {
  const _Error(this.message, {required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(message, style: TextStyle(color: color)),
  );
}

void _answer(BuildContext context, QuestionNode node, AnswerValue? value) =>
    XFormScope.of(context).controller.answer(node.index, value);

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
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (from, to) {
        if (node.isReadonly) return;
        final list = [...order];
        final moved = list.removeAt(from);
        list.insert(to, moved);
        _answer(
          context,
          node,
          MultipleItemsValue([for (final c in list) Selection.ofChoice(c)]),
        );
      },
      children: [
        for (final c in order)
          ListTile(
            key: ValueKey(c.value),
            title: Text(node.choiceLabel(c) ?? c.value),
            trailing: const Icon(Icons.drag_handle),
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
        _answer(context, node, on! ? const StringValue('OK') : null),
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
    return Row(
      children: [
        Expanded(child: Text(node.displayValue ?? '—')),
        if (!node.isReadonly)
          FilledButton.tonalIcon(
            icon: Icon(icon),
            label: Text(buttonLabel),
            onPressed: () async {
              final text = await capture();
              if (text == null || !context.mounted) return;
              _answer(context, node, UncastValue(text));
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
  const _Geo(this.node);

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final delegates = XFormScope.of(context).delegates;
    final appearance = Appearance.parse(node.appearance);
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
