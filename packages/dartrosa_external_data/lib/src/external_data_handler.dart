// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalDataHandler, ExternalDataHandlerBase),
//  Copyright (C) 2014 University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart';

import 'external_data_manager.dart';

/// A custom XPath function reading external data.
///
/// Port of Collect's `ExternalDataHandler` and `ExternalDataHandlerBase`.
abstract class ExternalDataHandler extends XPathFunctionHandler {
  /// Creates a handler reading through [externalDataManager].
  ExternalDataHandler(this.externalDataManager);

  /// The form's data sets.
  ExternalDataManager externalDataManager;

  @override
  List<List<XPathArgType>> get prototypes => const [];

  @override
  bool get rawArgs => true;

  /// The data set name used in a function: lower-cased, without `.csv`
  /// (SCTO-545).
  static String normalize(String dataSetName) {
    final lower = dataSetName.toLowerCase();
    return lower.endsWith('.csv')
        ? lower.substring(0, lower.lastIndexOf('.csv'))
        : lower;
  }
}
