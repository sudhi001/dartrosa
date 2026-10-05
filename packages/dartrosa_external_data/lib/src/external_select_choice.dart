// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalSelectChoice), Copyright (C) 2014
//  University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';

/// A choice created by a `search()` appearance from a CSV row, with an
/// optional image.
///
/// Port of Collect's `ExternalSelectChoice`.
final class ExternalSelectChoice extends SelectChoice {
  /// Creates a choice labelled [label] (literal text) with [value].
  ExternalSelectChoice(super.label, super.value)
    : super.fromItem(isLocalizable: false);

  /// The image (`jr://images/<file>`), if the CSV row names one.
  String? image;
}
