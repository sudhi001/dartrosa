/// Response headers, looked up regardless of case.
///
/// Port of Collect's `org.odk.collect.openrosa.http.CaseInsensitiveHeaders`.
abstract interface class CaseInsensitiveHeaders {
  /// The header names.
  Set<String>? get headers;

  /// Whether there is a header called [header] (in any case).
  bool containsHeader(String? header);

  /// One of the values of [header], or `null`.
  String? getAnyValue(String header);

  /// All the values of [header], or `null`.
  List<String>? getValues(String header);
}

/// No headers.
///
/// Port of Collect's `CaseInsensitiveEmptyHeaders`.
final class CaseInsensitiveEmptyHeaders implements CaseInsensitiveHeaders {
  /// Creates the empty headers.
  const CaseInsensitiveEmptyHeaders();

  @override
  Set<String> get headers => <String>{};

  @override
  bool containsHeader(String? header) => false;

  @override
  String? getAnyValue(String header) => null;

  @override
  List<String>? getValues(String header) => null;
}

/// Headers from a list of `(name, value)` pairs, which may repeat names.
///
/// Port of Collect's `OkHttpCaseInsensitiveHeaders` (over OkHttp's
/// `Headers`).
final class ListCaseInsensitiveHeaders implements CaseInsensitiveHeaders {
  /// Creates headers from [entries].
  ListCaseInsensitiveHeaders(Iterable<(String, String)> entries)
    : _entries = List.unmodifiable(entries);

  /// Creates headers from a `package:http` response header map.
  factory ListCaseInsensitiveHeaders.fromMap(Map<String, String> headers) =>
      ListCaseInsensitiveHeaders([
        for (final MapEntry(:key, :value) in headers.entries) (key, value),
      ]);

  final List<(String, String)> _entries;

  @override
  Set<String> get headers {
    // OkHttp's Headers.names(): a case-insensitive sorted set.
    final names = <String>{};
    for (final (name, _) in _entries) {
      if (!names.any((n) => n.toLowerCase() == name.toLowerCase())) {
        names.add(name);
      }
    }
    return names;
  }

  @override
  bool containsHeader(String? header) =>
      header != null && getAnyValue(header) != null;

  @override
  String? getAnyValue(String header) {
    // OkHttp's Headers.get returns the last value.
    final values = getValues(header);
    return values.isEmpty ? null : values.last;
  }

  @override
  List<String> getValues(String header) {
    final lowerHeader = header.toLowerCase();
    return [
      for (final (name, value) in _entries)
        if (name.toLowerCase() == lowerHeader) value,
    ];
  }
}
