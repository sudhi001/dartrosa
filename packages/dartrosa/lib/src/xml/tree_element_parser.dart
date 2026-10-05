// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ElementParser, TreeElementParser,
//  InternalDataInstanceParser), Copyright (C) 2009 JavaRosa and contributors;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// XML → [TreeElement] parsing for instances.
///
/// Port of `org.javarosa.xml.ElementParser`, `TreeElementParser` and
/// `InternalDataInstanceParser`. JavaRosa reads XML with kXML's pull
/// parser; this port walks a `package:xml` DOM but reproduces kXML's event
/// semantics: adjacent text, CDATA and entity references (with comments and
/// processing instructions in between) form one text event, whitespace-only
/// text is skipped, and other text becomes the element's value, trimmed.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../model/data/answer_value.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../util/java_lang.dart';

const _xmlNamespace = 'http://www.w3.org/XML/1998/namespace';

/// Decodes [bytes] as UTF-8 (as kXML is told to), dropping a byte-order
/// mark.
String decodeXmlBytes(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  // Dart's UTF-8 decoder drops a leading byte-order mark itself.
  final text = utf8.decode(bytes, allowMalformed: true);
  if (hasBom && text.startsWith('<?xml')) {
    throw const FormatException('PI must not start with xml');
  }
  return text;
}

/// Parses the document element of [xml] into a [TreeElement] with
/// [multiplicity], whose nodes all get [instanceId] as instance name.
///
/// Port of `new TreeElementParser(parser, multiplicity, instanceId).parse()`
/// on a freshly instantiated parser.
///
/// Reads `package:xml`'s events rather than a DOM (the same parse that
/// `XmlDocument.parse` does, so malformed XML fails the same way, before
/// anything is built), which halves the cost for large external
/// instances.
TreeElement parseTreeElement(
  String xml, {
  int multiplicity = 0,
  String? instanceId,
}) {
  final events = parseEvents(
    xml,
    validateNesting: true,
    validateDocument: true,
  ).toList(growable: false);
  final builder = _EventTreeBuilder(events, instanceId);
  while (events[builder._next] is! XmlStartElementEvent) {
    builder._next++;
  }
  return builder.element(multiplicity);
}

/// Builds [TreeElement]s from the events of a whole document exactly as
/// [_parseElement] does from its DOM.
final class _EventTreeBuilder {
  _EventTreeBuilder(this._events, this._instanceId);

  final List<XmlEvent> _events;
  final String? _instanceId;

  /// The attributes of the open elements, innermost last.
  final List<List<XmlEventAttribute>> _open = [];

  /// The index of the next event to read.
  int _next = 0;

  /// The element starting at the next event, which is a start tag.
  TreeElement element(int multiplicity) {
    final start = _events[_next++] as XmlStartElementEvent;
    _open.add(start.attributes);
    final (prefix, local) = _split(start.name);
    _namespaceOf(prefix);
    final element = TreeElement(local, multiplicity)
      ..instanceName = _instanceId;
    for (final attribute in start.attributes) {
      final (prefix, local) = _split(attribute.name);
      if (prefix == 'xmlns' || (prefix == null && local == 'xmlns')) {
        continue; // namespace declarations aren't attributes in kXML
      }
      element.setAttribute(
        prefix == null ? '' : _namespaceOf(prefix),
        local,
        attribute.value,
      );
    }
    if (!start.isSelfClosing) {
      final multiplicities = <String, int>{};
      final text = StringBuffer();
      var hasText = false;

      void flushText() {
        if (hasText) {
          final value = text.toString();
          if (!_isWhitespace(value)) {
            element.value = UncastValue(javaTrim(value));
          }
        }
        text.clear();
        hasText = false;
      }

      for (;;) {
        switch (_events[_next]) {
          case XmlEndElementEvent():
            _next++;
            flushText();
            _open.removeLast();
            return element;
          case XmlStartElementEvent(:final name):
            flushText();
            final (_, local) = _split(name);
            final childMultiplicity = (multiplicities[local] ?? -1) + 1;
            multiplicities[local] = childMultiplicity;
            element.addChild(this.element(childMultiplicity));
          case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
            _next++;
            text.write(value);
            hasText = true;
          default:
            // Comments and processing instructions are skipped; text on
            // either side of them is one event in kXML.
            _next++;
        }
      }
    }
    _open.removeLast();
    return element;
  }

  /// [_namespaceOf] for the innermost open element.
  String _namespaceOf(String? prefix) {
    if (prefix == null) return '';
    if (prefix == 'xml') return _xmlNamespace;
    final declaration = 'xmlns:$prefix';
    for (var i = _open.length - 1; i >= 0; i--) {
      for (final attribute in _open[i]) {
        if (attribute.name == declaration) return attribute.value;
      }
    }
    throw FormatException('undefined prefix: $prefix');
  }

