// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XmlTextConsolidator, XFormParser, XFormSerializer),
//  Copyright (C) 2009 JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// A small DOM with kXML's `kdom` semantics, which the XForm parser is
/// written against.
///
/// JavaRosa parses forms into a kXML `Document`; several observable
/// behaviours come from it and are reproduced here (each verified against
/// JavaRosa 6.0.0):
/// * text, CDATA and entity references are text; comments and processing
///   instructions are separate nodes whose text is `null` (so a comment
///   inside a label reads as the word `null`, and ends a text run);
/// * an element written `<a></a>` (not `<a/>`) has one empty
///   "ignorable whitespace" child, so its text is `''` rather than `null`;
/// * line endings are normalized to `\n`;
/// * [consolidateText] merges adjacent text and drops whitespace-only runs;
/// * [elementToString] writes exactly what kXML's serializer writes (used
///   for HTML markup inside labels).
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as xmlevents;
import '../util/java_lang.dart';

/// Kinds of non-element child.
enum KNodeType {
  /// Text (including CDATA and resolved entities).
  text,

  /// `<!-- comment -->`
  comment,

  /// `<?target data?>`
  processingInstruction,

  /// The empty content of `<a></a>` (kXML's IGNORABLE_WHITESPACE).
  ignorableWhitespace,
}

/// A non-element child node.
final class KText {
  /// Creates a node of [type] with [content].
  KText(this.type, this.content);

  /// The node kind.
  final KNodeType type;

  /// The raw content.
  final String content;
}

/// An attribute: namespace URI (`''` for none), local name and value.
typedef KAttribute = ({String namespace, String name, String value});

/// An element.
final class KElement {
  /// Creates an element.
  KElement(this.name, this.namespace);

  /// The local name.
  final String name;

  /// The namespace URI (`''` for none).
  final String namespace;

  /// Attributes in document order (namespace declarations excluded).
  final List<KAttribute> attributes = [];

  /// Namespace declarations on this element: prefix (`null` for the
  /// default namespace) and URI.
  final List<(String?, String)> namespaceDeclarations = [];

  /// Children: [KElement]s and [KText]s.
  final List<Object> children = [];

  /// The parent element, if any.
  KElement? parent;

  /// Number of children.
  int get childCount => children.length;

  /// The child element at [i], or `null` if it isn't an element.
  KElement? elementAt(int i) {
    final child = children[i];
    return child is KElement ? child : null;
  }

  /// Whether child [i] is an element.
  bool isElement(int i) => children[i] is KElement;

  /// Whether child [i] is text.
  bool isText(int i) {
    final child = children[i];
    return child is KText && child.type == KNodeType.text;
  }

  /// The text of child [i], or `null` unless it is text or ignorable
  /// whitespace (kdom's `getText`).
  String? textAt(int i) {
    final child = children[i];
    return child is KText &&
            (child.type == KNodeType.text ||
                child.type == KNodeType.ignorableWhitespace)
        ? child.content
        : null;
  }

  /// The value of attribute [name] in [namespace] (any namespace when
  /// `null`), or `null`.
  String? attribute(String? namespace, String name) {
    for (final a in attributes) {
      if (a.name == name && (namespace == null || a.namespace == namespace)) {
        return a.value;
      }
    }
    return null;
  }

  /// Removes child [i].
  void removeChildAt(int i) => children.removeAt(i);

  /// Inserts [child] at [i], adopting elements.
  void insertChild(int i, Object child) {
    if (child is KElement) child.parent = this;
    children.insert(i, child);
  }

  /// Child elements, in order.
  Iterable<KElement> get childElements => children.whereType<KElement>();
}

/// Parses [source] into a document element. Throws [xml.XmlException] for
/// malformed XML.
///
/// Builds the tree from `package:xml`'s events (the parse behind
/// `XmlDocument.parse`, with the namespace resolution of package:xml 7),
/// without building its DOM first.
KElement parseKDocument(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  try {
    return _KDocumentBuilder().build(normalized);
  } on _UseDom {
    return parseKDocumentFromDom(normalized);
  }
}

