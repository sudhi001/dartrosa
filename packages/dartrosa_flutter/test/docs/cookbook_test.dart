// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The Flutter code of the recipes in docs/cookbook/ (custom widgets,
// theming, translations and right-to-left, device features, layouts), run
// as widget tests so the recipes can't rot (packages/dartrosa/test/docs
// checks that the recipes' snippets are here).
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Feedback</h:title>
    <model>
      <itext>
        <translation lang="English (en)" default="true()">
          <text id="service"><value>How was the service?</value></text>
          <text id="where"><value>Where are you?</value></text>
        </translation>
        <translation lang="Arabic (ar)">
          <text id="service"><value>كيف كانت الخدمة؟</value></text>
          <text id="where"><value>أين أنت؟</value></text>
        </translation>
      </itext>
      <instance><data id="feedback"><service/><where/><code/><photo/></data></instance>
      <bind nodeset="/data/service" type="string" required="true()"/>
      <bind nodeset="/data/where" type="geopoint"/>
      <bind nodeset="/data/code" type="barcode"/>
      <bind nodeset="/data/photo" type="binary"/>
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/service" appearance="likert">
      <label ref="jr:itext('service')"/>
      <item><label>Bad</label><value>1</value></item>
      <item><label>Fair</label><value>2</value></item>
      <item><label>Good</label><value>3</value></item>
    </select1>
    <input ref="/data/where"><label ref="jr:itext('where')"/></input>
    <input ref="/data/code"><label>Ticket</label></input>
    <upload ref="/data/photo" mediatype="image/*"><label>Photo</label></upload>
  </h:body>
