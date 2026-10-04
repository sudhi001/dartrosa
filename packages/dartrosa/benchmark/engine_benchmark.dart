// Engine benchmarks for the plan's performance targets (PORTING_PLAN §1,
// §10.1): parse, answer cascade, large CSV choice filter, repeat growth.
//
// Run AOT for realistic numbers:
//   dart compile exe benchmark/engine_benchmark.dart -o /tmp/bench && /tmp/bench
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';

const _ns =
    'xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" '
    'xmlns:jr="http://openrosa.org/javarosa"';

/// A form with [n] questions: every 5th has a relevance condition on the
/// previous one and every 5th a calculation chaining from it.
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

/// A cascading select over an external CSV with [rows] rows.
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

String placesCsv(int rows) {
  final b = StringBuffer('name,label,region\n');
  for (var i = 0; i < rows; i++) {
    b.write('p$i,Place $i,r${i % 1000}\n');
  }
  return b.toString();
}

String repeatForm() =>
    '<?xml version="1.0"?><h:html $_ns><h:head><h:title>Repeat</h:title>'
    '<model><instance><data id="rep"><r jr:template=""><v/><pos/></r>'
    '<count/></data></instance>'
    '<bind nodeset="/data/r/v" type="int"/>'
    '<bind nodeset="/data/r/pos" type="int" calculate="position(..)"/>'
    '<bind nodeset="/data/count" type="int" calculate="count(/data/r)"/>'
    '</model></h:head><h:body><repeat nodeset="/data/r">'
    '<input ref="/data/r/v"><label>V</label></input></repeat></h:body></h:html>';

Future<Duration> time(Future<void> Function() f, {int runs = 5}) async {
  await f(); // warm-up
  final sw = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    await f();
  }
  return sw.elapsed ~/ runs;
}

String ms(Duration d) => '${(d.inMicroseconds / 1000).toStringAsFixed(1)} ms';

Future<void> main() async {
  // Each case runs in its own function so its data can be collected
  // before the next one.
  await _parse();
  await _answer();
  await _csv();
  await _repeats();
  // Keep the testing import used (Scenario is the reference driver).
  assert(Scenario.beginningOfForm.isBeginningOfFormIndex);
}

/// Parse a 1,000-question form (target < 300 ms on a mid-range phone).
Future<void> _parse() async {
  final xml = bigForm(1000);
  final parse = await time(() => FormDefinition.parse(xml));
  print('parse 1000-question form:        ${ms(parse)}');
}

/// Answer cascade (target < 16 ms) and session start.
Future<void> _answer() async {
  final definition = await FormDefinition.parse(bigForm(1000));
  final session = definition.createSession();
  final question = session.root.children[4];
  var v = 0;
  final answer = await time(() async {
    session.answer(question.index, IntegerValue(v++ % 10));
  }, runs: 50);
  print('answer -> recompute (1000 q):    ${ms(answer)}');
  final start = await time(() async => definition.createSession(), runs: 3);
  print('start session (initialize):      ${ms(start)}');
}

/// 100k-row CSV choice filter (target < 50 ms).
Future<void> _csv() async {
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
  final filter = await time(() async {
    session.answer(region.index, StringValue('r${r++ % 1000}'));
    if (place.choices.length != 100) throw StateError('bad filter');
  }, runs: 20);
  print('100k-row CSV choice filter:      ${ms(filter)}');
}

/// Grow a repeat to 1,000 instances with count()/position() dependents
/// (JavaRosa 6.0.0 on the JVM: about 3 s on the same machine; both are
/// quadratic, as every add recomputes position() in every instance).
Future<void> _repeats() async {
  final definition = await FormDefinition.parse(repeatForm());
  final sw = Stopwatch()..start();
  final session = definition.createSession();
  final repeat = session.root.children[0] as RepeatNode;
  for (var i = 0; i < 1000; i++) {
    session.addRepeatInstance(repeat.index);
  }
  print('add 1000 repeat instances:       ${ms(sw.elapsed)}');
}
