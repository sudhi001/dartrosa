import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Visual settings of the form renderer, as a [ThemeExtension]: add it to
/// `ThemeData.extensions`; missing values fall back to the theme.
@immutable
class XFormTheme extends ThemeExtension<XFormTheme> {
  /// Creates a form theme.
  const XFormTheme({
    this.pagePadding = const EdgeInsets.all(16),
    this.questionSpacing = 12,
    this.errorColor,
    this.cardColor,
    this.cardElevation,
    this.cardShape,
    this.cardMargin = const EdgeInsets.symmetric(vertical: 8),
    this.cardPadding = const EdgeInsets.all(16),
  });

  /// Padding around a page (pager screen or scrolling form).
  final EdgeInsets pagePadding;

  /// Vertical space above and below each question.
  final double questionSpacing;

  /// Color of validation errors (default: the color scheme's error).
  final Color? errorColor;

  /// Background of group and repeat-instance cards.
  final Color? cardColor;

  /// Elevation of group and repeat-instance cards.
  final double? cardElevation;

  /// Shape of group and repeat-instance cards.
  final ShapeBorder? cardShape;

  /// Margin around group and repeat-instance cards.
  final EdgeInsets cardMargin;

  /// Padding inside group and repeat-instance cards.
  final EdgeInsets cardPadding;

  /// The theme's form theme, or the defaults.
  static XFormTheme of(BuildContext context) =>
      Theme.of(context).extension<XFormTheme>() ?? const XFormTheme();

  /// The error color in [context].
  Color errorColorOf(BuildContext context) =>
      errorColor ?? Theme.of(context).colorScheme.error;

  @override
  XFormTheme copyWith({
    EdgeInsets? pagePadding,
    double? questionSpacing,
    Color? errorColor,
    Color? cardColor,
    double? cardElevation,
    ShapeBorder? cardShape,
    EdgeInsets? cardMargin,
    EdgeInsets? cardPadding,
  }) => XFormTheme(
    pagePadding: pagePadding ?? this.pagePadding,
    questionSpacing: questionSpacing ?? this.questionSpacing,
    errorColor: errorColor ?? this.errorColor,
    cardColor: cardColor ?? this.cardColor,
    cardElevation: cardElevation ?? this.cardElevation,
    cardShape: cardShape ?? this.cardShape,
    cardMargin: cardMargin ?? this.cardMargin,
    cardPadding: cardPadding ?? this.cardPadding,
  );

  @override
  XFormTheme lerp(covariant XFormTheme? other, double t) {
    if (other == null) return this;
    return XFormTheme(
      pagePadding: EdgeInsets.lerp(pagePadding, other.pagePadding, t)!,
      questionSpacing: lerpDouble(questionSpacing, other.questionSpacing, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      cardColor: Color.lerp(cardColor, other.cardColor, t),
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t),
      cardShape: ShapeBorder.lerp(cardShape, other.cardShape, t),
      cardMargin: EdgeInsets.lerp(cardMargin, other.cardMargin, t)!,
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
    );
  }
}

/// A group or repeat-instance card styled by [XFormTheme].
class XFormCard extends StatelessWidget {
  /// Creates a card around [child].
  const XFormCard({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = XFormTheme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: theme.cardElevation,
      shape: theme.cardShape,
      margin: theme.cardMargin,
      child: Padding(padding: theme.cardPadding, child: child),
    );
  }
}
