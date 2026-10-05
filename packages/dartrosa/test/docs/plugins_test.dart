// The core code of docs/PLUGINS.md, run as tests so the guide can't rot
// (doc_snippets.dart checks that its snippets are here or in
// packages/dartrosa_collect/test/docs).
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:test/test.dart';

import 'doc_snippets.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Plugins</h:title>
    <model>
      <instance>
        <data id="plugins">
          <name/><greeting/><boss/><previous/><motto/><source/>
        </data>
      </instance>
      <instance id="staff" src="jr://file-csv/staff.csv"/>
      <instance id="last" src="jr://instance/last-saved"/>
      <bind nodeset="/data/name" type="string"/>
      <bind nodeset="/data/greeting" type="string"
          calculate="greet(/data/name)"/>
      <bind nodeset="/data/boss" type="string"
          calculate="instance('staff')/root/item[role = 'boss']/name"/>
      <bind nodeset="/data/previous" type="string"
          calculate="instance('last')/data/name"/>
      <bind nodeset="/data/motto" type="string" calculate="motto()"/>
      <bind nodeset="/data/source" type="string" jr:preload="app"
          jr:preloadParams="name"/>
    </model>
  </h:head>
  <h:body><input ref="/data/name"><label>Name</label></input></h:body>
</h:html>
''';

// greet('Ada') = 'Hello, Ada!'
final class GreetFunction extends XPathFunctionHandler {
  @override
  String get name => 'greet';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      'Hello, ${args.single}!';
}

// Sees every predicate (e.g. to answer some from an index) and hands the
// rest to the next strategy.
final class CountingFilterStrategy implements FilterStrategy {
  int predicates = 0;

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    predicates++;
    return next();
  }
}

// A typed extra attached to the parsed form.
final class QuestionCount {
  QuestionCount(this.count);
  final int count;
}

// Counts the questions while parsing (one processor per parse, as it keeps
// state) and attaches the count to the form.
final class QuestionCounter implements QuestionProcessor, FormDefProcessor {
  int _count = 0;

  @override
  void processQuestion(QuestionDef question) => _count++;

  @override
  void processFormDef(FormDef form) => form.extras.put(QuestionCount(_count));
}

// Runs when a session is finalized.
final class StampFinalization implements FormEntryFinalizationProcessor {
  @override
  void processForm(FormEntryModel model) =>
      model.extras['finalizedBy'] = 'my-app';
}

// jr:preload="app" jr:preloadParams="name"
final class AppPreloadHandler implements PreloadHandler {
  @override
  String get preloadHandled => 'app';

  @override
  AnswerValue? handlePreload(String? params) =>
      params == 'name' ? const StringValue('my-app') : null;

  @override
  bool handlePostProcess(TreeElement node, String? params) => false;
}

// Serves instance('staff') from the app's database instead of the CSV.
final class StaffProvider implements InstanceProvider {
  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      instanceSrc == 'jr://file-csv/staff.csv';

  @override
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) {
    final root = TreeElement('root')..instanceName = instanceId;
    return root..addChild(
      TreeElement('item', 0)
        ..addChild(TreeElement('name')..value = const StringValue('Grace'))
        ..addChild(TreeElement('role')..value = const StringValue('boss')),
    );
  }
}

// motto() reads jr://file/motto.txt, once per form load.
final class MottoPlugin extends FormLoadPlugin {
  const MottoPlugin();

  @override
  Future<void> prepareForm(FormDef form, ResourceResolver resolver) async {
    final motto = utf8.decode(await resolver.read('jr://file/motto.txt'));
    form.addFunctionHandler(_Constant('motto', motto));
  }
}

final class _Constant extends XPathFunctionHandler {
  _Constant(this.name, this.value);

  @override
  final String name;
  final String value;

  @override
  List<List<XPathArgType>> get prototypes => [[]];

  @override
  Object eval(List<Object> args, EvaluationContext context) => value;
}

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  expectSnippetsTested('docs/PLUGINS.md');

  test('every extension point', () async {
    final filter = CountingFilterStrategy();
    final config = DartRosaConfig(
      resolver: MapResourceResolver({
        'jr://file/motto.txt': bytes('Be kind'),
        'jr://file/last-saved.xml': bytes(
          '<data id="plugins"><name>Ada</name></data>',
        ),
      }),
      functions: [GreetFunction()],
      filterStrategies: [filter],
      parseProcessors: [QuestionCounter()],
      finalizationProcessors: [StampFinalization()],
      preloadHandlers: [AppPreloadHandler()],
      externalInstanceParser: ExternalInstanceParser()
        ..addInstanceProvider(StaffProvider()),
      properties: MapPropertyManager({'username': 'ada'}),
      plugins: [const MottoPlugin()],
      lastSavedSrc: 'jr://file/last-saved.xml',
    );

    final definition = await FormDefinition.parse(formXml, config: config);
    final count = definition.formDef.extras.get<QuestionCount>()?.count; // 1

    final session = definition.createSession();
    final name = session.root.children.single as QuestionNode;
    session.answer(name.index, const StringValue('Alan'));
    final draft = session.saveDraft();

    expect(count, 1);
    expect(draft, contains('<greeting>Hello, Alan!</greeting>'));
    expect(draft, contains('<boss>Grace</boss>'));
    expect(draft, contains('<previous>Ada</previous>'));
    expect(draft, contains('<motto>Be kind</motto>'));
    expect(draft, contains('<source>my-app</source>'));
    expect(filter.predicates, greaterThan(0));
    expect(session.finalize(), isA<FinalizeSuccess>());
    expect(session.extras['finalizedBy'], 'my-app');
  });

  test('copyWith', () {
    const base = DartRosaConfig();
    final config = base.copyWith(
      functions: [...base.functions, GreetFunction()],
    );
    expect(config.functions.single, isA<GreetFunction>());
  });
}
