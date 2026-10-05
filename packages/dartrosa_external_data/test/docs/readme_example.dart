// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The example of README.md, verbatim below the imports its placeholders
// need; run by api_examples_test.dart.
// ignore_for_file: avoid_print, directives_ordering
import '../../example/example.dart' show xform;
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';

Future<void> main() async {
  final config = DartRosaConfig(
    // Form media, read as jr://file/<name>.
    resolver: MapResourceResolver({
      'jr://file/fruits.csv': utf8.encode('name,price\nmango,1.5\n'),
    }),
    plugins: [
      ExternalDataPlugin(listMedia: (_) => ['fruits.csv']),
    ],
  );
  // The form calculates pulldata('fruits', 'price', 'name', /data/fruit).
  final definition = await FormDefinition.parse(xform, config: config);
  final session = definition.createSession();
  final [fruit, price] = session.root.children.cast<QuestionNode>();
  session.answer(fruit.index, const StringValue('mango'));
  print(price.value?.displayText); // 1.5
}
