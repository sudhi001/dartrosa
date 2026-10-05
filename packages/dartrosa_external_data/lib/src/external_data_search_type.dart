// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalDataSearchType), Copyright (C) 2014
//  University of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart';

/// How `search()` matches its query value.
///
/// Port of Collect's `ExternalDataSearchType`.
enum ExternalDataSearchType {
  /// The column contains the value.
  contains('contains'),

  /// The column equals the value (SQL `LIKE` without wildcards added).
  matches('matches'),

  /// The column starts with the value.
  starts('startsWith'),

  /// The column ends with the value.
  ends('endsWith');

  const ExternalDataSearchType(this.keyword);

  /// The keyword used in `search()`.
  final String keyword;

  /// The type whose keyword equals [keyword] (trimmed, ignoring case), or
  /// [fallback].
  static ExternalDataSearchType getByKeyword(
    String? keyword,
    ExternalDataSearchType fallback,
  ) {
    if (keyword == null) return fallback;
    final wanted = javaTrim(keyword).toLowerCase();
    for (final type in values) {
      if (javaTrim(type.keyword).toLowerCase() == wanted) return type;
    }
    return fallback;
  }

  /// [times] copies of the `LIKE` pattern for [queriedValue].
  List<String> constructLikeArguments(String queriedValue, int times) =>
      List.filled(times, singleLikeArgument(queriedValue));

  /// The `LIKE` pattern for [queriedValue].
  String singleLikeArgument(String queriedValue) => switch (this) {
    contains => '%$queriedValue%',
    matches => queriedValue,
    starts => '$queriedValue%',
    ends => '%$queriedValue',
  };
}
