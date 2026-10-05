# Quick start: a form on screen in five minutes

**Audience:** Flutter developers trying DartRosa for the first time.
**Type:** tutorial. **Time:** 5 minutes.

You will create a Flutter app that shows an ODK form, checks the answers
as they are typed and prints the finished submission. No server is
needed. The app is run by
`packages/dartrosa_flutter/test/docs/quickstart_test.dart`, so the code
below works as written.

## 1. Create the app

```sh
flutter create visit_app
cd visit_app
flutter pub add dartrosa_flutter
```

`dartrosa_flutter` brings the engine (`dartrosa`) with it. It needs
Flutter 3.35 or later and runs on Android, iOS, the web, macOS, Windows
and Linux.

## 2. Add a form

ODK forms are usually written as spreadsheets ([XLSForm](https://xlsform.org))
and converted to XML; the [tutorial](tutorials/build-a-data-collection-app.md)
shows how. For now, save this XML as `assets/visit.xml`:

```xml
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance>
        <data id="visit">
          <name/><age/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string" required="true()"/>
      <bind nodeset="/data/age" type="int" constraint=". &gt;= 18"
          jr:constraintMsg="Only adults can take part"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>What is your name?</label></input>
    <input ref="/data/age"><label>How old are you?</label></input>
  </h:body>
</h:html>
```

and list it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/visit.xml
```

## 3. Show it

Replace `lib/main.dart` with:

```dart
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final xml = await rootBundle.loadString('assets/visit.xml');
  final definition = await FormDefinition.parse(xml);
  runApp(QuickStartApp(session: definition.createSession()));
}

class QuickStartApp extends StatelessWidget {
  const QuickStartApp({required this.session, super.key});

  final FormSession session;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: Scaffold(
      appBar: AppBar(title: Text(session.definition.title ?? 'Form')),
      body: XFormView(
        session: session,
        onFinalized: (submission) {
          // The finished form, ready to save or upload.
          debugPrint(submission.xml);
        },
      ),
    ),
  );
}
```

## 4. Run it

```sh
flutter run
```

You get one question per screen, as in ODK Collect. Try to go past the
name without typing one: the form says it is required. Enter an age of
16: "Only adults can take part". On the last screen, **Finalize** prints
the submission XML, with a generated `instanceID`, to the console.

What happened:

* `FormDefinition.parse` read the form: its questions and rules.
* `createSession()` started one filling of it.
* `XFormView` drew the questions and ran the rules on every answer, with
  the same results as ODK Collect.

## Next

* [Concepts](CONCEPTS.md): definitions, sessions, nodes and rules, in ten
  minutes.
* [Tutorial: build a data-collection app](tutorials/build-a-data-collection-app.md):
  from a spreadsheet to submissions on ODK Central, with drafts and
  encryption.
* [Cookbook](cookbook/README.md): theming, custom widgets, translations,
  camera and GPS.
* No Flutter? The engine runs in plain Dart too:
  [Getting started](GETTING_STARTED.md).