  /// The prefix and local part of the qualified [name], as `XmlName`
  /// splits it.
  static (String?, String) _split(String name) {
    final colon = name.indexOf(':');
    return colon > 0
        ? (name.substring(0, colon), name.substring(colon + 1))
        : (null, name);
  }
}

/// Parses [element] (and its subtree) into a [TreeElement].
///
/// Port of `TreeElementParser.parse`: children get multiplicities counted
/// per local name, attributes keep their namespace URI (`''` when none),
/// and text values are stored as trimmed [UncastValue]s. As in JavaRosa,
/// text mixed with child elements fails: a value can't be set on an
/// element that has children, nor a child added to one that has a value.
TreeElement parseTreeElementFrom(
  XmlElement element, {
  int multiplicity = 0,
  String? instanceId,
}) => _parseElement(element, multiplicity, instanceId);

TreeElement _parseElement(
  XmlElement xml,
  int multiplicity,
  String? instanceId,
) {
  _namespaceOf(xml, xml.name.prefix);
  final element = TreeElement(xml.name.local, multiplicity)
    ..instanceName = instanceId;
  for (final attribute in xml.attributes) {
    final prefix = attribute.name.prefix;
    if (prefix == 'xmlns' ||
        (prefix == null && attribute.name.local == 'xmlns')) {
      continue; // namespace declarations aren't attributes in kXML
    }
    element.setAttribute(
      prefix == null ? '' : _namespaceOf(xml, prefix),
      attribute.name.local,
      attribute.value,
    );
  }

  final multiplicities = <String, int>{};
  final text = StringBuffer();
  var hasText = false;

  void flushText() {
    if (hasText) {
      final value = text.toString();
      if (!_isWhitespace(value)) element.value = UncastValue(javaTrim(value));
    }
    text.clear();
    hasText = false;
  }

  for (final child in xml.children) {
    switch (child) {
      case XmlText() || XmlCDATA():
        text.write(child.value);
        hasText = true;
      case XmlElement():
        flushText();
        final name = child.name.local;
        final childMultiplicity = (multiplicities[name] ?? -1) + 1;
        multiplicities[name] = childMultiplicity;
        element.addChild(_parseElement(child, childMultiplicity, instanceId));
      default:
        // Comments and processing instructions are skipped; text on either
        // side of them is one event in kXML.
        break;
    }
  }
  flushText();
  return element;
}

/// The namespace URI bound to [prefix] at [element] (`''` for no prefix).
/// Throws like kXML for an undeclared prefix.
String _namespaceOf(XmlElement element, String? prefix) {
  if (prefix == null) return '';
  if (prefix == 'xml') return _xmlNamespace;
  for (XmlNode? node = element; node is XmlElement; node = node.parent) {
    final declaration = node.getAttribute('xmlns:$prefix');
    if (declaration != null) return declaration;
  }
  throw FormatException('undefined prefix: $prefix');
}

/// kXML's notion of whitespace: every character `<= ' '`.
bool _isWhitespace(String s) => s.codeUnits.every((c) => c <= 0x20);

/// The internal secondary instances of the XForm [xml]: every `<instance>`
/// element without a `src` attribute, except the first one (the primary
/// instance), in document order.
///
/// Each result is the `<instance>` element itself; its instance name is its
/// `id` attribute when present. Port of
/// `TreeElementParser.parseInternalSecondaryInstances`, including its
/// traversal: the primary instance's content is walked (an `<instance>`
/// nested in it would count), a secondary instance's content isn't.
List<TreeElement> parseInternalSecondaryInstances(String xml) {
  final document = XmlDocument.parse(xml);
  final instances = <TreeElement>[];
  var primarySkipped = false;

  void visit(XmlElement element) {
    for (final child in element.childElements) {
      final isInstance =
          child.name.local == 'instance' &&
          !child.attributes.any((a) => a.name.local == 'src');
      if (isInstance && primarySkipped) {
        final instance = _parseElement(child, 0, '');
        final id = instance.getAttributeValue(null, 'id');
        if (id != null) instance.instanceName = id;
        instances.add(instance);
        continue; // the parser resumes after the instance's end tag
      }
      if (isInstance) primarySkipped = true;
      visit(child);
    }
  }

  visit(document.rootElement);
  return instances;
}

/// The internal secondary instances of the XForm [xml] as [FormInstance]s
/// keyed by id.
///
/// Port of `InternalDataInstanceParser.buildInstances`. As in JavaRosa an
/// instance without an `id`, or without content, fails.
Map<String, DataInstance> buildInternalInstances(String xml) {
  final instances = <String, DataInstance>{};
  for (final element in parseInternalSecondaryInstances(xml)) {
    final idAttribute = element.getAttribute(null, 'id');
    if (idAttribute == null) {
      throw StateError('internal secondary instance without an id');
    }
    final id = idAttribute.attributeValue!;
    final instance = FormInstance(element.childAt(0), id);
    instances[instance.instanceId!] = instance;
  }
  return instances;
}
