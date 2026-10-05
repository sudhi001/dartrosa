import 'dart:convert';

import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';

/// Port of Collect's `StubWebCredentialsProvider`.
final class StubWebCredentialsProvider implements WebCredentialsProvider {
  @override
  HttpCredentialsInterface getCredentials(Uri url) =>
      const HttpCredentials(null, null);
}

/// A recorded call to [FakeHttpInterface].
typedef GetCall = ({
  Uri uri,
  String? contentType,
  HttpCredentialsInterface? credentials,
});

/// A recorded upload.
typedef UploadCall = ({
  UploadFile submissionFile,
  List<UploadFile> files,
  Uri uri,
  HttpCredentialsInterface? credentials,
  int contentLength,
});

/// A programmable [OpenRosaHttpInterface] (Collect's tests mock it with
/// Mockito).
final class FakeHttpInterface implements OpenRosaHttpInterface {
  Future<HttpGetResult> Function(GetCall call)? onGet;
  Future<HttpHeadResult> Function(Uri uri)? onHead;
  Future<HttpPostResult> Function(UploadCall call)? onUpload;

  final List<GetCall> gets = [];
  final List<Uri> heads = [];
  final List<UploadCall> uploads = [];

  @override
  Future<HttpGetResult> executeGetRequest(
    Uri uri,
    String? contentType,
    HttpCredentialsInterface? credentials,
  ) {
    final call = (uri: uri, contentType: contentType, credentials: credentials);
    gets.add(call);
    return onGet!(call);
  }

  @override
  Future<HttpHeadResult> executeHeadRequest(
    Uri uri,
    HttpCredentialsInterface? credentials,
  ) {
    heads.add(uri);
    return onHead!(uri);
  }

  @override
  Future<HttpPostResult> uploadSubmissionAndFiles(
    UploadFile submissionFile,
    List<UploadFile> fileList,
    Uri uri,
    HttpCredentialsInterface? credentials,
    int contentLength, {
    bool Function()? isCancelled,
  }) {
    final call = (
      submissionFile: submissionFile,
      files: fileList,
      uri: uri,
      credentials: credentials,
      contentLength: contentLength,
    );
    uploads.add(call);
    return onUpload!(call);
  }
}

/// A GET result with [body].
HttpGetResult getResult(
  String? body,
  Map<String, String> headers,
  String hash,
  int statusCode,
) => HttpGetResult(
  body == null ? null : Stream.value(utf8.encode(body)),
  headers,
  hash,
  statusCode,
);

const openRosaHeaders = {OpenRosaConstants.versionHeader: '1.0'};
