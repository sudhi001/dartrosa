// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'support/forms.dart';

/// The JavaRosa test resource called [name], found anywhere under
/// `conformance/forms/javarosa` (like JavaRosa's `ResourcePathHelper.r`).
File javarosaResource(String name) =>
    Directory('${conformanceDir().path}/forms/javarosa')
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere(
          (f) => f.uri.pathSegments.last == name,
          orElse: () => throw StateError('test resource $name not found'),
        );

/// The bytes of the JavaRosa test resource [name].
Uint8List resourceBytes(String name) =>
    javarosaResource(name).readAsBytesSync();
