// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XFormsElement, BindBuilderXFormsElement), Copyright
//  2019 Nafundi; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

/// A piece of an XForm document built in code.
///
/// Port of JavaRosa's `org.javarosa.test.XFormsElement` and its
/// implementations. Build forms with the top-level helpers such as [html],
/// [model], [bind], [input] and [t], then call [asXml].
sealed class XFormsElement {
  const XFormsElement(this.name, this.attributes);

  /// Qualified element name, for example `h:head` or `input`.
  final String name;

  /// Attributes in insertion order.
  final Map<String, String> attributes;

  /// Serializes this element and its descendants as XML.
  String asXml();

  String get _attributesString => attributes.isEmpty
      ? ''
      : ' ${attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ')}';
}

/// An element with child elements.
final class TagXFormsElement extends XFormsElement {
  /// Creates an element called [name] with non-empty [children].
  TagXFormsElement(super.name, super.attributes, this.children)
    : assert(children.isNotEmpty, 'use EmptyXFormsElement for no children');

  /// Child elements, in document order.
  final List<XFormsElement> children;

  @override
  String asXml() {
    final prolog = name == 'h:html' ? '<?xml version="1.0"?>' : '';
    final inner = children.map((c) => c.asXml()).join();
    return '$prolog<$name$_attributesString>$inner</$name>';
  }
}

/// An element whose content is a raw XML string.
final class StringLiteralXFormsElement extends XFormsElement {
  /// Creates an element called [name] containing [innerXml] verbatim.
  const StringLiteralXFormsElement(super.name, super.attributes, this.innerXml);

  /// Content inserted without escaping.
  final String innerXml;

  @override
  String asXml() => '<$name$_attributesString>$innerXml</$name>';
}

/// A self-closing element with no content.
final class EmptyXFormsElement extends XFormsElement {
  /// Creates an empty element called [name].
  const EmptyXFormsElement(super.name, super.attributes);

  @override
  String asXml() => '<$name$_attributesString/>';
}

/// A builder for a `<bind>` element, configured with cascades.
///
/// ```dart
/// final element = bind('/data/age')
///   ..type('int')
///   ..required()
///   ..constraint('. > 0');
/// ```
///
/// Port of `org.javarosa.test.BindBuilderXFormsElement`.
final class BindBuilderXFormsElement extends XFormsElement {
  BindBuilderXFormsElement._(String nodeset)
    : super('bind', <String, String>{'nodeset': nodeset});

  /// The bind's `nodeset` attribute.
  String get nodeset => attributes['nodeset'] ?? '';

  /// Sets the data `type`, for example `int` or `geopoint`.
  void type(String type) => attributes['type'] = type;

  /// Sets the `constraint` expression.
  void constraint(String expression) => attributes['constraint'] = expression;

  /// Sets the `required` expression (default `true()`).
  void required([String expression = 'true()']) =>
      attributes['required'] = expression;

  /// Sets the `relevant` expression.
  void relevant(String expression) => attributes['relevant'] = expression;

  /// Sets the `calculate` expression.
  void calculate(String expression) => attributes['calculate'] = expression;

  /// Sets the `jr:preload` attribute.
  void preload(String expression) => attributes['jr:preload'] = expression;

  /// Sets the `readonly` expression (default `true()`).
  void readonly([String expression = 'true()']) =>
      attributes['readonly'] = expression;

  /// Sets an arbitrary namespaced attribute `namespace:name`.
  void withAttribute(String namespace, String name, String expression) =>
      attributes['$namespace:$name'] = expression;

  @override
  String asXml() => EmptyXFormsElement(name, attributes).asXml();
}

// ---------------------------------------------------------------------------
// Element-spec parsing: `t('input ref="/data/a" appearance="minimal"')`.
// ---------------------------------------------------------------------------

final _spaceOutsideQuotes = RegExp(r' (?=(?:[^"]*"[^"]*")*[^"]*$)');
final _attributeSeparator = RegExp(r'''(?<!\))=("|')''');

/// Splits a spec like `input ref="/data/a"` into its element name.
String _parseName(String spec) =>
    spec.contains(' ') ? spec.split(' ').first : spec;

/// Splits a spec like `input ref="/data/a"` into its attributes.
Map<String, String> _parseAttributes(String spec) {
  final attributes = <String, String>{};
  if (!spec.contains(' ')) return attributes;
  for (final word in spec.split(_spaceOutsideQuotes).skip(1)) {
    final match = _attributeSeparator.firstMatch(word);
    if (match == null) {
      throw ArgumentError.value(spec, 'spec', 'malformed attribute "$word"');
    }
    final value = word.substring(match.end);
    attributes[word.substring(0, match.start)] = value.substring(
      0,
      value.length - 1,
    );
  }
  return attributes;
}

