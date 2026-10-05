// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (Instance, InstanceExt,
//  EditedFormFinalizationProcessor), Copyright 2017 Nafundi; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

/// Marks a session as editing a previously finalized submission (Collect's
/// `Instance.editOf` / `editNumber`). Put it in the session's extras with
/// [markSession].
final class InstanceEdit {
  /// An edit of the instance identified by [editOf] (Collect: the database
  /// id of the first instance of the edit group), the [editNumber]th edit.
  const InstanceEdit({required this.editOf, this.editNumber});

  /// The instance this edits.
  final Object editOf;

  /// Which edit this is (1 for the first), if known.
  final int? editNumber;

  /// Marks [session] as this edit.
  void markSession(FormSession session) => session.extras[InstanceEdit] = this;

  /// The edit [model]'s session is marked as, if any.
  static InstanceEdit? of(FormEntryModel model) =>
      model.extras[InstanceEdit] as InstanceEdit?;
}

/// Whether an instance is an edit: it records the instance it edits.
///
/// Port of Collect's `Instance.isEdit()` (`InstanceExt.kt`).
bool isEdit({required Object? editOf}) => editOf != null;

/// When an edit of a finalized submission is finalized, moves its
/// `meta/instanceID` to a new `meta/deprecatedID` and gives it a new
/// `uuid:` instance ID, so the server can link the edit to the original.
///
/// Port of Collect's `EditedFormFinalizationProcessor`. Add it to
/// `DartRosaConfig.finalizationProcessors`; sessions are edits when marked
/// with [InstanceEdit.markSession] (or when [isEdit] says so). Like
/// Collect, throws when the form has no `meta/instanceID`.
final class EditedFormFinalizationProcessor
    implements FormEntryFinalizationProcessor {
  /// Creates the processor. [isEdit] decides whether the finalized session
  /// is an edit (default: it is marked with an [InstanceEdit]); [uuid]
  /// generates the new instance ID's UUID (default: a random one).
  EditedFormFinalizationProcessor({
    bool Function(FormEntryModel model)? isEdit,
    String Function()? uuid,
  }) : _isEdit = isEdit ?? _isMarkedEdit,
       _uuid = uuid ?? randomUuid;

  static bool _isMarkedEdit(FormEntryModel model) =>
      InstanceEdit.of(model) != null;

  final bool Function(FormEntryModel model) _isEdit;
  final String Function() _uuid;

  @override
  void processForm(FormEntryModel model) {
    if (_isEdit(model)) _addDeprecatedId(model.form);
  }

  void _addDeprecatedId(FormDef formDef) {
    final metaSection = formDef.mainInstance.root.firstChild('meta')!;
    final instanceId = metaSection.firstChild('instanceID')!;
    final deprecatedId = TreeElement('deprecatedID');
    metaSection.addChild(deprecatedId);
    deprecatedId.setAnswer(instanceId.value);
    instanceId.setAnswer(StringValue('uuid:${_uuid()}'));
  }
}
