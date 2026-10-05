// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/material.dart';

import 'node_widgets.dart';

/// The element of the widget of [node] (keyed by [nodeKey]) under
/// [root], if it is built.
Element? findNodeElement(BuildContext root, FormNode node) {
  final key = nodeKey(node);
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget.key == key) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  root.visitChildElements(visit);
  return found;
}

/// The first focus node that can take keyboard focus inside [element].
FocusNode? firstFocusIn(Element element) {
  for (final node in FocusManager.instance.rootScope.traversalDescendants) {
    final context = node.context;
    if (context == null || node is FocusScopeNode) continue;
    var inside = identical(context, element);
    if (!inside) {
      context.visitAncestorElements((ancestor) {
        inside = identical(ancestor, element);
        return !inside;
      });
    }
    if (inside) return node;
  }
  return null;
}

/// Scrolls the widget of [node] under [root] into view and, if [focus],
/// moves keyboard focus to its first control; whether it is built.
bool revealNode(BuildContext root, FormNode node, {bool focus = true}) {
  final element = findNodeElement(root, node);
  if (element == null) return false;
  Scrollable.ensureVisible(
    element,
    alignment: 0.1,
    duration: const Duration(milliseconds: 200),
  ).ignore();
  if (focus) firstFocusIn(element)?.requestFocus();
  return true;
}

/// Tells the input of a question whether its answer was rejected, so
/// that it can show the error state (e.g. a red outline).
class QuestionErrorScope extends InheritedWidget {
  /// Creates a scope for a question that [hasError] or not.
  const QuestionErrorScope({
    required this.hasError,
    required super.child,
    super.key,
  });

  /// Whether the question's answer was rejected.
  final bool hasError;

  /// Whether the question around [context] has an error.
  static bool hasErrorOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<QuestionErrorScope>()
          ?.hasError ??
      false;

  @override
  bool updateShouldNotify(QuestionErrorScope oldWidget) =>
      hasError != oldWidget.hasError;
}