/// Creates an element from [spec] (name plus inline attributes) with
/// optional [children].
XFormsElement t(String spec, [List<XFormsElement> children = const []]) =>
    children.isEmpty
    ? EmptyXFormsElement(_parseName(spec), _parseAttributes(spec))
    : TagXFormsElement(_parseName(spec), _parseAttributes(spec), children);

/// Creates an element from [spec] whose content is [innerXml].
XFormsElement tText(String spec, String innerXml) => StringLiteralXFormsElement(
  _parseName(spec),
  _parseAttributes(spec),
  innerXml,
);

const _standardNamespaces =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa" '
    'xmlns:odk="http://www.opendatakit.org/xforms" '
    'xmlns:orx="http://openrosa.org/xforms"';

/// The `<h:html>` root with the standard ODK namespaces plus any
/// [additionalNamespaces] (prefix → URI).
XFormsElement html(
  XFormsElement head,
  XFormsElement body, {
  Map<String, String> additionalNamespaces = const {},
}) {
  final extra = additionalNamespaces.entries
      .map((e) => ' xmlns:${e.key}="${e.value}"')
      .join();
  return t('h:html $_standardNamespaces$extra', [head, body]);
}

/// The `<h:head>` element.
XFormsElement head(List<XFormsElement> children) =>
    TagXFormsElement('h:head', const {}, children);

/// The `<h:body>` element.
XFormsElement body(List<XFormsElement> children) =>
    TagXFormsElement('h:body', const {}, children);

/// The `<h:title>` element; a random title when [text] is omitted.
XFormsElement title([String? text]) => tText('h:title', text ?? _randomId());

/// The `<model>` element with optional extra [attributes].
XFormsElement model(
  List<XFormsElement> children, {
  Map<String, String> attributes = const {},
}) => TagXFormsElement('model', {...attributes}, children);

/// The primary `<instance>` (no id).
XFormsElement mainInstance(List<XFormsElement> children) =>
    t('instance', children);

/// A `<data>` root element with a random form `id`.
XFormsElement data(List<XFormsElement> children) =>
    t('data id="${_randomId()}"', children);

/// A secondary `<instance id="name">` wrapping its items in `<root>`.
XFormsElement instance(String name, List<XFormsElement> children) =>
    t('instance id="$name"', [t('root', children)]);

/// Starts a `<bind>` for [nodeset]; configure it with cascades.
BindBuilderXFormsElement bind(String nodeset) =>
    BindBuilderXFormsElement._(nodeset);

/// An `<input>` control.
XFormsElement input(String ref, [List<XFormsElement> children = const []]) =>
    t('input ref="$ref"', children);

/// A `<select1>` control.
XFormsElement select1(String ref, [List<XFormsElement> children = const []]) =>
    t('select1 ref="$ref"', children);

/// A `<select1>` whose choices come from an `<itemset>` at [nodeset].
XFormsElement select1Dynamic(
  String ref,
  String nodeset, {
  String valueRef = 'value',
  String labelRef = 'label',
}) => t('select1 ref="$ref"', [
  t('itemset nodeset="$nodeset"', [
    t('value ref="$valueRef"'),
    t('label ref="$labelRef"'),
  ]),
]);

/// A `<group>`. Named `formGroup` so it doesn't clash with
/// `package:test`'s `group`.
XFormsElement formGroup(
  String ref, [
  List<XFormsElement> children = const [],
]) => t('group ref="$ref"', children);

/// A `<repeat>`, optionally with a `jr:count` expression [count].
XFormsElement repeat(
  String nodeset, [
  List<XFormsElement> children = const [],
  String? count,
]) => t(
  count == null
      ? 'repeat nodeset="$nodeset"'
      : 'repeat nodeset="$nodeset" jr:count="$count"',
  children,
);

/// A `<label>` with raw XML content.
XFormsElement label(String innerXml) =>
    StringLiteralXFormsElement('label', const {}, innerXml);

/// A static choice `<item>`.
XFormsElement item(Object value, String label) =>
    t('item', [tText('label', label), tText('value', '$value')]);

/// A `<setvalue>` action; [value] is an XPath expression.
XFormsElement setvalue(String event, String ref, [String? value]) => t(
  value == null
      ? 'setvalue event="$event" ref="$ref"'
      : 'setvalue event="$event" ref="$ref" value="$value"',
);

/// A `<setvalue>` action whose value is the literal [innerXml].
XFormsElement setvalueLiteral(String event, String ref, String innerXml) =>
    tText('setvalue event="$event" ref="$ref"', innerXml);

final _random = Random.secure();

String _randomId() {
  String hex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
}
