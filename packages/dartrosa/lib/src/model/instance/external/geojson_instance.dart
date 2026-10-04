/// GeoJSON secondary instances (`….geojson`).
///
/// Port of `GeoJsonExternalInstance`, `GeojsonFeature` and
/// `GeojsonGeometry`. JavaRosa reads GeoJSON with Jackson; this port uses a
/// small strict JSON reader that keeps the raw text of numbers, because
/// Jackson turns a number into a `String` property or id using its original
/// text (`77`, `1.50`), while coordinates are parsed numbers printed by
/// Java (`102`, `0.5`, `1.0E-7`).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../util/java_double.dart';
import '../../data/answer_value.dart';
import '../tree_element.dart';
import 'external_instance_parser.dart';
import 'instance_format_exception.dart';

/// Name of the child holding a feature's geometry.
const geometryChildName = 'geometry';

/// Parses GeoJSON `FeatureCollection`s into `root/item` instances.
///
/// Each feature becomes an `item` with a `geometry` child (ODK geo
/// string), one child per property, and an `id` child for the feature's
/// top-level `id` (which overrides an `id` property).
final class GeoJsonExternalInstance implements FileInstanceParser {
  /// Creates the parser.
  const GeoJsonExternalInstance();

  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      instanceSrc.endsWith('geojson');

  @override
  TreeElement parse(
    String instanceId,
    Uint8List bytes, {
    bool partial = false,
  }) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    return parseGeoJsonInstance(instanceId, text);
  }
}

/// Parses GeoJSON [text] into an instance named [instanceId].
///
/// Like JavaRosa, reading stops as soon as both the `type` and the
/// `features` of the top-level object have been seen.
TreeElement parseGeoJsonInstance(String instanceId, String text) {
  final root = TreeElement('root', 0)..instanceName = instanceId;
  final reader = _JsonReader(text);
  if (!reader.startsObject()) {
    throw const InstanceFormatException(
      'GeoJSON file must contain a top-level Object',
    );
  }
  var typeValidated = false;
  var featuresIdentified = false;
  reader.expect(0x7B); // {
  if (!reader.tryConsume(0x7D)) {
    while (!(typeValidated && featuresIdentified)) {
      final name = reader.readString();
      reader.expect(0x3A); // :
      if (name == 'type' && reader.peekIsString()) {
        if (reader.readString() == 'FeatureCollection') typeValidated = true;
      } else if (name == 'features' && reader.peekIsArray()) {
        reader.expect(0x5B); // [
        var multiplicity = 0;
        if (!reader.tryConsume(0x5D)) {
          while (true) {
            final feature = GeojsonFeature.fromJson(reader.readValue());
            root.addChild(feature.toTreeElement(multiplicity++));
            if (reader.tryConsume(0x5D)) break;
            reader.expect(0x2C); // ,
          }
        }
        featuresIdentified = true;
      } else {
        reader.readValue();
      }
      if (typeValidated && featuresIdentified) break;
      if (reader.tryConsume(0x7D)) break;
      reader.expect(0x2C);
    }
  }
  if (!typeValidated) {
    throw const InstanceFormatException(
      'GeoJSON file must contain a top-level FeatureCollection',
    );
  }
  if (!featuresIdentified) {
    throw const InstanceFormatException(
      'GeoJSON FeatureCollection must contain an array of features',
    );
  }
  return root;
}

/// One GeoJSON feature. Port of `GeojsonFeature` (unknown fields ignored).
final class GeojsonFeature {
  /// Creates a feature.
  const GeojsonFeature({this.type, this.geometry, this.properties, this.id});

  /// Reads a feature from a parsed JSON value, coercing scalars to strings
  /// as Jackson does.
  factory GeojsonFeature.fromJson(Object? json) {
    if (json == null) {
      throw StateError('null feature'); // a NullPointerException in Java
    }
    if (json is! Map<String, Object?>) {
      throw InstanceFormatException(
        'Cannot deserialize value of type `GeojsonFeature` from '
        '${_jsonKind(json)} value',
      );
    }
    Map<String, String?>? properties;
    final rawProperties = json['properties'];
    if (rawProperties is Map<String, Object?>) {
      properties = {
        for (final entry in rawProperties.entries)
          entry.key: _coerceToString(entry.value),
      };
    } else if (rawProperties != null) {
      throw InstanceFormatException(
        'Cannot deserialize value of type `java.util.Map` from '
        '${_jsonKind(rawProperties)} value',
      );
    }
    final rawGeometry = json['geometry'];
    return GeojsonFeature(
      type: _coerceToString(json['type']),
      geometry: rawGeometry == null
          ? null
          : GeojsonGeometry.fromJson(rawGeometry),
      properties: properties,
      id: _coerceToString(json['id']),
    );
  }

  /// The feature's `type`; must be `Feature`.
  final String? type;

  /// The geometry, if any.
  final GeojsonGeometry? geometry;

