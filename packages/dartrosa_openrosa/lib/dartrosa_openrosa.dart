// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect, Copyright University of Washington, Nafundi and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// An OpenRosa server client for DartRosa.
///
/// A port of ODK Collect's `open-rosa` module and its OpenRosa instance
/// uploader, over `package:http` (so it works on the VM and the web):
/// * [OpenRosaClient] fetches the form list, manifests, forms, media files
///   and entity list integrity states;
/// * [OpenRosaInstanceUploader] submits finalized instances
///   (`multipart/form-data` with `xml_submission_file`, split to respect
///   the server's `X-OpenRosa-Accept-Content-Length`);
/// * [HttpClientConnection] implements the HTTP side, with Collect's
///   headers and Digest/Basic authentication;
/// * [InstanceUpload.forForm] turns a `FormSession` submission into an
///   upload, encrypting it when the form asks for it.
///
/// ```dart
/// final connection = HttpClientConnection(
///   client: http.Client(),
///   fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
///   userAgent: 'my-app/1.0',
/// );
/// final credentials = WebCredentialsUtils(
///   InMemoryServerCredentialsSettings(
///     serverUrl: serverUrl,
///     username: 'user',
///     password: 'pass',
///   ),
/// );
/// final client = OpenRosaClient(
///   serverUrl,
///   connection,
///   credentials,
///   deviceId: 'my-app:device-1',
/// );
/// final forms = await client.fetchFormList();
///
/// final uploader = OpenRosaInstanceUploader(connection, credentials);
/// final message = await uploader.uploadOneSubmission(
///   InstanceUpload.forForm(form, submission, attachments: files),
///   serverUrl: serverUrl,
///   deviceId: 'my-app:device-1',
/// );
/// ```
///
/// @docImport 'src/forms/open_rosa_client.dart';
/// @docImport 'src/http/client/http_client_connection.dart';
/// @docImport 'src/upload/instance_upload.dart';
/// @docImport 'src/upload/open_rosa_instance_uploader.dart';
library;

export 'src/forms/document_fetch_result.dart';
export 'src/forms/form_source.dart';
export 'src/forms/models.dart';
export 'src/forms/open_rosa_client.dart';
export 'src/forms/open_rosa_xml_fetcher.dart';
export 'src/http/case_insensitive_headers.dart';
export 'src/http/client/authenticators.dart';
export 'src/http/client/http_client_connection.dart';
export 'src/http/client/multipart.dart';
export 'src/http/client/open_rosa_server_client.dart';
export 'src/http/content_type_mapper.dart';
export 'src/http/http_credentials.dart';
export 'src/http/http_results.dart';
export 'src/http/open_rosa_constants.dart';
export 'src/http/open_rosa_http_interface.dart';
export 'src/http/uri_utils.dart';
export 'src/parse/open_rosa_response_parser.dart';
export 'src/upload/form_upload_exception.dart';
export 'src/upload/instance_upload.dart';
export 'src/upload/open_rosa_instance_uploader.dart';
export 'src/upload/response_message_parser.dart';
export 'src/upload/web_credentials_utils.dart';
