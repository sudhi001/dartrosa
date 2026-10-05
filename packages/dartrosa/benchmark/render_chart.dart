// Turns the JSON of `engine_benchmark.dart --json` into an SVG bar chart,
// one row per case, each on its own linear scale with its target (or
// JavaRosa's time) marked.
//
//   dart run benchmark/render_chart.dart results.json ../../docs/images/benchmarks.svg
//
// Reads standard input when the input path is `-` and writes standard
// output when the output path is omitted.
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

const _width = 760;
const _left = 330; // label column
const _right = 40;
const _top = 92;
const _rowHeight = 64;
const _barHeight = 16;

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _fmt(double ms) => ms >= 1000
    ? '${(ms / 1000).toStringAsFixed(2)} s'
    : ms >= 10
    ? '${ms.toStringAsFixed(0)} ms'
    : ms >= 1
    ? '${ms.toStringAsFixed(1)} ms'
    : '${ms.toStringAsFixed(2)} ms';

/// Renders the benchmark [report] (the decoded JSON) as an SVG document.
String renderChart(Map<String, Object?> report) {
  final machine = report['machine']! as Map<String, Object?>;
  final cases = [
    for (final c in report['cases']! as List<Object?>)
      c! as Map<String, Object?>,
  ];
  final plotWidth = _width - _left - _right;
  final height = _top + cases.length * _rowHeight + 56;
  final out = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$_width" '
      'height="$height" viewBox="0 0 $_width $height" role="img" '
      'aria-labelledby="title desc">',
    )
    ..writeln(
      '<title id="title">DartRosa engine benchmark: median time per case '
      'against its target</title>',
    )
    ..writeln(
      '<desc id="desc">${_escape([for (final c in cases) '${c['label']}: median ${_fmt(_num(c['medianMs']))}'
            '${c['targetMs'] != null ? ', target ${_fmt(_num(c['targetMs']))}' : ''}'
            '${c['javarosaMs'] != null ? ', JavaRosa ${_fmt(_num(c['javarosaMs']))}' : ''}'].join('; '))}.</desc>',
    )
    ..writeln('<style>')
    ..writeln(
      '  .bg{fill:#fcfcfb}.t1{fill:#0b0b0b}.t2{fill:#52514e}'
      '.grid{stroke:#d9d8d3}.bar{fill:#2a78d6}.whisker{stroke:#0b0b0b}'
      '.target{stroke:#b3261e}.ttext{fill:#b3261e}',
    )
    ..writeln(
      '  @media (prefers-color-scheme: dark){.bg{fill:#1a1a19}.t1{fill:#fff}'
      '.t2{fill:#c3c2b7}.grid{stroke:#3a3a37}.bar{fill:#3987e5}'
      '.whisker{stroke:#fff}.target{stroke:#f2b8b5}.ttext{fill:#f2b8b5}}',
    )
    ..writeln(
      '  text{font-family:system-ui,-apple-system,"Segoe UI",Roboto,'
      'sans-serif}',
    )
    ..writeln('</style>')
    ..writeln(
      '<rect class="bg" x="0" y="0" width="$_width" height="$height" '
      'rx="8"/>',
    )
    ..writeln(
      '<text class="t1" x="24" y="34" font-size="18" font-weight="600">'
      'DartRosa engine benchmark</text>',
    )
    ..writeln(
      '<text class="t2" x="24" y="56" font-size="13">Median of N runs '
      '(bar), 90th percentile (whisker), target or JavaRosa 6.0.0 (red '
      'line). Each row has its own scale.</text>',
    );

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    final median = _num(c['medianMs']);
    final p90 = _num(c['p90Ms']);
    final target = c['targetMs'] == null ? null : _num(c['targetMs']);
    final javarosa = c['javarosaMs'] == null ? null : _num(c['javarosaMs']);
    final reference = target ?? javarosa;
    final scaleMax =
        [median, p90, ?reference].reduce((a, b) => a > b ? a : b) * 1.12;
    double x(double ms) => _left + ms / scaleMax * plotWidth;
    final y = _top + i * _rowHeight;
    final barY = y + 14;
    out
      ..writeln('<g>')
      ..writeln(
        '<title>${_escape('${c['label']}: median ${_fmt(median)}, p90 '
        '${_fmt(p90)} over ${c['runs']} runs')}</title>',
      )
      ..writeln(
        '<text class="t1" x="24" y="${barY + 12}" font-size="14">'
        '${_escape(c['label']! as String)}</text>',
      )
      ..writeln(
        '<text class="t2" x="24" y="${barY + 30}" font-size="12">'
        '${c['runs']} runs</text>',
      )
      ..writeln(
        '<line class="grid" x1="$_left" y1="${barY - 6}" x2="$_left" '
        'y2="${barY + _barHeight + 6}" stroke-width="1"/>',
      );
    // A visible sliver even for tiny values.
    final barWidth = (x(median) - _left).clamp(2.0, plotWidth.toDouble());
    out
      ..writeln(
        '<rect class="bar" x="$_left" y="$barY" '
        'width="${barWidth.toStringAsFixed(1)}" height="$_barHeight" '
        'rx="4"/>',
      )
      ..writeln(
        '<line class="whisker" x1="${x(median).toStringAsFixed(1)}" '
        'y1="${barY + _barHeight / 2}" x2="${x(p90).toStringAsFixed(1)}" '
        'y2="${barY + _barHeight / 2}" stroke-width="1.5"/>',
      )
      ..writeln(
        '<line class="whisker" x1="${x(p90).toStringAsFixed(1)}" '
        'y1="${barY + 3}" x2="${x(p90).toStringAsFixed(1)}" '
        'y2="${barY + _barHeight - 3}" stroke-width="1.5"/>',
      );
    out.writeln(
      '<text class="t1" x="$_left" y="${barY + _barHeight + 22}" '
      'font-size="12"><tspan font-weight="600">${_fmt(median)}</tspan>'
      '<tspan class="t2"> median, p90 ${_fmt(p90)}</tspan></text>',
    );
    if (reference != null) {
      final rx = x(reference).toStringAsFixed(1);
      final label = target != null
          ? 'target ${_fmt(target)}'
          : 'JavaRosa ${_fmt(javarosa!)}';
      out
        ..writeln(
          '<line class="target" x1="$rx" y1="${barY - 8}" x2="$rx" '
          'y2="${barY + _barHeight + 8}" stroke-width="2" '
          'stroke-dasharray="4 3"/>',
        )
        // Under the line, unless it would run into the median label.
        ..writeln(
          x(reference) - _left > 210
              ? '<text class="ttext" x="$rx" y="${barY + _barHeight + 22}" '
                    'font-size="12" text-anchor="end">${_escape(label)}</text>'
              : '<text class="ttext" x="${x(reference) + 6}" y="${barY - 2}" '
                    'font-size="12">${_escape(label)}</text>',
        );
    }
    if (reference == null) {
      out.writeln(
        '<text class="t2" x="${_width - _right}" '
        'y="${barY + _barHeight + 22}" font-size="12" text-anchor="end">'
        'no target set</text>',
      );
    }
    out.writeln('</g>');
  }

  final footY = _top + cases.length * _rowHeight + 24;
  final mode = machine['mode'];
  final info = [
    '${machine['cpu'] ?? 'unknown CPU'}',
    '${machine['os']}'.split(' (').first,
    'Dart ${machine['dart']} $mode',
    if (machine['loadAverage'] != null) 'load ${machine['loadAverage']}',
    '${machine['date']}'.split('T').first,
  ].join(' · ');
  out
    ..writeln(
      '<text class="t2" x="24" y="$footY" font-size="12">'
      '${_escape(info)}</text>',
    )
    ..writeln(
      '<text class="t2" x="24" y="${footY + 18}" font-size="12">Desktop '
      'numbers; phones are several times slower. Targets are for a '
      'mid-range Android phone.</text>',
    )
    ..writeln('</svg>');
  return out.toString();
}

double _num(Object? value) => (value! as num).toDouble();

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run benchmark/render_chart.dart <results.json|-> '
      '[output.svg]',
    );
    exitCode = 64;
    return;
  }
  final input = arguments.first == '-'
      ? await stdin.transform(utf8.decoder).join()
      : File(arguments.first).readAsStringSync();
  final svg = renderChart(jsonDecode(input) as Map<String, Object?>);
  if (arguments.length > 1) {
    File(arguments[1]).writeAsStringSync(svg);
  } else {
    stdout.write(svg);
  }
}