  /// The properties (values as strings; JSON `null` stays `null`).
  final Map<String, String?>? properties;

  /// The top-level id, if any.
  final String? id;

  /// The instance item for this feature at [multiplicity].
  TreeElement toTreeElement(int multiplicity) {
    final type = this.type;
    if (type == null) throw StateError('feature without a type');
    if (type != 'Feature') {
      throw InstanceFormatException(
        'Item of type $type found but expected item of type Feature',
      );
    }
    final item = TreeElement('item', multiplicity);
    final geometry = this.geometry;
    if (geometry != null) {
      item.addChild(
        TreeElement(geometryChildName, 0)
          ..value = UncastValue(geometry.odkCoordinates),
      );
    }
    final properties = this.properties;
    if (properties != null) {
      properties.forEach((name, value) {
        item.addChild(TreeElement(name, 0)..value = UncastValue(value ?? ''));
      });
    }
    final id = this.id;
    if (id != null) {
      final existing = item.childrenWithName('id');
      if (existing.isNotEmpty) {
        existing.first.value = UncastValue(id);
      } else {
        item.addChild(TreeElement('id', 0)..value = UncastValue(id));
      }
    }
    return item;
  }
}

/// A GeoJSON geometry. Port of `GeojsonGeometry` (unlike features, unknown
/// fields are an error, as Jackson's default).
final class GeojsonGeometry {
  /// Creates a geometry.
  const GeojsonGeometry({this.type, this.coordinates});

  /// Reads a geometry from JSON [text], as Jackson's
  /// `readValue(text, GeojsonGeometry.class)`.
  factory GeojsonGeometry.parse(String text) {
    final value = _JsonReader(text).readValue();
    if (value == null) throw StateError('null geometry');
    return GeojsonGeometry.fromJson(value);
  }

  /// Reads a geometry from a parsed JSON value.
  factory GeojsonGeometry.fromJson(Object json) {
    if (json is! Map<String, Object?>) {
      throw InstanceFormatException(
        'Cannot construct instance of `GeojsonGeometry` from '
        '${_jsonKind(json)} value',
      );
    }
    for (final key in json.keys) {
      if (key != 'type' && key != 'coordinates') {
        throw InstanceFormatException(
          'Unrecognized field "$key" (class GeojsonGeometry), not marked as '
          'ignorable',
        );
      }
    }
    final coordinates = json['coordinates'];
    if (coordinates != null && coordinates is! List<Object?>) {
      throw InstanceFormatException(
        'Cannot deserialize value of type `java.util.ArrayList` from '
        '${_jsonKind(coordinates)} value',
      );
    }
    return GeojsonGeometry(
      type: _coerceToString(json['type']),
      coordinates: coordinates == null
          ? null
          : [for (final c in coordinates as List<Object?>) _untyped(c)],
    );
  }

  /// `Point`, `LineString` or `Polygon`.
  final String? type;

  /// The coordinates as Jackson's untyped values: `int`/`BigInt` for
  /// integers, `double` for other numbers, strings, booleans, `null`, lists
  /// and maps.
  final List<Object?>? coordinates;

  /// The ODK geo string: `lat lon 0 0` points joined by `; `. Only the outer
  /// ring of a polygon is used.
  String get odkCoordinates {
    final type = this.type;
    if (type == null) throw StateError('geometry without a type');
    String point(Object? p) {
      final list = p! as List<Object?>;
      return '${_javaString(list[1])} ${_javaString(list[0])} 0 0';
    }

    switch (type) {
      case 'Point':
        final c = coordinates!;
        return '${_javaString(c[1])} ${_javaString(c[0])} 0 0';
      case 'LineString':
        return coordinates!.map(point).join('; ');
      case 'Polygon':
        final c = coordinates!;
        if (c.isEmpty) return '';
        return (c.first! as List<Object?>).map(point).join('; ');
      default:
        throw const InstanceFormatException(
          'Only Points, LineStrings and Polygons are currently supported',
        );
    }
  }
}

/// A JSON number with its original text.
final class _JsonNumber {
  const _JsonNumber(this.raw, {required this.isInteger});

  final String raw;
  final bool isInteger;
}

/// Jackson's coercion of a JSON value to a `String` field.
String? _coerceToString(Object? value) => switch (value) {
  null => null,
  String() => value,
  _JsonNumber() => value.raw,
  bool() => '$value',
  _ => throw InstanceFormatException(
    'Cannot deserialize value of type `java.lang.String` from '
    '${_jsonKind(value)} value',
  ),
};

/// Jackson's untyped value for a JSON value (`Object` target).
Object? _untyped(Object? value) => switch (value) {
  _JsonNumber(isInteger: true) => BigInt.parse(value.raw),
  _JsonNumber() => double.parse(value.raw),
  List<Object?>() => [for (final v in value) _untyped(v)],
  Map<String, Object?>() => {
    for (final e in value.entries) e.key: _untyped(e.value),
  },
  _ => value,
};

