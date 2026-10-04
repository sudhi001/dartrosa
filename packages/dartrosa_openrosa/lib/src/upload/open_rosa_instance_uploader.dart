import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../forms/open_rosa_xml_fetcher.dart';
import '../http/case_insensitive_headers.dart';
import '../http/http_results.dart';
import '../http/open_rosa_constants.dart';
import '../http/open_rosa_http_interface.dart';
import '../http/uri_utils.dart';
import 'form_upload_exception.dart';
import 'instance_upload.dart';
import 'response_message_parser.dart';

final _log = Logger('dartrosa_openrosa');

/// Uploads finalized instances to an OpenRosa server.
///
/// Port of Collect's `OpenRosaServerInstanceUploader`. It HEADs the
/// submission URL first (once per URL: the result, including a same-host
/// redirect, is remembered) to learn the largest request the server
/// accepts (`X-OpenRosa-Accept-Content-Length`, 10 MB by default), then
/// POSTs the instance and its attachments with
/// [OpenRosaHttpInterface.uploadSubmissionAndFiles].
///
/// Collect also marks the instance "submission failed" before trying and
/// "submitted" afterwards, and logs analytics; here the app does that:
/// [uploadOneSubmission] returns when the instance was submitted and
/// throws a [FormUploadException] when it wasn't.
final class OpenRosaInstanceUploader {
  /// Creates an uploader sending through [httpInterface] with the
  /// credentials of [webCredentialsProvider].
  OpenRosaInstanceUploader(this.httpInterface, this.webCredentialsProvider);

  /// The prefix of most error messages.
  static const fail = 'Error: ';

  static const _urlPathSep = '/';

  /// Collect's `url_error` string.
  static const urlError = 'Sorry, invalid URL!';

  /// Collect's `server_auth_credentials` string, for a host.
  static String serverAuthCredentials(String host) =>
      'Invalid username or password for server: $host';

  /// Sends the requests.
  final OpenRosaHttpInterface httpInterface;

  /// Chooses the credentials for each request.
  final WebCredentialsProvider webCredentialsProvider;

  final Map<String, String> _uriRemap = {};

