// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

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
    this.maxContentWidth,
    this.adaptiveChoiceColumns = true,
    this.outlinePanelWidth = 320,
  });

  /// The content width cap used when [maxContentWidth] is `null`: on
  /// windows wider than this (plus [pagePadding]) the form is a centered
  /// column of readable line length; narrower windows (phones) use the
  /// full width.
  static const double defaultMaxContentWidth = 720;

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

  /// The widest the form's content gets, [pagePadding] not included.
  ///
  /// On tablets and desktops a form as wide as the window has lines too
  /// long to read and controls far apart, so the questions, the pager's
  /// buttons and the scroll mode's finish button stay at most this wide,
  /// centered. In scroll mode the whole width still scrolls.
  ///
  /// `null` (the default) uses [defaultMaxContentWidth] (720dp): phones
  /// keep the full width, wider windows get a centered column. Use
  /// `double.infinity` to fill any width.
  final double? maxContentWidth;

  /// Whether select questions without a `columns` appearance show their
  /// choices in columns when there is room: four or more short text
  /// choices (no images) on a form at least 560dp wide. Phones keep one
  /// choice per line.
  final bool adaptiveChoiceColumns;

  /// The width of the outline side panel `XFormView` shows on expanded
  /// (840dp and wider) windows.
  final double outlinePanelWidth;

  /// [maxContentWidth], or [defaultMaxContentWidth] when it is `null`.
  double get effectiveMaxContentWidth =>
      maxContentWidth ?? defaultMaxContentWidth;

  /// The theme's form theme, or the defaults.
  static XFormTheme of(BuildContext context) =>
      Theme.of(context).extension<XFormTheme>() ?? const XFormTheme();

  /// [pagePadding] widened so that content of at most
  /// [effectiveMaxContentWidth] is centered in [width].
  EdgeInsets pagePaddingFor(double width) {
    final max = effectiveMaxContentWidth;
    if (!max.isFinite || !width.isFinite) return pagePadding;
    final extra = (width - pagePadding.horizontal - max) / 2;
    if (extra <= 0) return pagePadding;
    return pagePadding.copyWith(
      left: pagePadding.left + extra,
      right: pagePadding.right + extra,
    );
  }

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
    double? maxContentWidth,
    bool? adaptiveChoiceColumns,
    double? outlinePanelWidth,
  }) => XFormTheme(
    pagePadding: pagePadding ?? this.pagePadding,
    questionSpacing: questionSpacing ?? this.questionSpacing,
    errorColor: errorColor ?? this.errorColor,
    cardColor: cardColor ?? this.cardColor,
    cardElevation: cardElevation ?? this.cardElevation,
    cardShape: cardShape ?? this.cardShape,
    cardMargin: cardMargin ?? this.cardMargin,
    cardPadding: cardPadding ?? this.cardPadding,
    maxContentWidth: maxContentWidth ?? this.maxContentWidth,
    adaptiveChoiceColumns: adaptiveChoiceColumns ?? this.adaptiveChoiceColumns,
    outlinePanelWidth: outlinePanelWidth ?? this.outlinePanelWidth,
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
      maxContentWidth: lerpDouble(maxContentWidth, other.maxContentWidth, t),
      adaptiveChoiceColumns: t < 0.5
          ? adaptiveChoiceColumns
          : other.adaptiveChoiceColumns,
      outlinePanelWidth: lerpDouble(
        outlinePanelWidth,
        other.outlinePanelWidth,
        t,
      )!,
    );
  }
}

/// A group or repeat-instance card styled by [XFormTheme].
///
/// By default a Material 3 filled card (the color scheme's
/// `surfaceContainerLow`, no elevation) unless the app's `CardTheme` or
/// [XFormTheme] set a color, elevation or shape. A card inside another card is a
/// section instead, marked by a line along its start edge, so nested
/// groups don't lose width to padding on phones.
class XFormCard extends StatelessWidget {
  /// Creates a card around [child].
  const XFormCard({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = XFormTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_CardDepth.nested(context)) {
      return Padding(
        padding: EdgeInsets.only(
          top: theme.cardMargin.top,
          bottom: theme.cardMargin.bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: scheme.outlineVariant, width: 2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: child,
          ),
        ),
      );
    }
    final cardTheme = CardTheme.of(context);
    return Card(
      color: theme.cardColor ?? cardTheme.color ?? scheme.surfaceContainerLow,
      elevation: theme.cardElevation ?? cardTheme.elevation ?? 0,
      shape: theme.cardShape,
      margin: theme.cardMargin,
      child: Padding(
        padding: theme.cardPadding,
        child: _CardDepth(child: child),
      ),
    );
  }
}

/// Marks the content of an [XFormCard].
class _CardDepth extends InheritedWidget {
  const _CardDepth({required super.child});

  static bool nested(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_CardDepth>() != null;

  @override
  bool updateShouldNotify(_CardDepth oldWidget) => false;
}
