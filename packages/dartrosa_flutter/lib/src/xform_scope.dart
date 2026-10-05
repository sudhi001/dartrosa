// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';

import 'delegates.dart';
import 'xform_controller.dart';

/// Builds a replacement widget for a question node.
typedef QuestionWidgetBuilder =
    Widget Function(BuildContext context, Object node);

/// When guidance hints are shown, like ODK Collect's setting.
enum GuidanceHintMode {
  /// Never.
  no,

  /// Always, under the hint.
  yes,

  /// Behind a "guidance" expander.
  collapsed,
}

/// Gives descendants access to the form's controller, delegates and
/// widget overrides.
class XFormScope extends InheritedNotifier<XFormController> {
  /// Creates a scope.
  const XFormScope({
    required XFormController controller,
    required this.delegates,
    required this.overrides,
    required super.child,
    this.guidanceHints = GuidanceHintMode.yes,
    super.key,
  }) : super(notifier: controller);

  /// When guidance hints are shown.
  final GuidanceHintMode guidanceHints;

  /// Platform features (camera, location, ...).
  final XFormDelegates delegates;

  /// Replacement widgets keyed by `controlType` name, optionally with
  /// `:appearance` (e.g. `selectOne:likert`).
  final Map<String, QuestionWidgetBuilder> overrides;

  /// The controller of the nearest form.
  XFormController get controller => notifier!;

  /// The nearest scope, if any.
  static XFormScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<XFormScope>();

  /// The nearest scope.
  static XFormScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<XFormScope>();
    assert(scope != null, 'No XFormScope above this widget');
    return scope!;
  }
}
