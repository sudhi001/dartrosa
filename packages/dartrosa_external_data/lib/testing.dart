// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// Test support: drive forms that use external data with DartRosa's
/// `Scenario`.
library;

import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';

import 'dartrosa_external_data.dart';

/// Parses the form [xml] with external data enabled and starts a
/// [Scenario] on it.
///
/// [media] maps media file names (e.g. `fruits.csv`) to their text,
/// served at `jr://file/<name>` (and `jr://file-csv/<name>` for CSV
/// secondary instances). With [listMedia] (the default) the plugin is told
/// the media file names, as Collect lists its media folder. With
/// [instanceXml], that saved instance is loaded (typed by
/// [externalAnswerResolver]) instead of starting a new one.
Future<Scenario> externalDataScenario(
  String xml, {
  Map<String, String> media = const {},
  bool listMedia = true,
  PullDataInstanceAdapter? instanceAdapter,
  ExternalDataRepository? repository,
  String? instanceXml,
}) async {
  final resolver = MapResourceResolver({
    for (final MapEntry(:key, :value) in media.entries) ...{
      'jr://file/$key': utf8.encode(value),
      'jr://file-csv/$key': utf8.encode(value),
    },
  });
  final plugin = ExternalDataPlugin(
    listMedia: listMedia ? (_) => media.keys : null,
    instanceAdapter: instanceAdapter,
    repository: repository == null ? null : (_) => repository,
  );
  final parser = XFormParser(resolver: resolver);
  plugin.createParseProcessors().forEach(parser.addProcessor);
  final form = await parser.parse(
    xml,
    instanceXml: instanceXml,
    answerResolver: plugin.answerResolver,
  );
  await plugin.prepareForm(form, resolver);
  return Scenario.fromFormDef(form, newInstance: instanceXml == null);
}

/// The choices of the select at [xPath] in [scenario], expanded from its
/// `search()` appearance if it has one (see [loadSelectChoices]).
List<SelectChoice> externalChoicesOf(Scenario scenario, String xPath) =>
    loadSelectChoices(
      FormEntryPrompt(scenario.formDef, scenario.indexOf(xPath)!),
    );
