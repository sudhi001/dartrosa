// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Material 3 window size classes, by available width.
///
/// `XFormView` picks its layout from the width it is given (not the
/// device): single column on [compact], a centered column from [medium],
/// and the outline side panel from [expanded].
enum XFormWindowSize {
  /// Narrower than 600dp: phones in portrait.
  compact(0),

  /// 600dp to 839dp: tablets in portrait, foldables, phones in landscape.
  medium(600),

  /// 840dp to 1199dp: tablets in landscape, small desktop windows.
  expanded(840),

  /// 1200dp to 1599dp: desktops.
  large(1200),

  /// 1600dp and wider: large desktop monitors.
  extraLarge(1600);

  const XFormWindowSize(this.minWidth);

  /// The narrowest width of the class, in logical pixels.
  final double minWidth;

  /// The class of a [width] in logical pixels.
  static XFormWindowSize fromWidth(double width) {
    for (final size in values.reversed) {
      if (width >= size.minWidth) return size;
    }
    return compact;
  }

  /// The class of the window [context] is shown in (`MediaQuery` size).
  static XFormWindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Whether this class is at least as wide as [other].
  bool operator >=(XFormWindowSize other) => index >= other.index;

  /// Whether this class is narrower than [other].
  bool operator <(XFormWindowSize other) => index < other.index;
}

/// Whether the app runs on a desktop operating system or in a browser,
/// where people use a mouse and keyboard: scroll bars stay visible, text
/// can be selected with the mouse, the time picker opens in text input
/// mode. Follows `ThemeData.platform`.
bool isDesktopOrWeb(BuildContext context) =>
    kIsWeb ||
    switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
