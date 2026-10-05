// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (FormUploadException,
//  FormUploadAuthRequestedException, FormUploadInterruptedException), Copyright
//  (C) 2018 Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// A problem submitting a finalized form.
///
/// Throwing one makes the submission attempt move on to the next
/// finalized form, except for a [FormUploadAuthRequestedException] when
/// the attempt was triggered by the user: that form is retried once the
/// user provides credentials.
///
/// Port of Collect's `FormUploadException`.
class FormUploadException implements Exception {
  /// Creates the exception.
  const FormUploadException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'FormUploadException: $message';
}

/// The server the upload was sent to asked for authentication.
///
/// Port of Collect's `FormUploadAuthRequestedException`.
final class FormUploadAuthRequestedException extends FormUploadException {
  /// Creates the exception.
  const FormUploadAuthRequestedException(
    super.message,
    this.authRequestingServer,
  );

  /// The server that asked for authentication, which may not be the
  /// configured one if there was a redirect.
  final Uri authRequestingServer;

  @override
  String toString() => 'FormUploadAuthRequestedException: $message';
}

/// The upload was cancelled. Not an error to report to the user.
///
/// Port of Collect's `FormUploadInterruptedException`.
final class FormUploadInterruptedException extends FormUploadException {
  /// Creates the exception.
  const FormUploadInterruptedException() : super('Upload interrupted');

  @override
  String toString() => 'FormUploadInterruptedException: $message';
}
