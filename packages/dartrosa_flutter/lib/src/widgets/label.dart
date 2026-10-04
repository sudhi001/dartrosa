import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../markdown.dart';
import '../xform_scope.dart';

/// A form label: its text in ODK markdown (with a required marker) and
/// its image, if the app's delegates can load it.
class XFormLabel extends StatelessWidget {
  /// Creates a label.
  const XFormLabel(this.text, {this.required = false, this.style, super.key});

  /// The label.
  final LocalizedText text;

  /// Whether to show the required marker.
  final bool required;

  /// The text style (defaults to the theme's title style).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = text.image == null
        ? null
        : XFormScope.maybeOf(context)?.delegates.image(text.image!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.text != null && text.text!.isNotEmpty)
          XFormMarkdown(
            text.text!,
            prefix: required
                ? TextSpan(
                    text: '* ',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                : null,
            style: style ?? theme.textTheme.titleMedium,
          ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Image(image: image, semanticLabel: text.text),
          ),
      ],
    );
  }
}

/// A question's hint and guidance hint, in ODK markdown.
class XFormHint extends StatelessWidget {
  /// Creates the hints of [node].
  const XFormHint(this.node, {super.key});

  /// The question.
  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final hint = node.hint;
    final mode =
        XFormScope.maybeOf(context)?.guidanceHints ?? GuidanceHintMode.yes;
    final guidance = mode == GuidanceHintMode.no
        ? null
        : node.guidanceHint ?? node.label.guidance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null && hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: XFormMarkdown(hint, style: style),
          ),
        if (guidance != null && guidance.isNotEmpty)
          if (mode == GuidanceHintMode.collapsed)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text('Guidance', style: style),
              expandedAlignment: AlignmentDirectional.centerStart,
              children: [XFormMarkdown(guidance, style: style)],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: XFormMarkdown(
                guidance,
                style: style?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
      ],
    );
  }
}
