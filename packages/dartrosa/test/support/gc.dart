// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Forcing a full garbage collection from a test, to check that objects
// can be collected (VM only).
library;

import 'dart:developer';
import 'dart:isolate';

import 'package:vm_service/vm_service_io.dart';

/// Runs a full garbage collection of this isolate's heap, through the VM
/// service (started for the occasion if it isn't running, and stopped
/// again).
Future<void> collectGarbage() async {
  var info = await Service.getInfo();
  final started = info.serverWebSocketUri == null;
  if (started) {
    info = await Service.controlWebServer(enable: true, silenceOutput: true);
  }
  final service = await vmServiceConnectUri('${info.serverWebSocketUri}');
  try {
    await service.getAllocationProfile(
      Service.getIsolateId(Isolate.current)!,
      gc: true,
    );
  } finally {
    await service.dispose();
    if (started) await Service.controlWebServer(enable: false);
  }
}
