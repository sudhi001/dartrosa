// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaConstants), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// OpenRosa header names and endpoints.
///
/// Port of Collect's `org.odk.collect.openrosa.http.OpenRosaConstants`.
abstract final class OpenRosaConstants {
  /// The header carrying the OpenRosa version (`1.0`), sent with every
  /// request and expected in every OpenRosa response.
  static const versionHeader = 'X-OpenRosa-Version';

  /// The header in which a submission endpoint advertises the largest
  /// request it accepts.
  static const acceptContentLengthHeader = 'X-OpenRosa-Accept-Content-Length';

  /// The form list endpoint, relative to the server URL.
  static const formList = '/formList';

  /// The submission endpoint, relative to the server URL.
  static const submission = '/submission';
}
