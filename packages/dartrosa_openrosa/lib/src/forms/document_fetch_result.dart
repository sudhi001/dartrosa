// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (DocumentFetchResult), Copyright (C) 2011 University
//  of Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart';

/// The result of fetching an XML document: either the document (and
/// whether it was an OpenRosa response, and its MD5 hash) or an error
/// message and status code.
///
/// Port of Collect's `org.odk.collect.openrosa.forms.DocumentFetchResult`.
final class DocumentFetchResult {
  /// A fetched document.
  const DocumentFetchResult(
    KElement this.doc, {
    required this.isOpenRosaResponse,
    required this.hash,
  }) : errorMessage = null,
       responseCode = 0;

  /// A failure with [errorMessage] and [responseCode].
  const DocumentFetchResult.error(String this.errorMessage, this.responseCode)
    : doc = null,
      isOpenRosaResponse = false,
      hash = null;

  /// What went wrong, or `null` on success.
  final String? errorMessage;

  /// The status code of a failure, `0` on success.
  final int responseCode;

  /// The document element, on success.
  final KElement? doc;

  /// Whether the response had an `X-OpenRosa-Version` header.
  final bool isOpenRosaResponse;

  /// The MD5 hash of the document.
  final String? hash;
}