  /// Uploads all the files of [instance] to its submission URL: the
  /// [overrideUrl] if there is one (an upload triggered by another app),
  /// else the form's submission URL, else [serverUrl] +
  /// `/submission`; with [deviceId] as the `deviceID` query parameter.
  ///
  /// Returns the server's custom success message, if it sent one. Throws
  /// a [FormUploadException] on failure, a
  /// [FormUploadAuthRequestedException] if the server asks for
  /// credentials and a [FormUploadInterruptedException] once
  /// [isCancelled] returns `true`.
  Future<String?> uploadOneSubmission(
    InstanceUpload instance, {
    String? deviceId,
    String? overrideUrl,
    String? serverUrl,
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? () => false;
    if (cancelled()) throw const FormUploadInterruptedException();

    final urlString = _getUrlToSubmitTo(
      instance,
      deviceId,
      overrideUrl,
      serverUrl,
    );
    var submissionUri = urlString;

    var contentLength = 10000000;

    // We already issued a head request and got a response, so we know it
    // was an OpenRosa-compliant server. We also know the proper URL to
    // send the submission to and the proper scheme.
    final remapped = _uriRemap[submissionUri];
    if (remapped != null) {
      submissionUri = remapped;
      _log.info('Using Uri remap for submission. Now: $submissionUri');
    } else {
      final host = androidUriHost(submissionUri);
      if (host == null) {
        throw const FormUploadException('$fail Host name may not be null');
      }

      final uri = _createUri(submissionUri);
      if (uri == null) throw const FormUploadException(urlError);

      final HttpHeadResult headResult;
      final CaseInsensitiveHeaders responseHeaders;
      try {
        headResult = await httpInterface.executeHeadRequest(
          uri,
          webCredentialsProvider.getCredentials(uri),
        );
        responseHeaders = headResult.headers;

        if (responseHeaders.containsHeader(
          OpenRosaConstants.acceptContentLengthHeader,
        )) {
          final contentLengthString = responseHeaders.getAnyValue(
            OpenRosaConstants.acceptContentLengthHeader,
          );
          final parsed = _parseJavaLong(contentLengthString);
          if (parsed != null) {
            contentLength = parsed;
          } else {
            _log.severe(
              'Exception thrown parsing contentLength $contentLengthString',
            );
          }
        }
      } on Exception catch (e) {
        throw FormUploadException('$fail${exceptionMessage(e)}');
      }

      switch (headResult.statusCode) {
        case 401:
          throw FormUploadAuthRequestedException(
            serverAuthCredentials(host),
            Uri.parse(submissionUri),
          );
        case 204:
          // Redirect header received
          if (responseHeaders.containsHeader('Location')) {
            try {
              var newUri = _urlDecode(responseHeaders.getAnyValue('Location')!);
              final newHost = androidUriHost(newUri);
              // Allow redirects within same host. This could be
              // redirecting to HTTPS.
              if (newHost != null &&
                  host.toLowerCase() == newHost.toLowerCase()) {
                // Re-add params if server didn't respond with params
                final query = _encodedQuery(submissionUri);
                if (_encodedQuery(newUri) == null && query != null) {
                  newUri = _withQuery(newUri, query);
                }
                _uriRemap[submissionUri] = newUri;
                submissionUri = newUri;
              } else {
                // Don't follow a redirection attempt to a different host.
                // We can't tell if this is a spoof or not.
                throw FormUploadException(
                  '${fail}Unexpected redirection attempt to a different '
                  'host: $newUri',
                );
              }
            } on Exception catch (e) {
              throw FormUploadException('$fail$urlString $e');
            }
          }
        default:
          if (headResult.statusCode >= 200 && headResult.statusCode < 300) {
            throw FormUploadException(
              'Failed to send to $uri. Is this an OpenRosa submission '
              'endpoint? If you have a web proxy you may need to log in to '
              'your network.\n\n'
              'HEAD request result status code: ${headResult.statusCode}',
            );
          }
      }
    }

    // When encrypting submissions, there is a failure window that may mark
    // the submission as complete but leave the file-to-be-uploaded with
    // the name "submission.xml" and the plaintext submission files on
    // disk. In this case, upload the submission.xml and all the files in
    // the directory. This means the plaintext files and the encrypted
    // files will be sent to the server and the server will have to figure
    // out what to do with them.
    UploadFile? find(String name) {
      for (final file in instance.files) {
        if (file.name == name) return file;
      }
      return null;
    }

    final instanceFile = find(instance.instanceFileName);
    var submissionFile = find(_submissionXml);
    if (submissionFile != null) {
      _log.warning(
        'submission.xml will be uploaded instead of '
        '${instance.instanceFileName}',
      );
    } else {
      submissionFile = instanceFile;
    }

    if (submissionFile == null) {
      throw const FormUploadException(
        '${fail}instance XML file does not exist!',
      );
    }

    final files = _getFilesInParentDirectory(instance, submissionFile.name);

    final messageParser = ResponseMessageParser();

    if (cancelled()) throw const FormUploadInterruptedException();

    try {
      final uri =
          _createUri(submissionUri) ??
          (throw const FormUploadException(urlError));
      final postResult = await httpInterface.uploadSubmissionAndFiles(
        submissionFile,
        files,
        uri,
        webCredentialsProvider.getCredentials(uri),
        contentLength,
        isCancelled: cancelled,
      );

      final responseCode = postResult.responseCode;
      messageParser.setMessageResponse(postResult.httpResponse);

      if (responseCode != 201 && responseCode != 202) {
        final FormUploadException exception;
        if (responseCode == 200) {
          exception = const FormUploadException(
            '$fail Error: Network login failure? Again?',
          );
        } else if (responseCode == 401) {
          exception = FormUploadException(
            '$fail${postResult.reasonPhrase} ($responseCode) at $urlString',
          );
        } else if (messageParser.isValid) {
          exception = FormUploadException(
            '$fail${messageParser.messageResponse}',
          );
        } else if (responseCode == 400) {
          _log.warning(
            '$fail${postResult.reasonPhrase} ($responseCode) at $urlString',
          );
          exception = const FormUploadException(
            'Failed to upload. Please make sure the form is configured to '
            'accept submissions on the server',
          );
        } else {
          exception = FormUploadException(
            '$fail${postResult.reasonPhrase} ($responseCode) at $urlString',
          );
        }
        throw exception;
      }
    } on Exception catch (e) {
      if (cancelled()) throw const FormUploadInterruptedException();
      throw FormUploadException(exceptionMessage(e));
    }

    return messageParser.isValid ? messageParser.messageResponse : null;
  }

  static const _submissionXml = 'submission.xml';

  List<UploadFile> _getFilesInParentDirectory(
    InstanceUpload instance,
    String submissionFileName,
  ) => [
    for (final file in instance.files)
      if (!file.name.startsWith('.') && // ignore invisible files
          file.name != instance.instanceFileName && // already added
          file.name != submissionFileName) // already added
        file,
  ];

  /// The URL [instance] should be submitted to, with the device id
  /// appended: the override URL, else the form's submission URL, else
  /// the server's.
  String _getUrlToSubmitTo(
    InstanceUpload instance,
    String? deviceId,
    String? overrideUrl,
    String? serverUrl,
  ) {
    final urlString =
        overrideUrl ??
        instance.submissionUri?.trim() ??
        _getServerSubmissionUrl(serverUrl);
    return appendQueryParameters(urlString, [('deviceID', deviceId)]);
  }

  String _getServerSubmissionUrl(String? serverUrl) {
    if (serverUrl == null) {
      throw StateError('No server URL configured');
    }
    var serverBase = serverUrl;
    if (serverBase.endsWith(_urlPathSep)) {
      serverBase = serverBase.substring(0, serverBase.length - 1);
    }
    return serverBase + OpenRosaConstants.submission;
  }
}

/// The message of [e], as Kotlin's `e.message ?: e.toString()`.
String exceptionMessage(Exception e) => switch (e) {
  FormUploadException(:final message) => message,
  OpenRosaHttpException(:final message?) => message,
  UploadCancelledException(:final message) => message,
  http.ClientException(:final message) => message,
  FormatException(:final message) => message,
  _ => e.toString(),
};

/// Android's `Uri.getHost()` for [url]: `null` if it has no authority.
String? androidUriHost(String url) {
  final match = RegExp(r'^[^:/?#]+://([^/?#]*)').firstMatch(url);
  if (match == null) return null;
  var authority = match.group(1)!;
  final at = authority.lastIndexOf('@');
  if (at != -1) authority = authority.substring(at + 1);
  if (authority.startsWith('[')) {
    final end = authority.indexOf(']');
    return end == -1 ? authority : authority.substring(0, end + 1);
  }
  final colon = authority.lastIndexOf(':');
  return colon == -1 ? authority : authority.substring(0, colon);
}

/// `java.net.URI.create(url)` (`null` where it throws), as a Dart [Uri].
Uri? _createUri(String url) {
  if (!hasValidJavaUriCharacters(url)) return null;
  return Uri.tryParse(url);
}

String? _encodedQuery(String url) {
  final hash = url.indexOf('#');
  final beforeFragment = hash == -1 ? url : url.substring(0, hash);
  final question = beforeFragment.indexOf('?');
  return question == -1 ? null : beforeFragment.substring(question + 1);
}

String _withQuery(String url, String query) {
  final hash = url.indexOf('#');
  return hash == -1
      ? '$url?$query'
      : '${url.substring(0, hash)}?$query${url.substring(hash)}';
}

/// Java's `Long.parseLong`, or `null` where it throws.
int? _parseJavaLong(String? s) {
  if (s == null || !RegExp(r'^[+-]?[0-9]+$').hasMatch(s)) return null;
  return int.tryParse(s);
}

/// `URLDecoder.decode(s, "utf-8")`; throws a [FormatException] for a bad
/// escape.
String _urlDecode(String s) {
  try {
    return Uri.decodeQueryComponent(s);
  } on ArgumentError catch (e) {
    throw FormatException('URLDecoder: ${e.message}');
  }
}
