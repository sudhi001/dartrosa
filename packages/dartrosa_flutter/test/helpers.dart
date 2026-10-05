// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" '
    'xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"';

/// A form with instance [fields] (e.g. `<a/><b/>`), [binds] and [body],
/// optionally with an `<itext>` block.
Future<FormSession> formSession(
  String fields,
  String binds,
  String body, {
  String itext = '',
  String? language,
}) async {
  final xml =
      '<?xml version="1.0"?><h:html $_ns><h:head><h:title>T</h:title>'
      '<model>$itext<instance><data id="t">$fields</data></instance>'
      '$binds</model></h:head><h:body>$body</h:body></h:html>';
  return (await FormDefinition.parse(xml)).createSession(language: language);
}

/// Items `<item>` for [labels] with lower-cased values.
String items(List<String> labels) => [
  for (final l in labels)
    '<item><label>$l</label><value>${l.toLowerCase()}</value></item>',
].join();

/// A material app showing [child].
Widget app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

/// The question at [i] of [s]'s root.
QuestionNode question(FormSession s, int i) =>
    s.root.children[i] as QuestionNode;

/// A 1x1 transparent PNG.
final Uint8List transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Delegates that load every `jr://images/` URI as [transparentPng].
class ImageDelegates extends XFormDelegates {
  /// Creates the delegates.
  const ImageDelegates();

  @override
  ImageProvider? image(String uri) =>
      uri.startsWith('jr://images/') ? MemoryImage(transparentPng) : null;
}
