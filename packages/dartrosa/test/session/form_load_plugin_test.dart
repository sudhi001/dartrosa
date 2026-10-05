// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormDef), Copyright (C) 2009 JavaRosa; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests (not ports) of FormLoadPlugin, DartRosaConfig.plugins and
// FormDef.extras (a port of JavaRosa's FormDef.getExtras()).
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:test/test.dart';

const _formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>Plugin</h:title><model>
<instance><data id="plugin"><q/><c/><s/></data></instance>
<bind nodeset="/data/c" calculate="answer()"/>
<bind nodeset="/data/s" type="select1"/>
</model></h:head>
<h:body><input ref="/data/q"><label>Q</label></input>
<select1 ref="/data/s"><label>S</label><item><label>A</label><value>a</value></item></select1>
</h:body></h:html>
''';

final class _Marker {}

final class _CountingProcessor implements XPathProcessor, FormDefProcessor {
  int expressions = 0;

  @override
  void processXPath(XPathExpression expression) => expressions++;

  @override
  void processFormDef(FormDef form) => form.extras.put(_Marker());
}

final class _Answer extends XPathFunctionHandler {
  _Answer(this.value);

  final String value;

  @override
  String get name => 'answer';

  @override
  List<List<XPathArgType>> get prototypes => const [[]];

  @override
  Object eval(List<Object> args, EvaluationContext context) => value;
}

final class _Plugin extends FormLoadPlugin {
  final processors = <_CountingProcessor>[];
  final resolvedBytes = <int>[];
  final resolvedValues = <String>[];

  @override
  List<Object> createParseProcessors() {
    final processor = _CountingProcessor();
    processors.add(processor);
    return [processor];
  }

  @override
  Future<void> prepareForm(FormDef form, ResourceResolver resolver) async {
    expect(form.extras.get<_Marker>(), isNotNull);
    resolvedBytes.addAll(await resolver.read('jr://file/x.csv'));
    form.addFunctionHandler(_Answer('from plugin'));
  }

  @override
  AnswerResolver get answerResolver => (text, element, form) {
    resolvedValues.add(text);
    return SelectOneValue(Selection(text));
  };
}

void main() {
  final resolver = MapResourceResolver({
    'jr://file/x.csv': Uint8List.fromList([1, 2]),
  });

  test('plugins get fresh processors per parse and prepare the form', () async {
    final plugin = _Plugin();
    final config = DartRosaConfig(resolver: resolver, plugins: [plugin]);
    final definition = await FormDefinition.parse(_formXml, config: config);
    await FormDefinition.parse(_formXml, config: config);

    expect(plugin.processors, hasLength(2));
    expect(plugin.processors.first.expressions, greaterThan(0));
    expect(plugin.resolvedBytes, [1, 2, 1, 2]);
    definition.createSession();
    expect(
      definition.formDef.mainInstance.root.getChild('c', 0)!.value!.displayText,
      'from plugin',
    );
  });

  test('the app functions take precedence over the plugin functions', () async {
    final definition = await FormDefinition.parse(
      _formXml,
      config: DartRosaConfig(
        resolver: resolver,
        plugins: [_Plugin()],
        functions: [_Answer('from app')],
      ),
    );
    definition.createSession();
    expect(
      definition.formDef.mainInstance.root.getChild('c', 0)!.value!.displayText,
      'from app',
    );
  });

  test('a plugin answer resolver types loaded instances', () async {
    final plugin = _Plugin();
    final definition = await FormDefinition.parse(
      _formXml,
      config: DartRosaConfig(resolver: resolver, plugins: [plugin]),
    );
    definition.createSession(
      existingInstance:
          '<data id="plugin"><q>x</q><c/><s>not-a-choice</s></data>',
    );
    expect(plugin.resolvedValues, ['not-a-choice']);
    final s = definition.formDef.mainInstance.root.getChild('s', 0)!;
    expect(s.value!.displayText, 'not-a-choice');
  });

  test('extras are keyed by type', () {
    final extras = Extras<Object>()..put('a');
    expect(extras.get<String>(), 'a');
    expect(extras.get<_Marker>(), isNull);
    extras.put('b');
    expect(extras.get<String>(), 'b');
  });
}
