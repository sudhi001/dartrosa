// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Engine benchmarks for DartRosa's performance targets: parsing a large
// form, the answer -> recompute cascade, starting a session, filtering a
// large CSV choice list and growing a repeat. docs/BENCHMARKS.md explains
// the method and records the results.
//
// Run it compiled ahead of time (AOT), as apps ship:
//
//   dart compile exe benchmark/engine_benchmark.dart -o /tmp/dartrosa-bench
//   /tmp/dartrosa-bench                     # table
//   /tmp/dartrosa-bench --json > bench.json # machine-readable
//
// `benchmark/run.sh` does this and redraws docs/images/benchmarks.svg.
//
// Options: `--json` prints JSON instead of a table; `--out=FILE` prints the
// table and also writes the JSON to FILE; `--runs=N` multiplies
// the number of timed runs of every case (default 1, i.e. the counts below);
// `--quick` runs each case a few times only (a smoke test).
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"';

/// A form with [n] integer questions: every fifth has a relevance condition
/// on the previous one, every fifth (offset by one) a calculation chained
/// from the previous one, and the rest are required with a constraint.
String bigForm(int n) {
  final instance = StringBuffer();
  final binds = StringBuffer();
  final body = StringBuffer();
  for (var i = 0; i < n; i++) {
    instance.write('<q$i/>');
    if (i > 0 && i % 5 == 0) {
      binds.write(
        '<bind nodeset="/data/q$i" type="int" '
        'relevant="/data/q${i - 1} != 7"/>',
      );
    } else if (i > 0 && i % 5 == 1) {
      binds.write(
        '<bind nodeset="/data/q$i" type="int" '
        'calculate="/data/q${i - 1} + 1"/>',
      );
    } else {
      binds.write(
        '<bind nodeset="/data/q$i" type="int" required="true()" '
        'constraint=". &lt; 1000"/>',
      );
    }
    body.write(
      '<input ref="/data/q$i"><label>Question $i</label>'
      '<hint>Hint $i</hint></input>',
    );
  }
  return '<?xml version="1.0"?><h:html $_ns><h:head><h:title>Big</h:title>'
      '<model><instance><data id="big">$instance</data></instance>$binds'
      '</model></h:head><h:body>$body</h:body></h:html>';
}

/// A cascading select whose choices come from an external CSV, filtered by
/// the answer to the first question.
String csvForm() =>
    '<?xml version="1.0"?><h:html $_ns><h:head><h:title>CSV</h:title>'
    '<model><instance><data id="csv"><region/><place/></data></instance>'
    '<instance id="places" src="jr://file-csv/places.csv"/>'
    '<bind nodeset="/data/region" type="string"/>'
    '<bind nodeset="/data/place" type="string"/></model></h:head><h:body>'
    '<input ref="/data/region"><label>Region</label></input>'
    '<select1 ref="/data/place"><label>Place</label>'
    "<itemset nodeset=\"instance('places')/root/item[region = /data/region]\">"
    '<value ref="name"/><label ref="label"/></itemset></select1>'
    '</h:body></h:html>';

/// A CSV of [rows] places spread over 1,000 regions.
String placesCsv(int rows) {
  final b = StringBuffer('name,label,region\n');
  for (var i = 0; i < rows; i++) {
    b.write('p$i,Place $i,r${i % 1000}\n');
  }
  return b.toString();
}

/// A repeat with a `position()` calculation in each instance and a
/// `count()` of the instances outside it.
String repeatForm() =>
    '<?xml version="1.0"?><h:html $_ns><h:head><h:title>Repeat</h:title>'
    '<model><instance><data id="rep"><r jr:template=""><v/><pos/></r>'
    '<count/></data></instance>'
    '<bind nodeset="/data/r/v" type="int"/>'
    '<bind nodeset="/data/r/pos" type="int" calculate="position(..)"/>'
    '<bind nodeset="/data/count" type="int" calculate="count(/data/r)"/>'
    '</model></h:head><h:body><repeat nodeset="/data/r">'
    '<input ref="/data/r/v"><label>V</label></input></repeat></h:body></h:html>';

/// One benchmark case and its timed samples.
final class CaseResult {
  /// Creates the result of case [id].
  CaseResult({
    required this.id,
    required this.label,
    required this.samples,
    this.targetMs,
    this.targetLabel,
    this.javarosaMs,
  });

