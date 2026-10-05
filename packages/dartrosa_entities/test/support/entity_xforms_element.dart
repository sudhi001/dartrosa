// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EntityXFormsElement), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.entities.javarosa.support.EntityXFormsElement.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';

/// The entities namespace declaration for `html(additionalNamespaces:)`.
const entitiesNs = {'entities': entitiesNamespace};

/// A model with the `entities:entities-version` attribute.
XFormsElement entityModel(String version, List<XFormsElement> children) =>
    model(children, attributes: {'entities:entities-version': version});

/// An `<entity>` element for [dataset] with [action].
XFormsElement entityNode(
  String dataset,
  EntityAction action, {
  bool optionalAction = false,
}) {
  final actionValue = optionalAction ? '' : '1';
  return switch (action) {
    EntityAction.create => t(
      'entity dataset="$dataset" create="$actionValue" id=""',
      [t('label')],
    ),
    EntityAction.update => t(
      'entity dataset="$dataset" update="$actionValue" id=""',
      [t('label')],
    ),
    EntityAction.upsert => t(
      'entity dataset="$dataset" create="$actionValue" '
      'update="$actionValue" id=""',
      [t('label')],
    ),
  };
}

/// A bind calculating the entity label from [ref].
BindBuilderXFormsElement entityLabelBind(String ref) =>
    bind('/data/meta/entity/label')
      ..type('string')
      ..calculate(ref);

/// A bind for the entity id.
BindBuilderXFormsElement entityIdBind() =>
    bind('/data/meta/entity/@id')..type('string');

/// Sets the entity id to a new UUID on first load.
XFormsElement entityIdSetValue() =>
    setvalue('odk-instance-first-load', '/data/meta/entity/@id', 'uuid()');

/// Adds `entities:saveto`.
extension WithSaveTo on BindBuilderXFormsElement {
  /// Saves the bound field to the entity [property].
  void withSaveTo(String property) =>
      withAttribute('entities', 'saveto', property);
}

/// A parser with an [EntityFormParseProcessor] (Collect's
/// `EntityXFormParserFactory`).
XFormParser entityParser(ResourceResolver? resolver) =>
    XFormParser(resolver: resolver)..addProcessor(EntityFormParseProcessor());

/// The [EntitiesExtra] the controller's model holds after finalizing.
EntitiesExtra? entitiesExtraOf(Scenario scenario) =>
    scenario.formEntryController.model.extras[EntitiesExtra] as EntitiesExtra?;

/// The string value at [xPath].
String? stringAnswer(Scenario scenario, String xPath) =>
    scenario.answerOf(xPath)?.value as String?;
