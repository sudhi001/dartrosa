// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'finalization/edited_form_finalization_processor.dart';
import 'itemsets/fast_external_itemsets_plugin.dart';
import 'last_saved/last_saved.dart';

/// A [DartRosaConfig] for loading one form the way ODK Collect does, with
/// this package's services wired in:
///
/// * [lastSaved]: `jr://instance/last-saved` reads the form's last-saved
///   instance (call [LastSaved.instanceSaved] after each save);
/// * [fastExternalItemsets]: the form's `itemsets.csv` is imported for
///   selects with a `query` attribute (read their choices with
///   `loadItemsetChoices`), by [itemsets] (default: a
///   [FastExternalItemsetsPlugin] with an in-memory repository);
/// * [editedFormFinalization]: finalizing a session marked with
///   `InstanceEdit` adds `meta/deprecatedID` (on by default).
///
/// [media] reads the form's media (`jr://file/...`). The other parameters
/// are passed through to [DartRosaConfig] (the Collect plugins and
/// processors come after the given ones). Audits are per session: create
/// a `FormAudit` for each session.
///
/// DartRosa's counterpart of the wiring in Collect's `FormLoaderTask`,
/// `FormEntryUseCases` and `CollectFormEntryControllerFactory`.
DartRosaConfig collectFormConfig({
  required ResourceResolver media,
  LastSaved? lastSaved,
  bool fastExternalItemsets = true,
  FastExternalItemsetsPlugin? itemsets,
  bool editedFormFinalization = true,
  String Function()? uuid,
  List<XPathFunctionHandler> functions = const [],
  List<FilterStrategy> filterStrategies = const [],
  List<Object> parseProcessors = const [],
  List<FormEntryFinalizationProcessor> finalizationProcessors = const [],
  List<PreloadHandler> preloadHandlers = const [],
  ExternalInstanceParser? externalInstanceParser,
  SetGeopointAction Function(TreeReference target)? setGeopointAction,
  PropertyManager? properties,
  List<FormLoadPlugin> plugins = const [],
}) => DartRosaConfig(
  resolver: lastSaved?.resolver(media) ?? media,
  lastSavedSrc: lastSaved == null ? null : LastSaved.src,
  functions: functions,
  filterStrategies: filterStrategies,
  parseProcessors: parseProcessors,
  finalizationProcessors: [
    ...finalizationProcessors,
    if (editedFormFinalization) EditedFormFinalizationProcessor(uuid: uuid),
  ],
  preloadHandlers: preloadHandlers,
  externalInstanceParser: externalInstanceParser,
  setGeopointAction: setGeopointAction,
  properties: properties,
  plugins: [
    ...plugins,
    if (fastExternalItemsets) itemsets ?? FastExternalItemsetsPlugin(),
  ],
);
