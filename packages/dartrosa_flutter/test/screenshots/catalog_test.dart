// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Renders the images of the widget catalog (docs/widgets/) into
// docs/images/screenshots/widgets/, from the purpose-built forms in
// test/screenshots/forms/.
//
// Like screenshots_test.dart it is skipped unless DARTROSA_SCREENSHOTS is
// set, and runs on macOS only. From packages/dartrosa_flutter:
//
//   DARTROSA_SCREENSHOTS=1 flutter test test/screenshots/catalog_test.dart
//   python3 test/screenshots/optimize_pngs.py ../../docs/images/screenshots/widgets
//
// Two kinds of image:
// * crops: a form is shown in scroll mode in a phone-wide, very tall
//   window and each image is the band of the screen holding some of its
//   questions (by name), so every image of a control family comes from
//   one form;
// * screens: a whole phone (or tablet, desktop) window, for dialogs,
//   pickers, the pager and the outline.
@Tags(['screenshots'])
@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The height of the window crops are taken from: enough for a whole
/// form to be built.
const _cropWindowHeight = 4000.0;

final Directory _out = Directory('${docsImages.path}/screenshots/widgets');

/// Choice images, drawn in `setUpAll`.
Map<String, Uint8List> _images = const {};

/// Which delegates a form is shown with.
enum _Platform {
  /// Every platform feature ([DemoDelegates]).
  full,

  /// None ([NoDelegates]): capture questions are typed.
  none,

  /// External apps that are not installed.
  missingApps,
}

XFormDelegates _delegates(_Platform platform) => switch (platform) {
  _Platform.full => DemoDelegates(_images),
  _Platform.none => const NoDelegates(),
  _Platform.missingApps => _MissingApps(_images),
};

/// [DemoDelegates] whose external apps are not installed.
class _MissingApps extends DemoDelegates {
  const _MissingApps(super.images);

  @override
  Future<Map<String, Object?>?> launchExternalApp(
    BuildContext context, {
    required String intent,
    required Map<String, Object?> params,
    String? data,
  }) async => throw const ExternalAppNotFoundException();
}

/// The controller of the form on screen.
XFormController _controller(WidgetTester tester) =>
    XFormScope.of(tester.element(find.byType(QuestionWidget).first)).controller;

/// The widget of the node named [name] of [session].
Finder _nodeFinder(FormSession session, String name) =>
    find.byKey(nodeKey(nodeNamed<FormNode>(session.root, name)));

/// Types [text] into the text field of the question named [name].
Future<void> typeInto(
  WidgetTester tester,
  FormSession session,
  String name,
  String text,
) async {
  final field = find.descendant(
    of: _nodeFinder(session, name),
    matching: find.byType(TextField),
  );
  await tester.enterText(field.first, text);
  await tester.pump();
}

/// Taps [finder] inside the node named [name].
Future<void> tapIn(
  WidgetTester tester,
  FormSession session,
  String name,
  Finder finder,
) async {
  await tester.tap(
    find.descendant(of: _nodeFinder(session, name), matching: finder).first,
  );
  await tester.pumpAndSettle();
}

/// A form shown in scroll mode, cut into images of some of its nodes.
class _Crops {
  const _Crops(
    this.form, {
    required this.crops,
    this.dark = const {},
    this.typed = const {},
    this.act,
    this.platform = _Platform.full,
    this.suffix = '',
  });

  /// The form, forms/[form].xml.
  final String form;

  /// Image names and the names of the nodes each shows (from the first
  /// to the last).
  final Map<String, List<String>> crops;

  /// The crops also rendered in the dark theme (`<name>_dark.png`).
  final Set<String> dark;

  /// Text typed into questions, by question name (rejected answers
  /// show their errors).
  final Map<String, String> typed;

  /// More to do before the images are taken.
  final Future<void> Function(WidgetTester tester, FormSession session)? act;

  /// The delegates.
  final _Platform platform;

  /// Tells apart test names of the same form shown differently.
  final String suffix;
}

