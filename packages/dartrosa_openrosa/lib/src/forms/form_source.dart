// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (FormSourceException, FormSource, EntitySource),
//  Copyright University of Washington, Nafundi and contributors; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'models.dart';

/// Why fetching from a [FormSource] or [EntitySource] failed.
///
/// Port of Collect's `org.odk.collect.forms.FormSourceException`.
sealed class FormSourceException implements Exception {
  const FormSourceException();
}

/// The server couldn't be reached (unknown host, or a 404 for the form
/// list).
final class FormSourceUnreachable extends FormSourceException {
  /// Creates the exception.
  const FormSourceUnreachable(this.serverUrl);

  /// The configured server URL.
  final String serverUrl;

  @override
  String toString() => 'FormSourceUnreachable($serverUrl)';
}

/// The server asked for credentials (a 401).
final class FormSourceAuthRequired extends FormSourceException {
  /// Creates the exception.
  const FormSourceAuthRequired();

  @override
  String toString() => 'FormSourceAuthRequired';
}

/// The request failed for another reason (a timeout, a malformed URL or
/// response...).
final class FormSourceFetchError extends FormSourceException {
  /// Creates the exception.
  const FormSourceFetchError();

  @override
  String toString() => 'FormSourceFetchError';
}

/// The secure connection to the server failed.
final class FormSourceSecurityError extends FormSourceException {
  /// Creates the exception.
  const FormSourceSecurityError(this.serverUrl);

  /// The configured server URL.
  final String serverUrl;

  @override
  String toString() => 'FormSourceSecurityError($serverUrl)';
}

/// The server answered with an unexpected status code.
final class FormSourceServerError extends FormSourceException {
  /// Creates the exception.
  const FormSourceServerError(this.statusCode, this.serverUrl);

  /// The HTTP status code.
  final int statusCode;

  /// The configured server URL.
  final String serverUrl;

  @override
  String toString() => 'FormSourceServerError($statusCode, $serverUrl)';
}

/// The server's response couldn't be parsed.
final class FormSourceParseError extends FormSourceException {
  /// Creates the exception.
  const FormSourceParseError(this.serverUrl);

  /// The configured server URL.
  final String serverUrl;

  @override
  String toString() => 'FormSourceParseError($serverUrl)';
}

/// The form list response wasn't an OpenRosa response (no
/// `X-OpenRosa-Version` header).
///
/// Aggregate 0.9 and prior used a custom API before the OpenRosa standard
/// was in place. Aggregate continued to provide this response to HTTP
/// requests so some custom servers tried to implement it.
final class FormSourceServerNotOpenRosaError extends FormSourceException {
  /// Creates the exception.
  const FormSourceServerNotOpenRosaError();

  @override
  String toString() => 'FormSourceServerNotOpenRosaError';
}

/// A place where forms live (outside the app's storage).
///
/// Port of Collect's `org.odk.collect.forms.FormSource`. Methods throw a
/// [FormSourceException] on failure.
abstract interface class FormSource {
  /// The forms the source offers.
  Future<List<FormListItem>> fetchFormList();

  /// The manifest at [manifestUrl], or `null` if [manifestUrl] is `null`.
  Future<ManifestFile?> fetchManifest(String? manifestUrl);

  /// The form definition at [formUrl], as a byte stream.
  Future<Stream<List<int>>> fetchForm(String formUrl);

  /// The media file at [mediaFileUrl], as a byte stream.
  Future<Stream<List<int>>> fetchMediaFile(String mediaFileUrl);
}

/// A source of entity list state.
///
/// Port of Collect's `org.odk.collect.entities.server.EntitySource`.
abstract interface class EntitySource {
  /// Whether each of the entities [ids] was deleted, from the integrity
  /// endpoint [integrityUrl]: `(id, deleted)` pairs. Throws a
  /// [FormSourceException] on failure.
  Future<List<(String, bool)>> fetchDeletedStates(
    String integrityUrl,
    List<String> ids,
  );
}
