// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'kdom.dart';

/// An output element: kdom's `Element` as JavaRosa builds it (a `null`
/// namespace writes the bare name).
final class KxmlElement {
  /// The local name.
  String? name;

  /// The namespace URI (`null` or empty: none).
  String? namespace;

  /// The attributes as (namespace, name, value).
  final List<(String?, String, String)> attributes = [];

  /// Namespace declarations as (prefix, URI).
  final List<(String, String)> declarations = [];

  /// Child [KxmlElement]s and text [String]s.
  final List<Object> children = [];
}

/// kXML's `KXmlSerializer` writing a kdom document in UTF-8. As in kXML,
/// the empty namespace is bound to the empty prefix.
final class KxmlWriter {
  /// A writer appending to [_out].
  KxmlWriter(this._out);

  final StringBuffer _out;
  final List<Map<String, String>> _scopes = [
    {'': ''},
  ];
  var _auto = 0;

  String? _boundPrefix(String namespace) {
    for (final scope in _scopes.reversed) {
      final prefix = scope[namespace];
      if (prefix != null) return prefix;
    }
    return null;
  }

  String _prefixFor(String namespace, List<(String, String)> declare) {
    final bound = _boundPrefix(namespace);
    if (bound != null) return bound;
    final prefix = 'n${_auto++}';
    _scopes.last[namespace] = prefix;
    declare.add((prefix, namespace));
    return prefix;
  }

  String _qualified(
    String? namespace,
    String name,
    List<(String, String)> declare,
  ) {
    if (namespace == null) return name;
    final prefix = _prefixFor(namespace, declare);
    return prefix.isEmpty ? name : '$prefix:$name';
  }

  /// Writes [node] and its subtree.
  void write(KxmlElement node) {
    final scope = <String, String>{};
    _scopes.add(scope);
    final declare = <(String, String)>[];
    for (final (prefix, uri) in node.declarations) {
      scope[uri] = prefix;
      declare.add((prefix, uri));
    }
    final name = _qualified(node.namespace, node.name ?? '', declare);
    _out.write('<$name');
    for (final (namespace, attrName, value) in node.attributes) {
      final qualified = namespace == null || namespace.isEmpty
          ? attrName
          : _qualified(namespace, attrName, declare);
      final quote = value.contains('"') ? "'" : '"';
      _out.write(' $qualified=$quote');
      kxmlEscape(_out, value, quote, unicode: true);
      _out.write(quote);
    }
    for (final (prefix, uri) in declare) {
      _out.write(prefix.isEmpty ? ' xmlns="' : ' xmlns:$prefix="');
      kxmlEscape(_out, uri, '"', unicode: true);
      _out.write('"');
    }
    if (node.children.isEmpty) {
      _out.write(' />');
    } else {
      _out.write('>');
      for (final child in node.children) {
        switch (child) {
          case final KxmlElement element:
            write(element);
          case final String text:
            kxmlEscape(_out, text, null, unicode: true);
        }
      }
      _out.write('</$name>');
    }
    _scopes.removeLast();
  }
}
