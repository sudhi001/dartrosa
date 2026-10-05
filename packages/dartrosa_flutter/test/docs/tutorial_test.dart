// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The Flutter code of docs/tutorials/build-a-data-collection-app.md, run as
// widget tests so the tutorial can't rot (packages/dartrosa/test/docs checks
// that its snippets are here or in
// packages/dartrosa_openrosa/test/docs/tutorial_test.dart).
import 'dart:typed_data';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tutorial's form, as pyxform converts it (trimmed).
const visitXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms">
  <h:head>
    <h:title>Household visit</h:title>
    <model>
      <instance>
        <data id="household_visit" version="2026100501">
          <village/><head_name/><members/><has_water/><water_source/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <instance id="villages" src="jr://file-csv/villages.csv"/>
      <bind nodeset="/data/village" type="string" required="true()"/>
      <bind nodeset="/data/head_name" type="string" required="true()"/>
      <bind nodeset="/data/members" type="int" required="true()"
          constraint=". &gt; 0 and . &lt; 30"
          jr:constraintMsg="Between 1 and 29"/>
      <bind nodeset="/data/has_water" type="string" required="true()"/>
      <bind nodeset="/data/water_source" type="string"
          relevant="/data/has_water = 'yes'"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/village"><label>Village</label>
      <itemset nodeset="instance('villages')/root/item">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
    <input ref="/data/head_name"><label>Name of the household head</label></input>
    <input ref="/data/members"><label>How many people live here?</label></input>
    <select1 ref="/data/has_water"><label>Is there drinking water?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
    <input ref="/data/water_source"><label>Where does it come from?</label></input>
  </h:body>
</h:html>
''';

/// What the app keeps: forms with their media, drafts, files and the
/// outbox. This one lives in memory; a real app writes files under
/// getApplicationDocumentsDirectory() or uses a database.
class FormStore {
  /// Form id -> its XML and media files (file name -> bytes).
  final forms = <String, ({String xml, Map<String, Uint8List> media})>{};

  /// Draft id -> the instance XML from saveDraft().
  final drafts = <String, String>{};

  /// Photos, signatures and recordings, by file name.
  final files = <String, Uint8List>{};

  /// instanceID -> a finalized submission waiting to be sent.
  final outbox = <String, ({String formId, Submission submission})>{};
}

/// Serves a form's media files (jr://file-csv/villages.csv, ...) from
/// memory.
class StoredMediaResolver implements ResourceResolver {
  StoredMediaResolver(this.media);

  final Map<String, Uint8List> media;

  @override
  Future<Uint8List> read(String uri) async =>
      media[Uri.parse(uri).pathSegments.last] ??
      (throw ResourceNotFoundException(uri));
}

/// Parses the stored form [formId].
Future<FormDefinition> loadForm(FormStore store, String formId) {
  final form = store.forms[formId]!;
  return FormDefinition.parse(
    form.xml,
    config: DartRosaConfig(resolver: StoredMediaResolver(form.media)),
  );
}

/// Opens a new visit, or continues the draft [draftId].
Future<FormSession> openVisit(
  FormStore store,
  String formId, {
  String? draftId,
}) async {
  final definition = await loadForm(store, formId);
  return definition.createSession(
    existingInstance: draftId == null ? null : store.drafts[draftId],
  );
}

class VisitPage extends StatefulWidget {
  const VisitPage({
    required this.store,
    required this.formId,
    required this.draftId,
    required this.session,
    super.key,
  });

  final FormStore store;
  final String formId;
  final String draftId;
  final FormSession session;

  @override
  State<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends State<VisitPage> with WidgetsBindingObserver {
  var _finalized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The system may stop a paused app: save first.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _saveDraft();
  }

  void _saveDraft() {
    if (_finalized) return;
    widget.store.drafts[widget.draftId] = widget.session.saveDraft();
  }

  void _finalize(Submission submission) {
    _finalized = true;
    widget.store.drafts.remove(widget.draftId);
    widget.store.outbox[submission.instanceId!] = (
      formId: widget.formId,
      submission: submission,
    );
    Navigator.of(context).pop(submission);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving with the back button keeps what was entered.
    onPopInvokedWithResult: (didPop, result) => _saveDraft(),
    child: Scaffold(
      appBar: AppBar(title: Text(widget.session.definition.title ?? '')),
      body: XFormView(
        session: widget.session,
        // Camera, GPS, barcodes: see the cookbook's device recipe.
        delegates: const NoDelegates(),
        onFinalized: _finalize,
      ),
    ),
  );
}

FormStore storeWithVisitForm() => FormStore()
  ..forms['household_visit'] = (
    xml: visitXml,
    media: {
      'villages.csv': Uint8List.fromList(
        'name,label\nkib,Kibera\nmat,Mathare\n'.codeUnits,
      ),
    },
  );

void main() {
  testWidgets('a visit is kept as a draft when the person leaves', (
    tester,
  ) async {
    final store = storeWithVisitForm();
    final session = (await tester.runAsync(
      () => openVisit(store, 'household_visit'),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Submission>(
                builder: (_) => VisitPage(
                  store: store,
                  formId: 'household_visit',
                  draftId: 'visit-1',
                  session: session,
                ),
              ),
            ),
            child: const Text('New visit'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New visit'));
    await tester.pumpAndSettle();
    expect(find.text('Kibera'), findsOne);

    await tester.tap(find.text('Kibera'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(store.drafts['visit-1'], contains('<village>kib</village>'));

    final resumed = (await tester.runAsync(
      () => openVisit(store, 'household_visit', draftId: 'visit-1'),
    ))!;
    final village = resumed.root.children.first as QuestionNode;
    expect(village.value?.displayText, 'kib');
  });

  testWidgets('a draft is saved when the app is paused', (tester) async {
    final store = storeWithVisitForm();
    final session = (await tester.runAsync(
      () => openVisit(store, 'household_visit'),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: VisitPage(
          store: store,
          formId: 'household_visit',
          draftId: 'visit-2',
          session: session,
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(store.drafts, contains('visit-2'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('finalizing moves the visit to the outbox', (tester) async {
    final store = storeWithVisitForm();
    final session = (await tester.runAsync(
      () => openVisit(store, 'household_visit'),
    ))!;
    final [village, name, members, water, _] = session.root.children
        .cast<QuestionNode>();
    session
      ..answer(village.index, const SelectOneValue(Selection('kib')))
      ..answer(name.index, const StringValue('Amina'))
      ..answer(members.index, const IntegerValue(4))
      ..answer(water.index, const SelectOneValue(Selection('no')));
    store.drafts['visit-3'] = session.saveDraft();
    await tester.pumpWidget(
      MaterialApp(
        home: VisitPage(
          store: store,
          formId: 'household_visit',
          draftId: 'visit-3',
          session: session,
        ),
      ),
    );
    // Walk to the end of the pager and finalize.
    const strings = XFormLocalizations();
    for (
      var i = 0;
      i < 10 && find.text(strings.finalize).evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(strings.finalize).last);
    await tester.pumpAndSettle();

    expect(store.outbox, hasLength(1));
    expect(store.drafts, isNot(contains('visit-3')));
  });

  testWidgets('the pager refuses 40 members', (tester) async {
    final store = storeWithVisitForm();
    final session = (await tester.runAsync(
      () => openVisit(store, 'household_visit'),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: XFormView(session: session)),
      ),
    );
    final members = session.root.children[2] as QuestionNode;
    session.navigator.jumpTo(members.index);
    final result = session.answer(members.index, const IntegerValue(40));
    expect(result, isA<AnswerConstraintViolated>());
  });
}