/// [parseKDocument] through `package:xml`'s DOM (what it did before
/// reading events), for tests comparing the two.
@visibleForTesting
KElement parseKDocumentFromDom(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return _convert(xml.XmlDocument.parse(normalized).rootElement, null);
}

/// Thrown when the events contain what only the DOM rejects (a declaration
/// or doctype inside an element), so the DOM path reports the error.
final class _UseDom implements Exception {
  const _UseDom();
}

/// Builds [KElement]s from XML events exactly as [_convert] does from the
/// DOM of the same document.
final class _KDocumentBuilder {
  static const _xmlUri = 'http://www.w3.org/XML/1998/namespace';
  static const _xmlnsUri = 'http://www.w3.org/2000/xmlns/';

  /// The namespace declarations in scope, per prefix (`null` = default),
  /// innermost last; `null` for an undeclaration (`xmlns:p=""`).
  final Map<String?, List<String?>> _namespaces = {};

  KElement build(String source) {
    KElement? root;
    KElement? current;
    // Whether each open element has had a child node (of any kind).
    final hadChild = <bool>[];
    final declared = <List<String?>>[];

    void end(KElement element, bool selfClosing, bool anyChild) {
      if (!anyChild && !selfClosing) {
        element.children.add(KText(KNodeType.ignorableWhitespace, ''));
      }
    }

    for (final event in xmlevents.parseEvents(
      source,
      validateNesting: true,
      validateDocument: true,
    )) {
      switch (event) {
        case xmlevents.XmlStartElementEvent():
          final prefixes = <String?>[];
          for (final attribute in event.attributes) {
            final (prefix, local) = _split(attribute.name);
            if (attribute.name == 'xmlns') {
              prefixes.add(null);
              (_namespaces[null] ??= []).add(
                attribute.value.isEmpty ? null : attribute.value,
              );
            } else if (prefix == 'xmlns') {
              prefixes.add(local);
              (_namespaces[local] ??= []).add(
                attribute.value.isEmpty ? null : attribute.value,
              );
            }
          }
          final (prefix, local) = _split(event.name);
          final element = KElement(local, _uri(prefix, event.name) ?? '')
            ..parent = current;
          for (final attribute in event.attributes) {
            final (prefix, local) = _split(attribute.name);
            if (prefix == 'xmlns') {
              element.namespaceDeclarations.add((local, attribute.value));
            } else if (prefix == null && local == 'xmlns') {
              element.namespaceDeclarations.add((null, attribute.value));
            } else {
              element.attributes.add((
                namespace: prefix == null
                    ? ''
                    : _uri(prefix, attribute.name) ?? '',
                name: local,
                value: attribute.value,
              ));
            }
          }
          if (current == null) {
            root ??= element;
          } else {
            current.children.add(element);
            hadChild[hadChild.length - 1] = true;
          }
          if (event.isSelfClosing) {
            _undeclare(prefixes);
            end(element, true, false);
          } else {
            current = element;
            hadChild.add(false);
            declared.add(prefixes);
          }
        case xmlevents.XmlEndElementEvent():
          final element = current!;
          _undeclare(declared.removeLast());
          end(element, false, hadChild.removeLast());
          current = element.parent;
        case xmlevents.XmlTextEvent(:final value) ||
            xmlevents.XmlCDATAEvent(:final value):
          if (current != null) {
            _appendText(current, value);
            hadChild[hadChild.length - 1] = true;
          }
        case xmlevents.XmlCommentEvent(:final value):
          if (current != null) {
            current.children.add(KText(KNodeType.comment, value));
            hadChild[hadChild.length - 1] = true;
          }
        case xmlevents.XmlProcessingEvent(:final value):
          if (current != null) {
            current.children.add(KText(KNodeType.processingInstruction, value));
            hadChild[hadChild.length - 1] = true;
          }
        default:
          // A declaration or doctype: fine outside the root element, an
          // error (raised by the DOM) inside it.
          if (current != null) throw const _UseDom();
      }
    }
    return root!;
  }

