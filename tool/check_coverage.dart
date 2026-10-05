// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Fails when line coverage of packages/dartrosa/lib (from an lcov file)
// is below the minimum (docs/development/PORTING_PLAN.md §10.2).
//
//   dart run tool/check_coverage.dart coverage/lcov.info [minimumPercent]
import 'dart:io';

void main(List<String> args) {
  final lcov = File(args.isEmpty ? 'coverage/lcov.info' : args[0]);
  final minimum = args.length > 1 ? double.parse(args[1]) : 90;
  var found = 0;
  var hit = 0;
  for (final line in lcov.readAsLinesSync()) {
    if (!line.startsWith('DA:')) continue;
    found++;
    if (int.parse(line.split(',')[1]) > 0) hit++;
  }
  final percent = found == 0 ? 0 : 100 * hit / found;
  stdout.writeln(
    'Line coverage: $hit/$found = ${percent.toStringAsFixed(2)}% '
    '(minimum $minimum%)',
  );
  if (percent < minimum) exit(1);
}
