// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// docs/widgets/README.md: supplying a device feature.
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/widgets.dart';

class AppDelegates extends XFormDelegates {
  @override
  bool get canLocate => true;

  @override
  Future<String?> currentLocation(BuildContext context) async {
    final p = await Geolocator.getCurrentPosition();
    return '${p.latitude} ${p.longitude} ${p.altitude} ${p.accuracy}';
  }
}

/// Stand-in for package:geolocator.
class Geolocator {
  static Future<Position> getCurrentPosition() async => const Position();
}

/// Stand-in for package:geolocator's position.
class Position {
  const Position();
  double get latitude => 0;
  double get longitude => 0;
  double get altitude => 0;
  double get accuracy => 0;
}
