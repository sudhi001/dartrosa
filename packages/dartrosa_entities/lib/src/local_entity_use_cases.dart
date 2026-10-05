// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocalEntityUseCases), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/javarosa.dart' show CsvReader;

import 'debug/debug_logger.dart';
import 'debug/entity_event.dart';
import 'javarosa/finalization/entities_extra.dart';
import 'javarosa/finalization/form_entity.dart';
import 'javarosa/parse/entity_schema.dart';
import 'javarosa/parse/string_ext.dart';
import 'javarosa/spec/entity_action.dart';
import 'server/entity_source.dart';
import 'server/media_file.dart';
import 'storage/entities_repository.dart';
import 'storage/entity.dart';
import 'uuid.dart';

/// Updates local entity lists from finalized forms and from the server.
///
/// Port of `org.odk.collect.entities.LocalEntityUseCases`. Branch ids are
/// random v4 UUIDs unless a `newBranchId` function is passed (for
/// deterministic tests).
abstract final class LocalEntityUseCases {
  /// Saves the entities a finalized form created or updated
  /// ([formEntities], from the form's `EntitiesExtra`) to
  /// [entitiesRepository]. Entities without a v4 UUID id, creates without
  /// a label or into a list that doesn't exist (or needs approval), and
  /// updates of unknown entities are skipped (and reported to
  /// [debugLogger]).
  static void updateLocalEntitiesFromForm(
    EntitiesExtra? formEntities,
    EntitiesRepository entitiesRepository, {
    DebugLogger<EntityEvent>? debugLogger,
    String Function() newBranchId = randomUuidV4,
  }) {
    for (final formEntity in formEntities?.entities ?? const <FormEntity>[]) {
      final id = formEntity.id;
      if (isV4Uuid(id)) {
        switch (formEntity.action) {
          case EntityAction.create:
            _saveNewEntity(
              formEntity,
              entitiesRepository,
              debugLogger,
              newBranchId,
            );
          case EntityAction.update:
            final existing = entitiesRepository.findEntityById(
              formEntity.dataset,
              id!,
            );
            if (existing != null) {
              _saveUpdatedEntity(formEntity, existing, entitiesRepository);
            } else {
              debugLogger?.log(UpdateNoMatch(formEntity));
            }
          case EntityAction.upsert:
            final existing = entitiesRepository.findEntityById(
              formEntity.dataset,
              id!,
            );
            if (existing == null) {
              _saveNewEntity(
                formEntity,
                entitiesRepository,
                debugLogger,
                newBranchId,
              );
            } else {
              _saveUpdatedEntity(formEntity, existing, entitiesRepository);
            }
        }
      } else {
        debugLogger?.log(
          id == null || id.trim().isEmpty
              ? NoId(formEntity)
              : InvalidId(formEntity),
        );
      }
    }
  }

  static void _saveNewEntity(
    FormEntity formEntity,
    EntitiesRepository entitiesRepository,
    DebugLogger<EntityEvent>? debugLogger,
    String Function() newBranchId,
  ) {
    if (formEntity.label.trim().isNotEmpty) {
      final list = entitiesRepository.getList(formEntity.dataset);
      if (list != null && !list.needsApproval) {
        entitiesRepository.save(formEntity.dataset, [
          NewEntity(
            formEntity.id!,
            formEntity.label,
            properties: formEntity.properties,
            branchId: newBranchId(),
          ),
        ]);
      }
    } else {
      debugLogger?.log(CreateNoLabel(formEntity));
    }
  }

  static void _saveUpdatedEntity(
    FormEntity formEntity,
    SavedEntity existing,
    EntitiesRepository entitiesRepository,
  ) {
    entitiesRepository.save(formEntity.dataset, [
      existing.copyWith(
        label: formEntity.label.trim().isEmpty
            ? existing.label
            : formEntity.label,
        properties: formEntity.properties,
        version: existing.version + 1,
      ),
    ]);
  }

