// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (OpenRosaHttpInterface), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'http_credentials.dart';
import 'http_results.dart';

/// A file to upload: a name, a length and its bytes.
///
/// Stands in for the `java.io.File`s Collect uploads; apps can implement
/// it over files on disk (e.g. `dart:io`'s `File.openRead`) to stream
/// large attachments.
abstract interface class UploadFile {
  /// The file's name (used as the part name and filename).
  String get name;

  /// The file's size in bytes.
  int get length;

  /// Reads the file. Called once per request that includes it (it may be
  /// sent again, e.g. after an authentication challenge).
  Stream<List<int>> openRead();
}

/// An [UploadFile] held in memory.
final class BytesUploadFile implements UploadFile {
  /// Creates a file called [name] with [bytes].
  BytesUploadFile(this.name, this.bytes);

  @override
  final String name;

  /// The file's content.
  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Stream<List<int>> openRead() async* {
    // Chunks the size of Apache Commons IO's default buffer, as Collect
    // reads files.
    const chunk = 8192;
    for (var i = 0; i < bytes.length; i += chunk) {
      yield Uint8List.sublistView(
        bytes,
        i,
        i + chunk > bytes.length ? bytes.length : i + chunk,
      );
    }
  }
}

/// Thrown when an upload is cancelled mid-transfer.
///
/// Stands in for the `InterruptedIOException("Upload canceled")` Collect
/// throws.
final class UploadCancelledException implements Exception {
  /// Creates the exception.
  const UploadCancelledException();

  /// The message.
  String get message => 'Upload canceled';

  @override
  String toString() => 'UploadCancelledException: $message';
}

/// A failure an [OpenRosaHttpInterface] reports.
final class OpenRosaHttpException implements Exception {
  /// Creates the exception.
  const OpenRosaHttpException([this.message]);

  /// What went wrong, if known.
  final String? message;

  @override
  String toString() => message == null
      ? 'OpenRosaHttpException'
      : 'OpenRosaHttpException: $message';
}

/// Thrown by an [OpenRosaHttpInterface] when the host name can't be
/// resolved (Java's `UnknownHostException`); `OpenRosaClient` reports it as
/// unreachable.
final class UnknownHostException implements Exception {
  /// Creates the exception.
  const UnknownHostException([this.message]);

  /// The message, if any.
  final String? message;

  @override
  String toString() => 'UnknownHostException: ${message ?? ''}';
}

/// Thrown by an [OpenRosaHttpInterface] when a secure connection fails
/// (Java's `SSLException`); `OpenRosaClient` reports it as a security
/// error.
final class SslException implements Exception {
  /// Creates the exception.
  const SslException([this.message]);

  /// The message, if any.
  final String? message;

  @override
  String toString() => 'SslException: ${message ?? ''}';
}

/// Maps a file name to the content type to upload it with.
///
/// Port of Collect's `OpenRosaHttpInterface.FileToContentTypeMapper`.
abstract interface class FileToContentTypeMapper {
  /// The content type of [fileName].
  String map(String fileName);
}

/// The HTTP operations of the OpenRosa API.
///
/// Port of Collect's `org.odk.collect.openrosa.http.OpenRosaHttpInterface`.
/// `HttpClientConnection` implements it over `package:http`.
abstract interface class OpenRosaHttpInterface {
  /// GETs [uri]. When [contentType] is given, the response's content type
  /// must contain it; `text/xml` also computes the body's MD5 hash.
  Future<HttpGetResult> executeGetRequest(
    Uri uri,
    String? contentType,
    HttpCredentialsInterface? credentials,
  );

  /// HEADs [uri]: the status code and, for a 204, the headers.
  Future<HttpHeadResult> executeHeadRequest(
    Uri uri,
    HttpCredentialsInterface? credentials,
  );

  /// POSTs [submissionFile] (as `xml_submission_file`) and [fileList] to
  /// [uri] as `multipart/form-data`, splitting the attachments over
  /// several requests to keep each under [contentLength] bytes (or 100
  /// attachments). Returns the last request's result; stops at the first
  /// that isn't a 201 or 202.
  ///
  /// The upload is aborted with an [UploadCancelledException] as soon as
  /// [isCancelled] returns `true`.
  Future<HttpPostResult> uploadSubmissionAndFiles(
    UploadFile submissionFile,
    List<UploadFile> fileList,
    Uri uri,
    HttpCredentialsInterface? credentials,
    int contentLength, {
    bool Function()? isCancelled,
  });
}
