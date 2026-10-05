// The code of docs/guides/render-a-form-in-flutter.md, run as widget tests
// so the guide can't rot (packages/dartrosa/test/docs checks that the
// guide's snippets are here).
import 'dart:io';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance><data id="visit"><name/><town/></data></instance>
      <instance id="towns" src="jr://file-csv/towns.csv"/>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/town" type="string"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Your name</label></input>
    <select1 ref="/data/town">
      <label>Town</label>
      <itemset nodeset="instance('towns')/root/item">
        <value ref="name"/><label ref="label"/>
      </itemset>
    </select1>
  </h:body>
</h:html>
''';

// Serves jr://file/..., jr://file-csv/... and jr://images/... from the
// folder the form's media files were downloaded to.
class MediaFolderResolver implements ResourceResolver {
  MediaFolderResolver(this.folder);

  final Directory folder;

  @override
  Future<Uint8List> read(String uri) async {
    final file = File('${folder.path}/${Uri.parse(uri).pathSegments.last}');
    if (!file.existsSync()) throw ResourceNotFoundException(uri);
    return file.readAsBytes();
  }
}

Future<FormSession> openForm(String formXml, Directory media) async {
  final definition = await FormDefinition.parse(
    formXml,
    config: DartRosaConfig(resolver: MediaFolderResolver(media)),
  );
  return definition.createSession();
}

// Images in labels come from the media folder. Capture questions would
// open the camera, a file picker, a location service and so on.
class MyDelegates extends XFormDelegates {
  const MyDelegates(this.media);

  final Directory media;

  File _file(String uri) =>
      File('${media.path}/${Uri.parse(uri).pathSegments.last}');

  @override
  ImageProvider? image(String uri) {
    final file = _file(uri);
    return file.existsSync() ? FileImage(file) : null;
  }

  @override
  Future<Uint8List?> mediaBytes(String uri) async {
    final file = _file(uri);
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) async {
    // Take a photo or pick a file (mediaType is image/*, audio/*, ...),
    // save it next to the instance and return its file name; null if
    // the user cancels.
    return null;
  }
}

class FormPage extends StatelessWidget {
  const FormPage({required this.session, required this.media, super.key});

  final FormSession session;
  final Directory media;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(session.definition.title ?? '')),
    body: XFormView(
      session: session,
      delegates: MyDelegates(media),
      onFinalized: (submission) {
        // Store submission.xml and its attachments, then leave the form.
        Navigator.of(context).pop(submission);
      },
    ),
  );
}

// French button labels; every string has an English default.
class FrenchXFormLocalizations extends XFormLocalizations {
  const FrenchXFormLocalizations();

  @override
  String get next => 'Suivant';

  @override
  String get back => 'Retour';
}

class FrenchXFormLocalizationsDelegate
    extends LocalizationsDelegate<XFormLocalizations> {
  const FrenchXFormLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';

  @override
  Future<XFormLocalizations> load(Locale locale) =>
      SynchronousFuture(const FrenchXFormLocalizations());

  @override
  bool shouldReload(FrenchXFormLocalizationsDelegate old) => false;
}

Widget buildApp(FormSession session, Directory media) => MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: Colors.indigo,
    extensions: const [XFormTheme(pagePadding: EdgeInsets.all(24))],
  ),
  locale: const Locale('fr'),
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: const [
    FrenchXFormLocalizationsDelegate(),
    // From flutter_localizations, for Flutter's own widgets.
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: FormPage(session: session, media: media),
);

class StarRating extends StatelessWidget {
  const StarRating({required this.node, super.key});

  final QuestionNode node;

  @override
  Widget build(BuildContext context) => Text('${node.label.text}: ★★★☆☆');
}

Widget scrollView(FormSession session) => XFormView(
  session: session,
  mode: XFormMode.scroll, // every question on one page
  widgetOverrides: {
    // Your widget for every select_one with appearance "likert".
    'selectOne:likert': (context, node) =>
        StarRating(node: node as QuestionNode),
  },
);

void main() {
  late Directory media;

  setUp(() {
    media = Directory.systemTemp.createTempSync('dartrosa_media');
    File(
      '${media.path}/towns.csv',
    ).writeAsStringSync('name,label\nnbo,Nairobi\nmsa,Mombasa\n');
  });

  tearDown(() => media.deleteSync(recursive: true));

  testWidgets('a form with CSV media in a French app', (tester) async {
    final session = (await tester.runAsync(() => openForm(formXml, media)))!;
    final town = session.root.children[1] as QuestionNode;
    expect([for (final c in town.choices) c.value], ['nbo', 'msa']);

    await tester.pumpWidget(buildApp(session, media));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your name', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Suivant'), findsOneWidget);

    // The required question blocks the next screen until it is answered.
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your name', findRichText: true),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Amina');
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Nairobi', findRichText: true), findsOneWidget);
  });

  testWidgets('a missing media file is ResourceNotFoundException', (
    tester,
  ) async {
    final resolver = MediaFolderResolver(media);
    await tester.runAsync(() async {
      expect(
        () => resolver.read('jr://file/missing.csv'),
        throwsA(isA<ResourceNotFoundException>()),
      );
      final bytes = await resolver.read('jr://file-csv/towns.csv');
      expect(bytes, isNotEmpty);
    });
    expect(MyDelegates(media).image('jr://images/x.png'), isNull);
  });

  testWidgets('widget overrides in scroll mode', (tester) async {
    final definition = (await tester.runAsync(
      () => FormDefinition.parse('''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>Rate</h:title><model>
    <instance><data id="rate"><q/></data></instance>
    <bind nodeset="/data/q" type="string"/>
  </model></h:head>
  <h:body>
    <select1 ref="/data/q" appearance="likert"><label>Service</label>
      <item><label>Good</label><value>good</value></item>
    </select1>
  </h:body>
</h:html>'''),
    ))!;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: scrollView(definition.createSession()))),
    );
    expect(find.text('Service: ★★★☆☆', findRichText: true), findsOneWidget);
  });
}
