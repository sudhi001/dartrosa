import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A response for [MockWebServer] to send.
final class MockResponse {
  MockResponse({
    this.code = 200,
    String body = '',
    Map<String, String>? headers,
    this.reasonPhrase,
  }) : body = utf8.encode(body),
       headers = headers ?? {};

  final int code;
  final Uint8List body;
  final Map<String, String> headers;
  final String? reasonPhrase;
}

/// A request [MockWebServer] received.
final class RecordedRequest {
  RecordedRequest(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Uint8List body;

  String? header(String name) {
    for (final MapEntry(:key, :value) in headers.entries) {
      if (key.toLowerCase() == name.toLowerCase()) return value;
    }
    return null;
  }

  String get bodyUtf8 => utf8.decode(body);
}

/// Stands in for OkHttp's `MockWebServer`: a `package:http` client that
/// answers with queued responses and records requests.
final class MockWebServer {
  MockWebServer([this.base = 'http://localhost:8080']);

  final String base;
  final List<MockResponse> _queue = [];
  final List<RecordedRequest> _requests = [];
  var _taken = 0;

  void enqueue(MockResponse response) => _queue.add(response);

  int get requestCount => _requests.length;

  RecordedRequest takeRequest() => _requests[_taken++];

  Uri url(String path) => Uri.parse('$base$path');

  late final http.Client client = MockClient.streaming((
    request,
    bodyStream,
  ) async {
    final body = await bodyStream.toBytes();
    _requests.add(
      RecordedRequest(request.method, request.url, request.headers, body),
    );
    if (_queue.isEmpty) {
      throw http.ClientException('Connection refused', request.url);
    }
    final response = _queue.removeAt(0);
    return http.StreamedResponse(
      Stream.value(response.body),
      response.code,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  });
}

/// The parts of a multipart body, each split into lines, as Collect's
/// `splitMultiPart` test helper does.
List<List<String>> splitMultiPart(RecordedRequest request) {
  final body = request.bodyUtf8;
  final boundary = body.split('\r\n')[0];
  final split = body.split(boundary);
  return [
    for (final part in split.sublist(1, split.length - 1)) part.split('\r\n'),
  ];
}
