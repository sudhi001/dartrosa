// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Regressions found while wiring the Collect packages together in the
// example app: withEntities() keeps the base config, and entity lists and
// CSV media share one pulldata().
import 'dart:convert';

import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart' show withEntities;
import 'package:dartrosa_entities/dartrosa_entities.dart' as entities;
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('withEntities keeps the base config plugins and lastSavedSrc', () {
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
  });

  test(
    "entities' pulldata() falls back to external data's CSV pulldata()",
    () async {
      // withEntities joins the plugin's pulldata(): entity lists first,
      // then CSV media (as in Collect).
      final config = withEntities(
        DartRosaConfig(resolver: _media, plugins: [_plugin()]),
        entitiesRepository: entities.InMemEntitiesRepository.new,
      );
      expect(await _draft(config), contains('<size>10</size>'));
    },
  );
}