  /// Updates [list] from the server's entity list CSV [serverList]
  /// (described by [mediaFile]): adds new entities, updates those changed
  /// on the server, removes online entities no longer in the list, and
  /// keeps offline changes the server hasn't seen. Does nothing if the
  /// list's hash hasn't changed, the file is not a CSV, or a row lacks
  /// `name`, `label` or `__version`.
  static void updateLocalEntitiesFromServer(
    String list,
    Uint8List serverList,
    EntitiesRepository entitiesRepository,
    MediaFile mediaFile, {
    String Function() newBranchId = randomUuidV4,
  }) {
    final existingListHash = entitiesRepository.getList(list)?.hash;
    if (mediaFile.hash == existingListHash) return;

    final List<String> header;
    final List<List<String>> records;
    try {
      (header, records) = _parseCsv(serverList);
    } on Object catch (_) {
      return;
    }

    final serverProperties = header.where((name) => !_isReserved(name)).toSet();
    entitiesRepository.cleanUpProperties(list, serverProperties);
    final localEntities = entitiesRepository.query(list);

    final missingFromServer = <String, SavedEntity>{
      for (final entity in localEntities) entity.id: entity,
    };
    final newAndUpdated = <Entity>[];
    for (final record in records) {
      final serverEntity = _parseEntityFromRecord(header, record);
      // Collect returns from the whole function here (a non-local return
      // from its forEach): nothing is saved.
      if (serverEntity == null) return;
      final existing = missingFromServer.remove(serverEntity.id);

      if (existing == null) {
        newAndUpdated.add(
          NewEntity(
            serverEntity.id,
            serverEntity.label,
            version: serverEntity.version,
            properties: serverEntity.properties,
            state: EntityState.online,
            trunkVersion: serverEntity.version,
            branchId: newBranchId(),
          ),
        );
      } else if (existing.version < serverEntity.version) {
        newAndUpdated.add(serverEntity.updateLocal(existing, newBranchId()));
      } else if (existing.version == serverEntity.version) {
        if (existing.isDirty()) {
          newAndUpdated.add(serverEntity.updateLocal(existing, newBranchId()));
        }
      } else if (existing.state == EntityState.offline) {
        newAndUpdated.add(existing.copyWith(state: EntityState.online));
      }
    }

    for (final entity in missingFromServer.values) {
      if (entity.state == EntityState.online) {
        entitiesRepository.delete(list, entity.id);
      }
    }

    entitiesRepository
      ..save(list, newAndUpdated)
      ..updateList(
        list,
        mediaFile.hash,
        needsApproval: mediaFile.type == MediaFileType.approvalEntityList,
      );
  }

  /// Deletes the offline entities of [list] that [entitySource] reports as
  /// deleted on the server (using [mediaFile]'s integrity URL; nothing is
  /// checked without one or without offline entities).
  static Future<void> cleanUpDeletedOfflineEntities(
    String list,
    EntitiesRepository entitiesRepository,
    EntitySource entitySource,
    MediaFile mediaFile,
  ) async {
    final offlineLocalEntities = entitiesRepository
        .query(list)
        .where((it) => it.state == EntityState.offline)
        .toList();

    final integrityUrl = mediaFile.integrityUrl;
    if (integrityUrl != null && offlineLocalEntities.isNotEmpty) {
      final states = await entitySource.fetchDeletedStates(integrityUrl, [
        for (final entity in offlineLocalEntities) entity.id,
      ]);
      for (final (id, deleted) in states) {
        if (deleted) entitiesRepository.delete(list, id);
      }
    }
  }

  /// JavaRosa's `SecondaryInstanceCSVParserBuilder`: `;`-delimited if the
  /// first line has a `;`, first record as header (duplicate names fail).
  static (List<String>, List<List<String>>) _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.isEmpty) {
      // Java's readLine() returns null and the delimiter check fails.
      throw const FormatException('Empty CSV');
    }
    final end = text.indexOf(RegExp('[\r\n]'));
    final firstLine = end < 0 ? text : text.substring(0, end);
    final delimiter = firstLine.contains(';') ? ';' : ',';
    final content = text.startsWith('﻿') ? text.substring(1) : text;
    final all = CsvReader(content, delimiter).readAll();
    if (all.isEmpty) return (const [], const []);
    final header = all.first;
    if (header.toSet().length != header.length) {
      throw FormatException('The header contains a duplicate name: $header');
    }
    return (header, all.sublist(1));
  }

  static _ServerEntity? _parseEntityFromRecord(
    List<String> header,
    List<String> record,
  ) {
    // CSVRecord.toMap(): only the columns the record has.
    final map = <String, String>{
      for (var i = 0; i < header.length && i < record.length; i++)
        header[i]: record[i],
    };

    final id = map[EntitySchema.id];
    final label = map[EntitySchema.label];
    final versionString = map[EntitySchema.version];
    // Kotlin's toInt() throws for a malformed number.
    final version = versionString == null
        ? null
        : int.parse(versionString, radix: 10);
    if (id == null || label == null || version == null) return null;

    return _ServerEntity(id, label, version, [
      for (final MapEntry(:key, :value) in map.entries)
        if (!_isReserved(key)) (key, value),
    ]);
  }

  static bool _isReserved(String name) =>
      name == EntitySchema.id ||
      name == EntitySchema.label ||
      name.startsWith('__');
}

final class _ServerEntity {
  const _ServerEntity(this.id, this.label, this.version, this.properties);

  final String id;
  final String label;
  final int version;
  final List<EntityProperty> properties;

  SavedEntity updateLocal(SavedEntity local, String branchId) => SavedEntity(
    local.id,
    label,
    index: local.index,
    version: version,
    properties: properties,
    state: EntityState.online,
    trunkVersion: version,
    branchId: branchId,
  );
}