/// Java's `String.valueOf` for an untyped value.
String _javaString(Object? value) => switch (value) {
  null => 'null',
  double() => javaDoubleToString(value),
  List<Object?>() => '[${value.map(_javaString).join(', ')}]',
  Map<String, Object?>() =>
    '{${value.entries.map((e) => '${e.key}=${_javaString(e.value)}').join(', ')}}',
  _ => '$value',
};

String _jsonKind(Object? value) => switch (value) {
  List<Object?>() => 'Array',
  Map<String, Object?>() => 'Object',
  String() => 'String',
  _JsonNumber() => 'Number',
  bool() => 'Boolean',
  _ => 'Null',
};

/// A strict JSON reader (RFC 8259, as Jackson's defaults: no comments, no
/// trailing commas, no leading zeros) that keeps raw number text.
final class _JsonReader {
  _JsonReader(this._text);

  final String _text;
  int _pos = 0;

  Never _error(String message) =>
      throw InstanceFormatException('$message at position $_pos');

  void _skipWhitespace() {
    while (_pos < _text.length) {
      final c = _text.codeUnitAt(_pos);
      if (c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) break;
      _pos++;
    }
  }

  int _peek() {
    _skipWhitespace();
    return _pos < _text.length ? _text.codeUnitAt(_pos) : -1;
  }

  bool startsObject() => _peek() == 0x7B;

  bool peekIsString() => _peek() == 0x22;

  bool peekIsArray() => _peek() == 0x5B;

  bool tryConsume(int c) {
    if (_peek() != c) return false;
    _pos++;
    return true;
  }

  void expect(int c) {
    if (!tryConsume(c)) {
      _error("Unexpected character, expected '${String.fromCharCode(c)}'");
    }
  }

  Object? readValue() {
    final c = _peek();
    switch (c) {
      case 0x7B:
        _pos++;
        final map = <String, Object?>{};
        if (tryConsume(0x7D)) return map;
        while (true) {
          final key = readString();
          expect(0x3A);
          map[key] = readValue();
          if (tryConsume(0x7D)) return map;
          expect(0x2C);
        }
      case 0x5B:
        _pos++;
        final list = <Object?>[];
        if (tryConsume(0x5D)) return list;
        while (true) {
          list.add(readValue());
          if (tryConsume(0x5D)) return list;
          expect(0x2C);
        }
      case 0x22:
        return readString();
      case 0x74:
        return _literal('true', true);
      case 0x66:
        return _literal('false', false);
      case 0x6E:
        return _literal('null', null);
      case -1:
        _error('Unexpected end-of-input');
      default:
        if (c == 0x2D || (c >= 0x30 && c <= 0x39)) return _number();
        _error("Unexpected character ('${String.fromCharCode(c)}')");
    }
  }

  Object? _literal(String word, Object? value) {
    if (!_text.startsWith(word, _pos)) _error('Unrecognized token');
    _pos += word.length;
    return value;
  }

  static final _numberPattern = RegExp(
    r'-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?',
  );

  _JsonNumber _number() {
    final match = _numberPattern.matchAsPrefix(_text, _pos);
    if (match == null) _error('Invalid numeric value');
    _pos = match.end;
    if (_pos < _text.length) {
      final next = _text.codeUnitAt(_pos);
      if (next >= 0x30 && next <= 0x39) {
        _error('Invalid numeric value: Leading zeroes not allowed');
      }
    }
    return _JsonNumber(
      match.group(0)!,
      isInteger: match.group(2) == null && match.group(3) == null,
    );
  }

  String readString() {
    if (_peek() != 0x22) _error('Unexpected character, expected a string');
    _pos++;
    final buffer = StringBuffer();
    while (true) {
      if (_pos >= _text.length) _error('Unexpected end-of-input in a String');
      final c = _text.codeUnitAt(_pos++);
      if (c == 0x22) return buffer.toString();
      if (c < 0x20) _error('Illegal unquoted character');
      if (c != 0x5C) {
        buffer.writeCharCode(c);
        continue;
      }
      if (_pos >= _text.length) _error('Unexpected end-of-input in a String');
      final e = _text.codeUnitAt(_pos++);
      switch (e) {
        case 0x22 || 0x5C || 0x2F:
          buffer.writeCharCode(e);
        case 0x62:
          buffer.writeCharCode(0x08);
        case 0x66:
          buffer.writeCharCode(0x0C);
        case 0x6E:
          buffer.writeCharCode(0x0A);
        case 0x72:
          buffer.writeCharCode(0x0D);
        case 0x74:
          buffer.writeCharCode(0x09);
        case 0x75:
          if (_pos + 4 > _text.length) _error('Unexpected end-of-input');
          final code = int.tryParse(_text.substring(_pos, _pos + 4), radix: 16);
          if (code == null) _error('Unexpected character in escape sequence');
          buffer.writeCharCode(code);
          _pos += 4;
        default:
          _error('Unrecognized character escape');
      }
    }
  }
}