  void _undeclare(List<String?> prefixes) {
    for (final prefix in prefixes) {
      _namespaces[prefix]!.removeLast();
    }
  }

  /// The namespace URI package:xml gives the name [qualified] with
  /// [prefix], or `null`.
  String? _uri(String? prefix, String qualified) => prefix == 'xml'
      ? _xmlUri
      : prefix == 'xmlns' || qualified == 'xmlns'
      ? _xmlnsUri
      : _namespaces[prefix]?.lastOrNull;

  /// The prefix and local part of [name], as package:xml splits it.
  static (String?, String) _split(String name) {
    final colon = name.indexOf(':');
    return colon > 0
        ? (name.substring(0, colon), name.substring(colon + 1))
        : (null, name);
  }
}

KElement _convert(xml.XmlElement node, KElement? parent) {
  final element = KElement(node.name.local, node.name.namespaceUri ?? '')
    ..parent = parent;
  for (final attribute in node.attributes) {
    final name = attribute.name;
    if (name.prefix == 'xmlns') {
      element.namespaceDeclarations.add((name.local, attribute.value));
    } else if (name.prefix == null && name.local == 'xmlns') {
      element.namespaceDeclarations.add((null, attribute.value));
    } else {
      element.attributes.add((
        namespace: name.prefix == null ? '' : name.namespaceUri ?? '',
        name: name.local,
        value: attribute.value,
      ));
    }
  }
  for (final child in node.children) {
    switch (child) {
      case xml.XmlElement():
        element.children.add(_convert(child, element));
      case xml.XmlText() || xml.XmlCDATA():
        _appendText(element, child.value!);
      case xml.XmlComment():
        element.children.add(KText(KNodeType.comment, child.value));
      case xml.XmlProcessing():
        element.children.add(
          KText(KNodeType.processingInstruction, child.value),
        );
      default:
        break;
    }
  }
  if (node.children.isEmpty && !node.isSelfClosing) {
    element.children.add(KText(KNodeType.ignorableWhitespace, ''));
  }
  return element;
}

void _appendText(KElement element, String text) {
  final last = element.children.isEmpty ? null : element.children.last;
  if (last is KText && last.type == KNodeType.text) {
    element.children[element.children.length - 1] = KText(
      KNodeType.text,
      last.content + text,
    );
  } else {
    element.children.add(KText(KNodeType.text, text));
  }
}

/// Parses [source] and consolidates its text, as JavaRosa's
/// `XFormParser.getXMLDocument` does: the document element of the result.
/// Throws [xml.XmlException] for malformed XML.
KElement getXmlDocument(String source) {
  final root = parseKDocument(source);
  consolidateText(root);
  return root;
}

/// Merges adjacent text children and removes whitespace-only text, in the
/// whole tree. Port of `XmlTextConsolidator.consolidateText`.
void consolidateText(KElement root) {
  final stack = [root];
  while (stack.isNotEmpty) {
    final e = stack.removeLast();
    final kept = <Object>[];
    var accumulator = '';
    for (final child in e.children) {
      if (child is KText && child.type == KNodeType.text) {
        accumulator += child.content;
        continue;
      }
      if (child is KElement) stack.add(child);
      if (javaTrim(accumulator).isNotEmpty) {
        kept.add(KText(KNodeType.text, accumulator));
      }
      accumulator = '';
      kept.add(child);
    }
    if (javaTrim(accumulator).isNotEmpty) {
      kept.add(KText(KNodeType.text, accumulator));
    }
    e.children
      ..clear()
      ..addAll(kept);
  }
}

/// The text of [node]'s first child and the text children right after it,
/// optionally trimmed; `null` without children or when the first child
/// isn't text. Port of `XFormParser.getXMLText`.
String? xmlText(KElement node, {required bool trim, int from = 0}) {
  if (node.childCount == 0) return null;
  var text = node.textAt(from);
  if (text == null) return null;
  for (var i = from + 1; i < node.childCount && node.isText(i); i++) {
    text = text! + node.textAt(i)!;
  }
  return trim ? javaTrim(text!) : text;
}

