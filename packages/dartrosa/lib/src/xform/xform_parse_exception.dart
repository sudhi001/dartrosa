import 'kdom.dart';

/// The form can't be parsed.
///
/// Port of `org.javarosa.xform.parse.XFormParseException`: when an
/// [element] is given, the message ends with its location in the
/// document.
final class XFormParseException implements Exception {
  /// Creates the exception, optionally located at [element].
  XFormParseException(this.detail, [this.element]);

  /// The problem.
  final String detail;

  /// Where it was found, if known.
  final KElement? element;

  /// The message, including the location.
  String get message {
    final element = this.element;
    return element == null ? detail : '$detail${vagueLocation(element)}';
  }

  @override
  String toString() => message;
}

/// A description of where [e] is, for messages.
///
/// Port of `XFormParser.getVagueLocation`.
String vagueLocation(KElement e) {
  var path = e.name;
  for (var ancestor = e.parent; ancestor != null; ancestor = ancestor.parent) {
    final step = StringBuffer(ancestor.name);
    for (final a in ancestor.attributes) {
      step.write('[@${a.name}=${a.value}]');
    }
    path = '$step/$path';
  }
  path = '/$path';
  return '\n    Problem found at nodeset: $path'
      '\n    With element ${_vagueElementPrintout(e, 2)}\n';
}

String _vagueElementPrintout(KElement e, int maxDepth) {
  final s = StringBuffer('<${e.name}');
  for (final a in e.attributes) {
    s.write(' ${a.name}="${a.value}"');
  }
  if (e.childCount > 0) {
    s.write('>');
    if (e.isElement(0)) {
      s.write(
        maxDepth > 0
            ? _vagueElementPrintout(e.elementAt(0)!, maxDepth - 1)
            : '...',
      );
    }
  } else {
    s.write('/>');
  }
  return s.toString();
}
