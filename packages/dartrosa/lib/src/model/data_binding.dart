// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DataBinding), Copyright (C) 2009 JavaRosa; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'condition/conditions.dart';
import 'data_type.dart';
import 'instance/tree_element.dart';
import 'instance/tree_reference.dart';

/// A parsed `<bind>`. Only used while parsing.
///
/// Port of `org.javarosa.core.model.DataBinding`.
final class DataBinding {
  /// The bind's `id`, if any.
  String? id;

  /// The absolute `nodeset` reference.
  late TreeReference reference;

  /// The `type`.
  DataType dataType = DataType.nullType;

  /// The `relevant` condition, unless it is a constant.
  Triggerable? relevancyCondition;

  /// Constant relevance (`true()`/`false()` or absent).
  bool relevantAbsolute = true;

  /// The `required` condition, unless it is a constant.
  Triggerable? requiredCondition;

  /// Constant requiredness.
  bool requiredAbsolute = false;

  /// The `readonly` condition, unless it is a constant.
  Triggerable? readonlyCondition;

  /// Constant read-only state.
  bool readonlyAbsolute = false;

  /// The `constraint`.
  XPathConditional? constraint;

  /// The `jr:constraintMsg`.
  String? constraintMessage;

  /// The `calculate`.
  Triggerable? calculate;

  /// `jr:preload`
  String? preload;

  /// `jr:preloadParams`
  String? preloadParams;

  /// Bind attributes not handled by the engine, kept verbatim.
  final List<TreeElement> additionalAttributes = [];

  /// Sets, adds or removes an additional attribute.
  void setAdditionalAttribute(String? namespace, String name, String? value) =>
      TreeElement.setAttributeIn(
        null,
        additionalAttributes,
        namespace,
        name,
        value,
      );
}