/// Serializes [element] as kXML's `KXmlSerializer` does with no output
/// encoding (port of `XFormSerializer.elementToString`):
/// * namespaced names get generated prefixes `n0`, `n1`, … declared after
///   the attributes;
/// * `&`, `<`, `>` are escaped, as are `@`, characters from 127 up and
///   control characters (as `&#N;` per UTF-16 unit); in attributes also
///   newlines and tabs;
/// * attribute values use `"` unless they contain `"`, then `'`;
/// * empty elements end with ` />`.
String elementToString(KElement element) {
  final out = StringBuffer();
  _KXmlSerializer(out).write(element);
  return out.toString();
}

final class _KXmlSerializer {
  _KXmlSerializer(this._out);

  final StringBuffer _out;
  final List<Map<String, String>> _scopes = [{}];
  var _auto = 0;

  String _prefixFor(String namespace, Map<String, String> declare) {
    for (final scope in _scopes.reversed) {
      final prefix = scope[namespace];
      if (prefix != null) return prefix;
    }
    final prefix = 'n${_auto++}';
    _scopes.last[namespace] = prefix;
    declare[namespace] = prefix;
    return prefix;
  }

  void write(KElement element) {
    _scopes.add({});
    final declare = <String, String>{};
    final name = element.namespace.isEmpty
        ? element.name
        : '${_prefixFor(element.namespace, declare)}:${element.name}';
    _out.write('<$name');
    for (final a in element.attributes) {
      final attributeName = a.namespace.isEmpty
          ? a.name
          : '${_prefixFor(a.namespace, declare)}:${a.name}';
      final quote = a.value.contains('"') ? "'" : '"';
      _out.write(' $attributeName=$quote');
      _escape(a.value, quote);
      _out.write(quote);
    }
    declare.forEach((namespace, prefix) {
      _out.write(' xmlns:$prefix="');
      _escape(namespace, '"');
      _out.write('"');
    });
    if (element.children.isEmpty) {
      _out.write(' />');
    } else {
      _out.write('>');
      for (final child in element.children) {
        switch (child) {
          case KElement():
            write(child);
          case KText(type: KNodeType.text, :final content):
            _escape(content, null);
          case KText(type: KNodeType.comment, :final content):
            _out.write('<!--$content-->');
          case KText(type: KNodeType.ignorableWhitespace, :final content):
            _out.write(content);
          case KText(:final content):
            _out.write('<?$content?>');
        }
      }
      _out.write('</$name>');
    }
    _scopes.removeLast();
  }

  void _escape(String s, String? quote) =>
      kxmlEscape(_out, s, quote, unicode: false);
}

/// Writes [s] escaped as kXML's `KXmlSerializer.writeEscaped` does: in
/// attribute values ([quote] given) tabs and line breaks become numeric
/// references and the quote is escaped; `&`, `<`, `>` always are; `@`,
/// control characters and (unless [unicode], i.e. a UTF output encoding)
/// characters from 127 up become `&#N;` per UTF-16 unit.
void kxmlEscape(
  StringSink out,
  String s,
  String? quote, {
  required bool unicode,
}) {
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x0A || 0x0D || 0x09:
        if (quote == null) {
          out.writeCharCode(c);
        } else {
          out.write('&#$c;');
        }
      case 0x26:
        out.write('&amp;');
      case 0x3E:
        out.write('&gt;');
      case 0x3C:
        out.write('&lt;');
      default:
        if (quote != null && c == quote.codeUnitAt(0)) {
          out.write(c == 0x22 ? '&quot;' : '&apos;');
        } else if (c >= 0x20 && c != 0x40 && (c < 127 || unicode)) {
          out.writeCharCode(c);
        } else {
          out.write('&#$c;');
        }
    }
  }
}
