// Fills an XForm with dartrosa_flutter. Add platforms with
// `flutter create .` in this directory, then `flutter run`.
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';

const _form = '''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household survey</h:title>
    <model>
      <instance>
        <data id="household">
          <name/><age/><adult/><members/>
          <member><mname/><mage/></member>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 0 and . &lt; 130"
          jr:constraintMsg="Enter an age between 0 and 129"/>
      <bind nodeset="/data/adult" type="string" relevant="/data/age &gt;= 18"/>
      <bind nodeset="/data/members" type="int"
          calculate="count(/data/member)"/>
      <bind nodeset="/data/member/mname" type="string"/>
      <bind nodeset="/data/member/mage" type="int"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Your name</label></input>
    <input ref="/data/age"><label>Your age</label></input>
    <select1 ref="/data/adult"><label>Do you vote?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <group><label>Household members</label>
      <repeat nodeset="/data/member">
        <input ref="/data/member/mname"><label>Member name</label></input>
        <input ref="/data/member/mage"><label>Member age</label></input>
      </repeat>
    </group>
  </h:body>
</h:html>''';

void main() => runApp(const ExampleApp());

/// The example app.
class ExampleApp extends StatelessWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DartRosa',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const FormScreen(),
  );
}

/// Loads the form and shows it.
class FormScreen extends StatefulWidget {
  /// Creates the screen.
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final Future<FormSession> _session = FormDefinition.parse(
    _form,
  ).then((definition) => definition.createSession());
  var _mode = XFormMode.pager;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Household survey'),
      actions: [
        IconButton(
          tooltip: 'Switch layout',
          icon: Icon(
            _mode == XFormMode.pager ? Icons.view_agenda : Icons.view_carousel,
          ),
          onPressed: () => setState(
            () => _mode = _mode == XFormMode.pager
                ? XFormMode.scroll
                : XFormMode.pager,
          ),
        ),
      ],
    ),
    body: FutureBuilder(
      future: _session,
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return XFormView(
          key: ValueKey(_mode),
          session: session,
          mode: _mode,
          onFinalized: (submission) => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Submission'),
              content: SingleChildScrollView(child: Text(submission.xml)),
            ),
          ),
        );
      },
    ),
  );
}
