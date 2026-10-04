// Sibling groups without a `ref` get the same widget key. Fails today;
// run with `--dart-define=KNOWN_ISSUES=true`.
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _run = bool.fromEnvironment('KNOWN_ISSUES');

// Reduced from conformance/forms/collect/form8.xml.
const _form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>Groups</h:title><model>
    <instance><data id="g"><a/><b/></data></instance>
  </model></h:head>
  <h:body><group appearance="field-list"><label>Outer</label>
    <group><label>First</label><input ref="/data/a"><label>A</label></input></group>
    <group><label>Second</label><input ref="/data/b"><label>B</label></input></group>
  </group></h:body>
</h:html>''';

void main() {
  // Reason: nodeWidget() keys a GroupWidget with ValueKey('g:${node.ref}');
  // a group without `ref` has its parent's reference (here /data), so
  // sibling ref-less groups inside a group collide:
  // "Duplicate keys found ... [<'g:/data'>]", then "Looking up a
  // deactivated widget's ancestor is unsafe". The key should come from
  // the node's FormIndex.
  testWidgets('sibling groups without ref build', skip: !_run, (tester) async {
    final session = (await tester.runAsync(
      () => FormDefinition.parse(_form),
    ))!.createSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XFormView(session: session, mode: XFormMode.scroll),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Second'), findsOneWidget);
  });
}
