// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// docs/widgets/select-one.md: choice images from the form's media folder.
import 'dart:io';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/painting.dart';

class AppDelegates extends XFormDelegates {
  AppDelegates(this.mediaDir);

  final Directory mediaDir;

  @override
  ImageProvider? image(String uri) =>
      FileImage(File('${mediaDir.path}/${Uri.parse(uri).pathSegments.last}'));
}