  /// A stable identifier, used as the JSON key and by the chart.
  final String id;

  /// What the case measures, for people.
  final String label;

  /// The duration of every timed run, in milliseconds.
  final List<double> samples;

  /// The performance target, if the plan sets one.
  final double? targetMs;

  /// Where [targetMs] comes from.
  final String? targetLabel;

  /// JavaRosa 6.0.0's time for the same work, if measured.
  final double? javarosaMs;

  List<double> get _sorted => [...samples]..sort();

  /// The median of [samples].
  double get median {
    final s = _sorted;
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }

  /// The 90th percentile of [samples] (nearest rank).
  double get p90 {
    final s = _sorted;
    final rank = (0.9 * s.length).ceil().clamp(1, s.length);
    return s[rank - 1];
  }

  /// The fastest run.
  double get min => _sorted.first;

  /// The result as JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'runs': samples.length,
    'medianMs': _round(median),
    'p90Ms': _round(p90),
    'minMs': _round(min),
    'targetMs': targetMs,
    'targetLabel': targetLabel,
    'javarosaMs': javarosaMs,
  };
}

double _round(double ms) => (ms * 1000).round() / 1000;

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000;

/// Times [runs] calls of [body] after [warmUp] untimed ones.
Future<List<double>> sample(
  Future<void> Function() body, {
  required int runs,
  int warmUp = 2,
}) async {
  for (var i = 0; i < warmUp; i++) {
    await body();
  }
  final samples = <double>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    await body();
    samples.add(_ms(sw));
  }
  return samples;
}

/// Parses a 1,000-question form.
Future<CaseResult> parseCase(int runs) async {
  final xml = bigForm(1000);
  return CaseResult(
    id: 'parse',
    label: 'Parse a 1,000-question form',
    samples: await sample(() => FormDefinition.parse(xml), runs: runs),
    targetMs: 300,
    targetLabel: 'target < 300 ms (mid-range phone)',
  );
}

/// Answers a question of the 1,000-question form and recomputes what
/// depends on it.
Future<CaseResult> answerCase(int runs) async {
  final definition = await FormDefinition.parse(bigForm(1000));
  final session = definition.createSession();
  final question = session.root.children[4];
  var v = 0;
  return CaseResult(
    id: 'answer',
    label: 'Answer -> recompute (1,000 questions)',
    samples: await sample(() async {
      session.answer(question.index, IntegerValue(v++ % 10));
    }, runs: runs),
    targetMs: 16,
    targetLabel: 'target < 16 ms (one frame)',
  );
}

/// Starts a session on the 1,000-question form (initializes every
/// calculation).
Future<CaseResult> sessionCase(int runs) async {
  final definition = await FormDefinition.parse(bigForm(1000));
  return CaseResult(
    id: 'session',
    label: 'Start a session (1,000 questions)',
    samples: await sample(
      () async => definition.createSession(),
      runs: runs,
      warmUp: 1,
    ),
  );
}

/// Filters a 100,000-row CSV choice list by the answer to another question.
Future<CaseResult> csvCase(int runs) async {
  final csv = Uint8List.fromList(utf8.encode(placesCsv(100000)));
  final definition = await FormDefinition.parse(
    csvForm(),
    config: DartRosaConfig(
      resolver: MapResourceResolver({'jr://file-csv/places.csv': csv}),
    ),
  );
  final session = definition.createSession();
  final region = session.root.children[0];
  final place = session.root.children[1] as QuestionNode;
  var r = 0;
  return CaseResult(
    id: 'csv',
    label: 'Filter a 100,000-row CSV choice list',
    samples: await sample(() async {
      session.answer(region.index, StringValue('r${r++ % 1000}'));
      if (place.choices.length != 100) throw StateError('bad filter');
    }, runs: runs),
    targetMs: 50,
    targetLabel: 'target < 50 ms',
  );
}

/// Grows a repeat to 1,000 instances, each with a `position()` calculation,
/// plus a `count()` outside the repeat. JavaRosa 6.0.0 takes about 3.0 s on
/// the JVM on the same machine; both engines are quadratic here, because
/// every insertion recomputes `position()` in every instance.
Future<CaseResult> repeatCase(int runs) async {
  final definition = await FormDefinition.parse(repeatForm());
  return CaseResult(
    id: 'repeat',
    label: 'Grow a repeat to 1,000 instances',
    samples: await sample(
      () async {
        final session = definition.createSession();
        final repeat = session.root.children[0] as RepeatNode;
        for (var i = 0; i < 1000; i++) {
          session.addRepeatInstance(repeat.index);
        }
      },
      runs: runs,
      warmUp: 1,
    ),
    javarosaMs: 3000,
  );
}

