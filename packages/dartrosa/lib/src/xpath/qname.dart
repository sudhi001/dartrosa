import 'package:meta/meta.dart';

/// A qualified name such as `jr:choice-name` or `age`.
///
/// Port of `org.javarosa.xpath.expr.XPathQName`.
@immutable
final class XPathQName {
  /// Creates a name; [name] and a non-null [namespace] must be non-empty.
  XPathQName(this.namespace, this.name) {
    if (name.isEmpty || (namespace != null && namespace!.isEmpty)) {
      throw ArgumentError('Invalid QName');
    }
  }

  /// Parses [qname], splitting at the first `:` into [namespace] and [name].
  factory XPathQName.parse(String qname) {
    final separator = qname.indexOf(':');
    return separator == -1
        ? XPathQName(null, qname)
        : XPathQName(
            qname.substring(0, separator),
            qname.substring(separator + 1),
          );
  }

  /// Namespace prefix, or `null` when unqualified.
  final String? namespace;

  /// Local name.
  final String name;

  @override
  String toString() => namespace == null ? name : '$namespace:$name';

  @override
  bool operator ==(Object other) =>
      other is XPathQName && namespace == other.namespace && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);
}
