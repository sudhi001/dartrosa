// Repeat growth only, for profiling.
// ignore_for_file: avoid_print
import 'package:dartrosa/dartrosa.dart';

import 'engine_benchmark.dart' show repeatForm;

Future<void> main() async {
  final definition = await FormDefinition.parse(repeatForm());
  final session = definition.createSession();
  final repeat = session.root.children[0] as RepeatNode;
  final sw = Stopwatch()..start();
  for (var i = 0; i < 1000; i++) {
    session.addRepeatInstance(repeat.index);
  }
  print('add 1000: ${sw.elapsedMilliseconds} ms');
}
