// Showing a select with an itemset asserts in debug builds. Fails today;
// run with `--dart-define=KNOWN_ISSUES=true`.
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _run = bool.fromEnvironment('KNOWN_ISSUES');

const _form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>Itemset</h:title><model>
    <instance><data id="i"><pick/></data></instance>
    <instance id="list"><root>
      <item><name>a</name><label>A</label></item>
      <item><name>b</name><label>B</label></item>
    </root></instance>
    <bind nodeset="/data/pick" type="string"/>
  </model></h:head>
  <h:body>
    <select1 ref="/data/pick"><label>Pick</label>
      <itemset nodeset="instance('list')/root/item">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
  </h:body>
</h:html>''';

void main() {
  const reason =
      'Reading QuestionNode.choices of an itemset select runs '
      'ItemsetBinding.getChoices, which publishes the debug '
      "EvaluationEvent('Dynamic choices'); FormSession._onEvaluation "
      'forwards it '
      "as a 'condition' FormChange, and XFormController notifies the "
      "question's ListenableBuilder while SelectOneInput.build runs: "
      '"setState() or markNeedsBuild() called during build" (debug '
      'builds). Reading choices should not emit a change, or the '
      'controller should defer notifications raised during build.';

  test(
    'reading the choices of an itemset select changes nothing',
    skip: _run ? false : reason,
    () async {
      final session = (await FormDefinition.parse(_form)).createSession();
      final changes = <FormChange>[];
      session.changes.listen(changes.add);
      final select = session.root.children.single as QuestionNode;
      expect(select.choices, hasLength(2));
      expect(changes, isEmpty);
    },
  );

  // testWidgets only takes a bool: the reason is the one above.
  testWidgets('an itemset select builds without errors', skip: !_run, (
    tester,
  ) async {
    final session = (await tester.runAsync(
      () => FormDefinition.parse(_form),
    ))!.createSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: XFormView(session: session)),
      ),
    );
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
