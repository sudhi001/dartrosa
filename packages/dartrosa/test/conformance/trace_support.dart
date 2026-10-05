/// Helpers shared by the oracle trace comparisons (VM only).
library;

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '../support/forms.dart';

/// The oracle's golden files under `conformance/traces/<kind>` for each of
/// [kinds] whose name ends with [suffix], sorted by path.
List<File> goldenTraces(List<String> kinds, {String suffix = '.json'}) {
  final root = conformanceDir().path;
  return [
    for (final kind in kinds)
      for (final entity in Directory(
        '$root/traces/$kind',
      ).listSync(recursive: true))
        if (entity is File && entity.path.endsWith(suffix)) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

/// [value] as the JSON it encodes to, comparable with a decoded trace.
Object? asJson(Object? value) => jsonDecode(jsonEncode(value));

/// [e]'s message as Java's `getMessage()` gives it (Dart's `toString()` of
/// `FormatException`, `StateError` and `ArgumentError` adds a type prefix),
/// with cycle lines sorted.
String exceptionMessage(Object e) => stableMessage(switch (e) {
  FormatException() => e.message,
  StateError() => e.message,
  ArgumentError(:final Object message) => '$message',
  _ => '$e',
});

/// The oracle's `stableError`: cycle node lines sorted.
String stableMessage(String message) {
  const marker = 'The following nodes are likely involved in the loop:';
  final at = message.indexOf(marker);
  if (at == -1) return message;
  final end = at + marker.length;
  final lines =
      message.substring(end).split('\n').where((l) => l.isNotEmpty).toList()
        ..sort();
  return '${message.substring(0, end)}\n${lines.join('\n')}';
}

/// Records differences between [expected] and [actual] under [path].
void diff(String path, Object? expected, Object? actual, List<String> out) {
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      diff('$path.$key', expected[key], actual[key], out);
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} != ${actual.length}');
    }
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      diff('$path[$i]', expected[i], actual[i], out);
    }
  } else if (!const DeepCollectionEquality().equals(expected, actual)) {
    out.add('$path: expected <$expected> got <$actual>');
  }
}
