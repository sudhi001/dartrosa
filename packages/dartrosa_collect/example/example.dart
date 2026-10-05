// Loads a form the way ODK Collect does: the last-saved instance
// pre-fills the next one, and editing a finalized submission gives it a
// new instanceID (the old one becomes deprecatedID).
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';

const xform = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance>
        <data id="visit"><village/><meta><instanceID/></meta></data>
      </instance>
      <instance id="__last-saved" src="jr://instance/last-saved"/>
      <bind nodeset="/data/village" type="string"/>
      <bind nodeset="/data/meta/instanceID" type="string" jr:preload="uid"/>
      <setvalue event="odk-instance-first-load" ref="/data/village"
          value="instance('__last-saved')/data/village"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/village"><label>Village</label></input>
  </h:body>
</h:html>
''';

Future<void> main() async {
  final lastSaved = LastSaved(InMemoryLastSavedStore(), 'visit-v1');
  final config = collectFormConfig(
    media: MapResourceResolver(const {}), // the form's media files
    lastSaved: lastSaved,
  );

  // First visit: answer and save.
  var session = (await FormDefinition.parse(
    xform,
    config: config,
  )).createSession();
  final village = session.root.children.whereType<QuestionNode>().single;
  session.answer(village.index, const StringValue('Kisumu'));
  final submission = (session.finalize() as FinalizeSuccess).submission;
  await lastSaved.instanceSaved(session);

  // Second visit: pre-filled from the last-saved instance.
  session = (await FormDefinition.parse(xform, config: config)).createSession();
  _log(session.saveDraft().contains('<village>Kisumu</village>')); // true

  // Editing the finalized submission.
  session = (await FormDefinition.parse(
    xform,
    config: config,
  )).createSession(existingInstance: submission.xml);
  const InstanceEdit(editOf: 1).markSession(session);
  final edited = (session.finalize() as FinalizeSuccess).submission;
  _log('${submission.instanceId} -> ${edited.instanceId}');
  _log(edited.xml.contains('<deprecatedID>')); // true
}

// ignore: avoid_print
void _log(Object? message) => print(message);