</h:html>
''';

// --- Recipe: replace a question widget -----------------------------------

// Stars for a select_one with the appearance "likert": one per choice.
class StarRating extends StatelessWidget {
  const StarRating({required this.node, super.key});

  final QuestionNode node;

  @override
  Widget build(BuildContext context) {
    final controller = XFormScope.of(context).controller;
    final selected = switch (node.value) {
      SelectOneValue(:final selection) => node.choices.indexWhere(
        (choice) => choice.value == selection.value,
      ),
      _ => -1,
    };
    // Set when the last answer (or finalize) was refused.
    final error = controller.errorFor(
      node.index,
      XFormLocalizations.of(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XFormLabel(node.label, required: node.isRequired),
        Row(
          children: [
            for (final (i, choice) in node.choices.indexed)
              IconButton(
                tooltip: node.choiceLabel(choice),
                icon: Icon(i <= selected ? Icons.star : Icons.star_border),
                onPressed: node.isReadonly
                    ? null
                    : () => controller.answer(
                        node.index,
                        SelectOneValue(Selection(choice.value)),
                      ),
              ),
          ],
        ),
        if (error != null)
          Text(
            error,
            style: TextStyle(
              color: XFormTheme.of(context).errorColorOf(context),
            ),
          ),
      ],
    );
  }
}

// Keep the map in a constant or a field: a new map on every build makes
// every question widget rebuild.
final overrides = <String, QuestionWidgetBuilder>{
  'selectOne:likert': (context, node) => StarRating(node: node as QuestionNode),
};

// --- Recipe: theme the form -----------------------------------------------

// The form's spacing, cards and width; colors and text come from
// ThemeData.
const formTheme = XFormTheme(
  pagePadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  questionSpacing: 16,
  cardElevation: 0,
  maxContentWidth: 640, // double.infinity: use the whole width
);

Widget brandedApp(Widget home) => MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: const Color(0xFF00695C), // your brand color
    extensions: const [formTheme],
  ),
  darkTheme: ThemeData(
    colorSchemeSeed: const Color(0xFF00695C),
    brightness: Brightness.dark,
    extensions: const [formTheme],
  ),
  themeMode: ThemeMode.system, // follow the device
  home: home,
);

// --- Recipe: translate the form and support right-to-left ----------------

// A menu of the form's own languages (its translations).
class FormLanguageMenu extends StatelessWidget {
  const FormLanguageMenu({required this.session, super.key});

  final FormSession session;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.translate),
    tooltip: 'Form language',
    // XFormView rebuilds in the new language and direction.
    onSelected: (language) => session.language = language,
    itemBuilder: (context) => [
      for (final language in session.definition.languages)
        CheckedPopupMenuItem(
          value: language,
          checked: language == session.language,
          child: Text(language),
        ),
    ],
  );
}

/// The form language matching [locale], if the form has one. pyxform
/// names languages like `French (fr)`.
String? formLanguageFor(Locale locale, List<String> languages) {
  for (final language in languages) {
    final code = RegExp(r'\(([\w-]+)\)').firstMatch(language)?[1];
    if (code?.split('-').first == locale.languageCode) return language;
  }
  return null;
}

// --- Recipe: connect the camera, location and barcode scanner -------------

/// A geopoint from your location plugin.
typedef Fix = ({double lat, double lon, double altitude, double accuracy});

/// Device features from the plugins your app already uses, passed in as
/// functions so this class doesn't depend on any of them.
class AppDelegates extends XFormDelegates {
  const AppDelegates({
    required this.locate,
    required this.scan,
    required this.takePhoto,
  });

  /// For example geolocator's `Geolocator.getCurrentPosition`.
  final Future<Fix?> Function() locate;

  /// For example a mobile_scanner screen that returns the raw value.
  final Future<String?> Function(BuildContext context) scan;

  /// For example image_picker: saves the picture next to the draft and
  /// returns its file name.
  final Future<String?> Function(String mediaType) takePhoto;

  // Turn on the capture buttons of the features you implement.
  @override
  bool get canLocate => true;

  @override
  bool get canScanBarcode => true;

  @override
  bool get canCaptureMedia => true;

  @override
  Future<String?> currentLocation(BuildContext context) async {
    final fix = await locate();
    if (fix == null) return null;
    // ODK geopoints are "latitude longitude altitude accuracy".
    return '${fix.lat} ${fix.lon} ${fix.altitude} ${fix.accuracy}';
  }

  @override
  Future<String?> scanBarcode(BuildContext context) => scan(context);

  @override
  Future<String?> captureMedia(
    BuildContext context, {
    required String mediaType,
    String? appearance,
  }) => takePhoto(mediaType);
}

// --- Recipe: choose pager, scroll or outline ------------------------------

// One question per screen on phones; the whole form on one page where
// there is room.
XFormMode modeFor(BuildContext context) =>
    XFormWindowSize.of(context) >= XFormWindowSize.expanded
    ? XFormMode.scroll
    : XFormMode.pager;

class OutlinedFormPage extends StatefulWidget {
  const OutlinedFormPage({required this.session, super.key});

  final FormSession session;

  @override
  State<OutlinedFormPage> createState() => _OutlinedFormPageState();
}

class _OutlinedFormPageState extends State<OutlinedFormPage> {
  final _form = GlobalKey<XFormViewState>();
  late final XFormMode _mode = modeFor(context);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.session.definition.title ?? ''),
      actions: [
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'Outline',
          // Every group and question, with its state; tap one to go there.
          onPressed: () => _form.currentState?.showOutline(),
        ),
      ],
    ),
    body: XFormView(
      key: _form,
      session: widget.session,
      mode: _mode, // chosen once, so the person keeps their place
      outline: XFormOutlineMode.onRequest, // no side panel
    ),
  );
}

Future<FormSession> openForm(WidgetTester tester) async {
  final definition = await tester.runAsync(() => FormDefinition.parse(formXml));
  return definition!.createSession();
}

void main() {
  testWidgets('a star rating replaces the likert select', (tester) async {
    final session = await openForm(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XFormView(
            session: session,
            mode: XFormMode.scroll,
            widgetOverrides: overrides,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.star_border), findsNWidgets(3));
    await tester.tap(find.byTooltip('Fair'));
    await tester.pump();
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    final service = session.root.children.first as QuestionNode;
    expect(service.value?.displayText, '2');
  });

  testWidgets('the star rating shows the required error', (tester) async {
    final session = await openForm(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XFormView(
            session: session,
            mode: XFormMode.scroll,
            widgetOverrides: overrides,
          ),
        ),
      ),
    );
    final service = session.root.children.first as QuestionNode;
    XFormScope.of(
      tester.element(find.byType(StarRating)),
    ).controller.answer(service.index, null);
    await tester.pump();
    expect(find.text(const XFormLocalizations().requiredDefault), findsWidgets);
  });

  testWidgets('a branded light and dark theme', (tester) async {
    final session = await openForm(tester);
    await tester.pumpWidget(
      brandedApp(Scaffold(body: XFormView(session: session))),
    );
    final context = tester.element(find.byType(XFormView));
    expect(XFormTheme.of(context).maxContentWidth, 640);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    final dark = tester.element(find.byType(XFormView));
    expect(Theme.of(dark).brightness, Brightness.dark);
    expect(XFormTheme.of(dark).questionSpacing, 16);
  });

  testWidgets('one form with its own error color', (tester) async {
    final session = await openForm(tester);
    late Color? color;
    await tester.pumpWidget(
      brandedApp(
        Builder(
          builder: (context) {
            final themed =
                // A different look for one form only.
                Theme(
                  data: Theme.of(context).copyWith(
                    extensions: [
                      XFormTheme.of(
                        context,
                      ).copyWith(errorColor: Colors.deepOrange),
                    ],
                  ),
                  child: XFormView(session: session),
                );
            return Scaffold(body: themed);
          },
        ),
      ),
    );
    color = XFormTheme.of(tester.element(find.byType(XFormView))).errorColor;
    expect(color, Colors.deepOrange);
  });

  testWidgets('switching to Arabic lays the form out right to left', (
    tester,
  ) async {
    final session = await openForm(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [FormLanguageMenu(session: session)]),
          body: XFormView(session: session, mode: XFormMode.scroll),
        ),
      ),
    );
    expect(
      find.textContaining('How was the service?', findRichText: true),
      findsOne,
    );
    await tester.tap(find.byTooltip('Form language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arabic (ar)'));
    await tester.pumpAndSettle();
    expect(session.language, 'Arabic (ar)');
    expect(
      find.textContaining('كيف كانت الخدمة؟', findRichText: true),
      findsOne,
    );
    final label = tester.element(
      find.textContaining('أين أنت؟', findRichText: true),
    );
    expect(Directionality.of(label), TextDirection.rtl);
    expect(textDirectionOfLanguage('Arabic (ar)'), TextDirection.rtl);
  });

  test('the form language for a locale', () {
    const languages = ['English (en)', 'Arabic (ar)'];
    expect(formLanguageFor(const Locale('ar', 'EG'), languages), 'Arabic (ar)');
    expect(formLanguageFor(const Locale('fr'), languages), isNull);
  });

  testWidgets('delegates fill location, barcode and photo', (tester) async {
    final session = await openForm(tester);
    final delegates = AppDelegates(
      locate: () async =>
          (lat: -1.29, lon: 36.82, altitude: 1661.0, accuracy: 5.0),
      scan: (context) async => 'T-42',
      takePhoto: (mediaType) async => 'photo-1.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XFormView(
            session: session,
            mode: XFormMode.scroll,
            delegates: delegates,
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(XFormView));
    expect(await delegates.currentLocation(context), '-1.29 36.82 1661.0 5.0');
    expect(await delegates.scanBarcode(context), 'T-42');
    expect(
      await delegates.captureMedia(context, mediaType: 'image/*'),
      'photo-1.jpg',
    );
  });

  testWidgets('scroll on wide windows, pager on phones, outline on demand', (
    tester,
  ) async {
    final session = await openForm(tester);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: OutlinedFormPage(session: session)),
    );
    final view = tester.widget<XFormView>(find.byType(XFormView));
    expect(view.mode, XFormMode.scroll);
    await tester.tap(find.byTooltip('Outline'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOne);
  });

  testWidgets('pager on a phone', (tester) async {
    final session = await openForm(tester);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: OutlinedFormPage(session: session)),
    );
    final view = tester.widget<XFormView>(find.byType(XFormView));
    expect(view.mode, XFormMode.pager);
  });
}