/// The first line of [executable]'s output for [arguments], or `null`.
String? _command(String executable, List<String> arguments) {
  try {
    final result = Process.runSync(executable, arguments);
    if (result.exitCode != 0) return null;
    final out = (result.stdout as String).trim();
    return out.isEmpty ? null : out.split('\n').first.trim();
  } on ProcessException {
    return null;
  }
}

/// A line of [path] matching [pattern], or `null`.
String? _fileLine(String path, RegExp pattern) {
  try {
    for (final line in File(path).readAsLinesSync()) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1)?.trim();
    }
  } on FileSystemException {
    return null;
  }
  return null;
}

/// The machine the benchmark runs on.
Map<String, Object?> machineInfo() {
  final String? cpu;
  final String? load;
  if (Platform.isMacOS) {
    cpu = _command('sysctl', ['-n', 'machdep.cpu.brand_string']);
    load = _command('sysctl', [
      '-n',
      'vm.loadavg',
    ])?.replaceAll(RegExp(r'[{}]'), '').trim();
  } else if (Platform.isLinux) {
    cpu = _fileLine('/proc/cpuinfo', RegExp(r'^model name\s*:\s*(.*)$'));
    load = _fileLine('/proc/loadavg', RegExp(r'^(\S+ \S+ \S+)'));
  } else {
    cpu = null;
    load = null;
  }
  return {
    'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'cpu': cpu,
    'cores': Platform.numberOfProcessors,
    'dart': Platform.version.split(' ').first,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'AOT' : 'JIT',
    'loadAverage': load,
    'date': DateTime.now().toUtc().toIso8601String(),
  };
}

Future<void> main(List<String> arguments) async {
  final json = arguments.contains('--json');
  final outPath = arguments
      .where((a) => a.startsWith('--out='))
      .map((a) => a.substring('--out='.length))
      .firstOrNull;
  final quick = arguments.contains('--quick');
  final runsArg = arguments
      .where((a) => a.startsWith('--runs='))
      .map((a) => int.parse(a.substring('--runs='.length)))
      .firstOrNull;
  final factor = runsArg ?? 1;
  int runs(int n) => quick ? 3 : n * factor;

  final machine = machineInfo();
  // Each case runs in its own function so its data can be collected before
  // the next one starts.
  final results = <CaseResult>[
    await parseCase(runs(15)),
    await answerCase(runs(200)),
    await sessionCase(runs(15)),
    await csvCase(runs(50)),
    await repeatCase(runs(5)),
  ];
  // The load at the end covers the whole run.
  machine['loadAverageAfter'] = machineInfo()['loadAverage'];

  final report = const JsonEncoder.withIndent('  ').convert({
    'machine': machine,
    'cases': [for (final r in results) r.toJson()],
  });
  if (outPath != null) File(outPath).writeAsStringSync('$report\n');
  if (json) {
    print(report);
    return;
  }
  print(
    'DartRosa engine benchmark (${machine['mode']}, Dart ${machine['dart']})',
  );
  print('${machine['os']}; ${machine['cpu']}; ${machine['cores']} cores');
  print(
    'Load average before: ${machine['loadAverage']}, '
    'after: ${machine['loadAverageAfter']}',
  );
  print('');
  print(
    '${'Case'.padRight(50)} ${'runs'.padLeft(5)} '
    '${'median'.padLeft(11)} ${'p90'.padLeft(11)}  target',
  );
  for (final r in results) {
    final target =
        r.targetLabel ??
        (r.javarosaMs == null ? '' : 'JavaRosa ${_fmt(r.javarosaMs!)}');
    print(
      '${r.label.padRight(50)} ${'${r.samples.length}'.padLeft(5)} '
      '${_fmt(r.median).padLeft(11)} ${_fmt(r.p90).padLeft(11)}  $target',
    );
  }
}

String _fmt(double ms) => ms >= 1000
    ? '${(ms / 1000).toStringAsFixed(2)} s'
    : ms >= 10
    ? '${ms.toStringAsFixed(1)} ms'
    : '${ms.toStringAsFixed(3)} ms';
