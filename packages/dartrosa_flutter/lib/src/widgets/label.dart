import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import '../xform_scope.dart';

/// A form label: its text (with a required marker) and its image, if the
/// app's delegates can load it.
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
        : XFormScope.of(context).delegates.image(text.image!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.text != null && text.text!.isNotEmpty)
          Text.rich(
            TextSpan(
              children: [
                if (required)
                  TextSpan(
                    text: '* ',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                TextSpan(text: text.text),
              ],
            ),
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
