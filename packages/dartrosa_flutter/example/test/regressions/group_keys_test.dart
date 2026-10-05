// Sibling groups without a `ref` used to get the same widget key (it came
// from the instance reference, which they share with their parent);
// widgets are now keyed by FormIndex.
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('sibling groups without ref build', (tester) async {
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
