import 'dart:io';
import 'dart:typed_data';

/// The JavaRosa test resource called [name], found anywhere under
/// `conformance/forms/javarosa` (like JavaRosa's `ResourcePathHelper.r`).
/// Works whether tests run from the repository root or the package.
File javarosaResource(String name) {
  for (var dir = Directory.current; ; dir = dir.parent) {
    final resources = Directory('${dir.path}/conformance/forms/javarosa');
    if (resources.existsSync()) {
      return resources
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere(
            (f) => f.uri.pathSegments.last == name,
            orElse: () => throw StateError('test resource $name not found'),
          );
    }
    if (dir.parent.path == dir.path) {
      throw StateError('conformance/ not found above ${Directory.current}');
    }
  }
}

/// The bytes of the JavaRosa test resource [name].
Uint8List resourceBytes(String name) =>
    javarosaResource(name).readAsBytesSync();
