// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocalEntitiesExternalInstanceParserFactory),
//  Copyright University of Washington, Nafundi and contributors; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/javarosa.dart';

import '../../storage/entities_repository.dart';
import 'form_media_file_repository.dart';
import 'local_entities_instance_provider.dart';

/// Creates [ExternalInstanceParser]s that read local entity lists.
///
/// Port of
/// `org.odk.collect.entities.javarosa.intance.LocalEntitiesExternalInstanceParserFactory`
/// (JavaRosa's global `ExternalInstanceParserFactory` becomes passing the
/// parser to `DartRosaConfig` / `XFormParser`).
final class LocalEntitiesExternalInstanceParserFactory {
  /// Creates a factory.
  const LocalEntitiesExternalInstanceParserFactory(
    this._entitiesRepositoryProvider,
    this._mediaFileRepository,
  );

  final EntitiesRepository Function() _entitiesRepositoryProvider;
  final FormMediaFileRepository _mediaFileRepository;

  /// A new parser with a [LocalEntitiesInstanceProvider] added.
  ExternalInstanceParser getExternalInstanceParser() =>
      ExternalInstanceParser()..addInstanceProvider(
        LocalEntitiesInstanceProvider(
          _entitiesRepositoryProvider,
          _mediaFileRepository,
        ),
      );
}