Future<void> _renderCrops(
  WidgetTester tester,
  _Crops spec,
  Brightness brightness,
) async {
  tester.view
    ..physicalSize = Size(phone.width, _cropWindowHeight) * docsPixelRatio
    ..devicePixelRatio = docsPixelRatio;
  addTearDown(tester.view.reset);
  final session = (await tester.runAsync(() => loadCatalogForm(spec.form)))!;
  final boundary = GlobalKey();
  await tester.pumpWidget(
    screenshotApp(
      boundary: boundary,
      brightness: brightness,
      home: Scaffold(
        body: XFormView(
          session: session,
          mode: XFormMode.scroll,
          delegates: _delegates(spec.platform),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await precacheScreenImages(tester);
  await tester.pumpAndSettle();

  // Required questions left empty (named `*required*`) get their error,
  // as when Next or Finalize is tapped.
  final controller = _controller(tester);
  for (final q in questionsUnder(session.root)) {
    if (q.index.reference.toString().contains('required')) {
      controller.answer(q.index, q.value);
    }
  }
  await tester.pump();
  for (final MapEntry(key: name, value: text) in spec.typed.entries) {
    await typeInto(tester, session, name, text);
  }
  await spec.act?.call(tester, session);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await precacheScreenImages(tester);
  await tester.pumpAndSettle();

  final dark = brightness == Brightness.dark;
  for (final MapEntry(key: image, value: names) in spec.crops.entries) {
    if (dark && !spec.dark.contains(image)) continue;
    final region = spanOf([
      for (final name in names)
        rectIn(tester, boundary, _nodeFinder(session, name)),
    ], width: phone.width);
    final bytes = await capturePng(
      tester,
      boundary,
      pixelRatio: docsPixelRatio,
      region: region,
    );
    writeImage(File('${_out.path}/$image${dark ? '_dark' : ''}.png'), bytes);
  }
}

/// A whole window.
class _Screen {
  const _Screen(
    this.name,
    this.form, {
    this.mode = XFormMode.pager,
    this.size = phone,
    this.pixelRatio = docsPixelRatio,
    this.prepare,
    this.act,
    this.dark = false,
    this.textScale = 1,
    this.cropTo,
  });

  final String name;

  /// What the image shows (padded), if not the whole window: e.g. the
  /// dialog.
  final Finder Function()? cropTo;

  /// The form, forms/[form].xml.
  final String form;
  final XFormMode mode;
  final Size size;
  final double pixelRatio;

  /// Changes the session before it is shown (answers, the screen).
  final void Function(FormSession session)? prepare;

  /// What to do once it is shown (taps opening dialogs, ...).
  final Future<void> Function(WidgetTester tester, FormSession session)? act;

  /// Whether a dark-theme image is rendered too.
  final bool dark;
  final double textScale;
}

Future<void> _renderScreen(
  WidgetTester tester,
  _Screen spec,
  Brightness brightness,
) async {
  tester.view
    ..physicalSize = spec.size * spec.pixelRatio
    ..devicePixelRatio = spec.pixelRatio;
  addTearDown(tester.view.reset);
  final session = (await tester.runAsync(() => loadCatalogForm(spec.form)))!;
  spec.prepare?.call(session);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    screenshotApp(
      boundary: boundary,
      brightness: brightness,
      textScale: spec.textScale,
      home: Scaffold(
        appBar: AppBar(title: Text(session.definition.title ?? '')),
        body: XFormView(
          session: session,
          mode: spec.mode,
          delegates: DemoDelegates(_images),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await precacheScreenImages(tester);
  await tester.pumpAndSettle();
  await spec.act?.call(tester, session);
  await tester.pumpAndSettle();
  await precacheScreenImages(tester);
  await tester.pumpAndSettle();
  final cropTo = spec.cropTo;
  final bytes = await capturePng(
    tester,
    boundary,
    pixelRatio: spec.pixelRatio,
    region: cropTo == null ? null : rectIn(tester, boundary, cropTo()),
  );
  final dark = brightness == Brightness.dark ? '_dark' : '';
  writeImage(File('${_out.path}/${spec.name}$dark.png'), bytes);
}

/// Jumps the pager to the question or group named [name].
void Function(FormSession) _at(String name) =>
    (s) => s.navigator.jumpTo(nodeNamed<FormNode>(s.root, name).index);

/// Taps the text [text] (the first match) and settles.
Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Taps Next until [text] is shown.
Future<void> _nextUntil(WidgetTester tester, String text) async {
  for (var i = 0; i < 20 && find.text(text).evaluate().isEmpty; i++) {
    await _tapText(tester, 'Next');
  }
}

/// The dialog's card (a [Dialog] fills the window).
Finder _dialog() => find
    .descendant(of: find.byType(Dialog).last, matching: find.byType(Material))
    .first;

/// A date picker screen: the pager at [question], its button tapped,
/// the image cut to the dialog when [dialogOnly].
_Screen _picker(
  String name,
  String question, {
  String button = 'Select date',
  bool dialogOnly = true,
  bool dark = false,
}) => _Screen(
  name,
  'date_time',
  prepare: _at(question),
  act: (tester, _) => _tapText(tester, button),
  cropTo: dialogOnly ? _dialog : null,
  dark: dark,
);

final List<_Crops> _crops = [
  const _Crops(
    'text',
    crops: {
      'text': ['name', 'village'],
      'text_multiline': ['notes'],
      'text_numbers': ['phone'],
      'text_masked': ['pin'],
      'integer_decimal': ['age', 'weight'],
      'thousands_sep': ['income', 'area'],
      'text_states': ['s_empty', 's_invalid'],
    },
    dark: {'text', 'text_states'},
    typed: {'s_invalid': '150'},
  ),
  const _Crops(
    'select_one',
    crops: {
      'select_one': ['transport'],
      'select_one_minimal': ['minimal'],
      'select_one_quick': ['quick'],
      'select_one_autocomplete': ['country'],
      'select_one_columns': ['columns'],
      'select_one_columns_pack': ['pack'],
      'select_one_columns_n': ['columns_n'],
      'select_one_images': ['images'],
      'select_one_no_buttons': ['nobuttons'],
      'select_one_likert': ['likert'],
      'select_one_list': ['list'],
      'select_one_label_list_nolabel': ['ratings'],
      'select_one_states': ['s_readonly', 's_required'],
    },
    dark: {'select_one', 'select_one_likert', 'select_one_no_buttons'},
    typed: {'country': 'an'},
  ),
  _Crops(
    'select_multiple',
    crops: const {
      'select_multiple': ['symptoms'],
      'select_multiple_minimal': ['minimal'],
      'select_multiple_autocomplete': ['crops'],
      'select_multiple_columns': ['columns'],
      'select_multiple_no_buttons': ['nobuttons'],
      'select_multiple_list': ['list'],
      'select_multiple_states': ['s_readonly', 's_invalid'],
    },
    dark: const {'select_multiple'},
    typed: const {'crops': 'm'},
    act: (tester, session) =>
        tapIn(tester, session, 's_invalid', find.text('Cassava')),
  ),
  _Crops(
    'select_advanced',
    crops: const {
      'image_map': ['region'],
      'image_map_multiple': ['regions'],
      'select_map': ['site'],
      'search': ['fruit'],
      'search_autocomplete': ['fruit_search'],
      'search_minimal': ['fruit_minimal'],
      'search_missing': ['missing'],
    },
    dark: const {'image_map'},
    typed: const {'fruit_search': 'pa'},
    // Choices from a CSV have no default answer: answer as a person would.
    act: (tester, session) async {
      await tapIn(tester, session, 'fruit', find.text('Mango'));
      final minimal = nodeNamed<QuestionNode>(session.root, 'fruit_minimal');
      _controller(
        tester,
      ).answer(minimal.index, const SelectOneValue(Selection('papaya')));
      await tester.pump();
    },
  ),
  const _Crops(
    'select_advanced',
    suffix: ' without maps',
    platform: _Platform.none,
    crops: {
      'select_map_fallback': ['site'],
    },
  ),
  _Crops(
    'date_time',
    crops: const {
      'date': ['visit', 'birth'],
      'time_datetime': ['start', 'arrived'],
      'date_no_calendar': ['typed'],
      'date_month_year': ['harvest', 'built'],
      'date_calendars': ['ethiopian', 'buddhist'],
      'date_states': ['s_readonly', 's_invalid'],
    },
    dark: const {'date', 'date_calendars'},
    act: (tester, session) async {
      final invalid = nodeNamed<QuestionNode>(session.root, 's_invalid');
      final now = DateTime.now();
      _controller(
        tester,
      ).answer(invalid.index, DateValue(DateTime(now.year + 1, 1, 15)));
      await tester.pump();
    },
  ),
  const _Crops(
    'range_rank',
    crops: {
      'range': ['pain', 'temperature'],
      'range_vertical': ['water'],
      'range_picker': ['picker'],
      'range_rating': ['rating'],
      'range_no_ticks': ['noticks'],
      'range_states': ['r_readonly', 'r_required'],
      'rank': ['priorities'],
      'rank_empty': ['rank_empty'],
      'rank_readonly': ['rank_readonly'],
    },
    dark: {'range', 'rank'},
  ),
  const _Crops(
    'geo',
    crops: {
      'geopoint': ['home', 'home_empty'],
      'geopoint_maps': ['point_map', 'placement'],
      'geotrace_geoshape': ['path', 'field'],
      'geo_hidden_answer': ['hidden'],
      'geo_states': ['g_required'],
    },
    dark: {'geopoint'},
  ),
  const _Crops(
    'geo',
    suffix: ' without delegates',
    platform: _Platform.none,
    crops: {
      'geo_fallback': ['home', 'home_empty'],
    },
  ),
  const _Crops(
    'media',
    crops: {
      'media_image': ['photo', 'photo_empty'],
      'media_audio_video_file': ['recording', 'document'],
      'media_signature_draw_annotate': ['signature', 'marked'],
      'barcode': ['code', 'code_empty'],
      'media_states': ['m_required'],
    },
    dark: {'media_image'},
  ),
  const _Crops(
    'media',
    suffix: ' without delegates',
    platform: _Platform.none,
    crops: {
      'media_fallback': ['photo', 'photo_empty'],
    },
  ),
  const _Crops(
    'special',
    crops: {
      'counter': ['people'],
      'bearing': ['heading', 'heading_empty'],
      'url': ['guide'],
      'external_app': ['reading'],
      'printer': ['label_text'],
      'intent_group': ['sensor'],
    },
    dark: {'counter'},
  ),
  _Crops(
    'special',
    suffix: ' with a missing app',
    platform: _Platform.missingApps,
    crops: const {
      'external_app_missing': ['reading_empty'],
    },
    act: (tester, session) =>
        tapIn(tester, session, 'reading_empty', find.text('Launch')),
  ),
  const _Crops(
    'special',
    suffix: ' without delegates',
    platform: _Platform.none,
    crops: {
      'special_fallback': ['heading', 'reading'],
    },
  ),
  const _Crops(
    'notes',
    crops: {
      'note': ['name', 'welcome'],
      'read_only_value': ['greeting'],
      'note_markdown': ['markdown'],
      'hint': ['hinted'],
      'guidance_hint': ['guided'],
      'label_image': ['water'],
      'trigger': ['consent', 't_required'],
    },
    dark: {'note_markdown'},
  ),
  const _Crops(
    'groups',
    crops: {
      'group': ['household'],
      'group_field_list': ['contact'],
      'table_list': ['assets'],
      'group_unlabelled': ['plain'],
    },
    dark: {'group', 'table_list'},
  ),
  const _Crops(
    'repeats',
    crops: {
      'repeat': ['member'],
      'repeat_count': ['plots', 'plot'],
      'repeat_no_add_remove': ['visit'],
    },
    dark: {'repeat'},
  ),
  _Crops(
    'validation',
    crops: const {
      'validation_messages': ['v_required_default', 'choice'],
    },
    dark: const {'validation_messages'},
    typed: const {
      'constraint_default': '25',
      'constraint_message': '25',
      'weight': '12.5.1',
    },
    act: (tester, session) async {
      final choice = nodeNamed<QuestionNode>(session.root, 'choice');
      _controller(
        tester,
      ).answer(choice.index, const SelectOneValue(Selection('maybe')));
      await tester.pump();
    },
  ),
];

final List<_Screen> _screens = [
  // Selects.
  _Screen(
    'select_one_minimal_open',
    'select_one',
    prepare: _at('minimal'),
    act: (tester, _) => _tapText(tester, 'Bus'),
  ),
  _Screen(
    'select_multiple_minimal_open',
    'select_multiple',
    prepare: _at('minimal'),
    act: (tester, _) => _tapText(tester, 'Fever, Headache'),
  ),
  _Screen('select_one_quick_pager', 'select_one', prepare: _at('quick')),
  // Dates.
  _picker('date_picker', 'visit', dialogOnly: false, dark: true),
  _picker('date_no_calendar_picker', 'typed'),
  _picker('date_month_year_picker', 'harvest'),
  _picker('date_year_picker', 'built'),
  _picker('time_picker', 'start', button: 'Select time', dialogOnly: false),
  _picker('date_ethiopian_picker', 'ethiopian', dark: true),
  _picker('date_coptic_picker', 'coptic'),
  _picker('date_islamic_picker', 'islamic'),
  _picker('date_bikram_sambat_picker', 'bikram'),
  _picker('date_myanmar_picker', 'myanmar'),
  _picker('date_persian_picker', 'persian'),
  _picker('date_buddhist_picker', 'buddhist'),
  // Groups and repeats.
  _Screen('field_list_pager', 'groups', prepare: _at('contact'), dark: true),
  _Screen('table_list_pager', 'groups', prepare: _at('assets')),
  _Screen(
    'repeat_prompt',
    'repeats',
    // From the last question of the second member, Next asks whether to
    // add a third.
    prepare: (s) {
      final members = nodeNamed<RepeatNode>(s.root, 'member');
      s.navigator.jumpTo(questionsUnder(members.instances.last).last.index);
    },
    act: (tester, _) => _nextUntil(tester, 'Add group'),
  ),
  // A repeat with jr:count: the pager creates its instances.
  _Screen(
    'repeat_count_pager',
    'repeats',
    prepare: _at('plots'),
    act: (tester, _) async {
      await _tapText(tester, 'Next');
      await _tapText(tester, 'Next');
    },
  ),
  _Screen(
    'repeat_remove_dialog',
    'repeats',
    mode: XFormMode.scroll,
    act: (tester, _) async {
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
    },
  ),
  // The pager and the outline.
  _Screen(
    'pager',
    'survey',
    prepare: (s) {
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      );
      _at('age')(s);
    },
    dark: true,
  ),
  _Screen(
    'pager_compact',
    'survey',
    size: const Size(320, 640),
    textScale: 2,
    prepare: _at('age'),
  ),
  _Screen(
    'pager_end',
    'survey',
    prepare: (s) {
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      );
      _at('thanks')(s);
    },
    act: (tester, _) => _tapText(tester, 'Next'),
  ),
  _Screen(
    'outline_sheet',
    'survey',
    prepare: (s) {
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      );
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'age').index,
        const IntegerValue(34),
      );
      _at('children')(s);
    },
    act: (tester, _) async {
      await tester.tap(find.byIcon(Icons.toc).first);
      await tester.pumpAndSettle();
    },
    dark: true,
  ),
  _Screen(
    'outline_panel',
    'survey',
    size: const Size(1280, 800),
    pixelRatio: 1,
    prepare: (s) {
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      );
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'age').index,
        const IntegerValue(34),
      );
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'has_children').index,
        const SelectOneValue(Selection('yes')),
      );
      _at('contact')(s);
    },
    dark: true,
  ),
  _Screen(
    'tablet',
    'survey',
    size: const Size(800, 1000),
    pixelRatio: 1,
    prepare: _at('contact'),
  ),
  // Validation.
  _Screen(
    'validation_next',
    'survey',
    prepare: _at('contact'),
    act: (tester, _) => _tapText(tester, 'Next'),
    dark: true,
  ),
  _Screen(
    'validation_finalize',
    'survey',
    prepare: (s) {
      s.answer(
        nodeNamed<QuestionNode>(s.root, 'name').index,
        const StringValue('Amina'),
      );
      _at('thanks')(s);
    },
    act: (tester, _) async {
      await _tapText(tester, 'Next');
      await _tapText(tester, 'Finalize');
    },
  ),
];

void main() {
  setUpAll(() async {
    if (!screenshotsEnabled) return;
    await loadScreenshotFonts();
    _images = await renderChoiceImages();
  });

  for (final spec in _crops) {
    for (final brightness in Brightness.values) {
      if (brightness == Brightness.dark && spec.dark.isEmpty) continue;
      testWidgets(
        'crops ${spec.form}${spec.suffix} ${brightness.name}',
        (tester) => _renderCrops(tester, spec, brightness),
        skip: !screenshotsEnabled,
        experimentalLeakTesting: screenshotLeakTesting,
      );
    }
  }
  for (final spec in _screens) {
    for (final brightness in Brightness.values) {
      if (brightness == Brightness.dark && !spec.dark) continue;
      testWidgets(
        'screen ${spec.name} ${brightness.name}',
        (tester) => _renderScreen(tester, spec, brightness),
        skip: !screenshotsEnabled,
        experimentalLeakTesting: screenshotLeakTesting,
      );
    }
  }
}
