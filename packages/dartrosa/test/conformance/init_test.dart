// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import 'structure_dump.dart';
import 'trace_support.dart';

/// Compares the dependency graph and the instance after
/// `initialize(newInstance: true)` of every form with the JavaRosa
/// oracle's `traces/init` golden.
void main() {
  for (final golden in goldenTraces(['init'])) {
    final trace = jsonDecode(golden.readAsStringSync()) as Map<String, Object?>;
    final formPath = trace['form']! as String;
    test(formPath, skip: skipUnlessUtc, () async {
      final parse = trace['parse']! as Map<String, Object?>;
      final file = File('${conformanceDir().path}/$formPath');
      FormDef form;
      try {
        form = await parseFile(file);
      } on Object catch (e) {
        expect(parse['ok'], isFalse, reason: 'JavaRosa parses it: $e');
        final error = parse['error']! as Map<String, Object?>;
        if (error['type'] == 'XFormParseException') {
          expect(e, isA<XFormParseException>());
          expect(
            stableMessage((e as XFormParseException).message),
            error['message'],
          );
        }
        return;
      }
      expect(parse['ok'], isTrue, reason: 'JavaRosa fails: ${parse['error']}');
      final differences = <String>[];
      diff(
        '.cascades',
        trace['cascades'],
        asJson(cascadesOf(form)),
        differences,
      );
      final init = trace['initialize']! as Map<String, Object?>;
      try {
        form.initialize(newInstance: true);
      } on Object catch (e) {
        expect(init['ok'], isFalse, reason: 'JavaRosa initializes it: $e');
        // JavaRosa evaluates a DAG level in identity-hash order, so what a
        // failed initialization already changed isn't comparable; the error
        // is.
        expect(exceptionMessage(e), (init['error']! as Map)['message']);
        expect(differences, isEmpty, reason: differences.join('\n'));
        return;
      }
      expect(init['ok'], isTrue, reason: 'JavaRosa fails: ${init['error']}');
      diff(
        '.instance',
        trace['instance'],
        asJson(structureOf(form)['instance']),
        differences,
      );
      expect(differences, isEmpty, reason: differences.take(15).join('\n'));
    });
  }
}
