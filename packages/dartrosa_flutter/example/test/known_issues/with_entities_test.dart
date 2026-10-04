// Known issues found while wiring the Collect packages together in the
// example app. Each test fails today and is skipped with the reason.
import 'dart:convert';

import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart' show withEntities;
import 'package:dartrosa_entities/dartrosa_entities.dart' as entities;
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run the skipped tests with `--dart-define=KNOWN_ISSUES=true`.
const _run = bool.fromEnvironment('KNOWN_ISSUES');

const _form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>pulldata</h:title><model>
    <instance><data id="p"><size/></data></instance>
    <bind nodeset="/data/size" type="string"
        calculate="pulldata('sizes', 'size', 'name', 'big')"/>
  </model></h:head>
  <h:body/>
</h:html>''';

final _media = MapResourceResolver({
  'jr://file/sizes.csv': utf8.encode('name,label,size\nbig,Big,10\n'),
});

ExternalDataPlugin _plugin() =>
    ExternalDataPlugin(listMedia: (_) => ['sizes.csv']);

Future<String> _draft(DartRosaConfig config) async =>
    (await FormDefinition.parse(
      _form,
      config: config,
    )).createSession().saveDraft();

void main() {
  test('control: CSV pulldata() without entities', () async {
    final config = DartRosaConfig(resolver: _media, plugins: [_plugin()]);
    expect(await _draft(config), contains('<size>10</size>'));
  });

  test(
    'withEntities keeps the base config plugins and lastSavedSrc',
    skip: _run
        ? false
        : 'dartrosa_entities withEntities() builds a new DartRosaConfig '
              'without copying base.plugins and base.lastSavedSrc, so composing '
              'it with collectFormConfig() silently drops fast external '
              'itemsets, external data and jr://instance/last-saved',
    () {
      final media = MapResourceResolver(const {});
      final base = collectFormConfig(
        media: media,
        lastSaved: LastSaved(InMemoryLastSavedStore(), 'form'),
        plugins: [ExternalDataPlugin()],
      );
      final config = withEntities(
        base,
        entitiesRepository: entities.InMemEntitiesRepository.new,
      );
      expect(config.plugins, hasLength(base.plugins.length));
      expect(config.lastSavedSrc, base.lastSavedSrc);
    },
  );

  test(
    "entities' pulldata() falls back to external data's CSV pulldata()",
    skip: _run
        ? false
        : 'withEntities() registers the entities pulldata() as a config '
              'function, which takes precedence over the per-form CSV pulldata() '
              'ExternalDataPlugin adds in prepareForm, and can only fall back to '
              'a handler already in base.functions; so with both enabled '
              'pulldata() on CSV media returns "" (the example app drops the '
              'entities handler and serves entity lists through '
              'ExternalDataPlugin.instanceAdapter instead)',
    () async {
      // Composed by hand, so the plugin isn't dropped (see above).
      final withLists = withEntities(
        DartRosaConfig(resolver: _media),
        entitiesRepository: entities.InMemEntitiesRepository.new,
      );
      final config = DartRosaConfig(
        resolver: _media,
        functions: withLists.functions,
        filterStrategies: withLists.filterStrategies,
        parseProcessors: withLists.parseProcessors,
        externalInstanceParser: withLists.externalInstanceParser,
        plugins: [_plugin()],
      );
      expect(await _draft(config), contains('<size>10</size>'));
    },
  );
}
