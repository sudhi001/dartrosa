import 'dart:typed_data';

/// Reads form resources such as `jr://file/towns.csv`.
///
/// Replaces JavaRosa's global `ReferenceManager`: the app supplies a
/// resolver (file system, assets, network cache, …) when loading a form.
abstract interface class ResourceResolver {
  /// The bytes at [uri]; throws [ResourceNotFoundException] if missing.
  Future<Uint8List> read(String uri);
}

/// The resource at [uri] doesn't exist.
///
/// Port of the `FileNotFoundException` / `InvalidReferenceException` cases
/// JavaRosa treats as "missing file".
final class ResourceNotFoundException implements Exception {
  /// Creates the exception for [uri].
  ResourceNotFoundException(this.uri);

  /// The URI that couldn't be read.
  final String uri;

  @override
  String toString() => 'Resource not found: $uri';
}

/// A [ResourceResolver] backed by an in-memory map of URI → bytes, for tests
/// and for apps that preload form media.
final class MapResourceResolver implements ResourceResolver {
  /// Creates a resolver serving [resources].
  MapResourceResolver(Map<String, Uint8List> resources)
    : _resources = Map.of(resources);

  final Map<String, Uint8List> _resources;

  @override
  Future<Uint8List> read(String uri) async {
    final bytes = _resources[uri];
    if (bytes == null) throw ResourceNotFoundException(uri);
    return bytes;
  }
}
