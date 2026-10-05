import 'dart:async';
import 'dart:convert';

import 'package:dartrosa/javarosa.dart' show FormDef;
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart'
    show
        EntitiesRepository,
        InMemEntitiesRepository,
        formEntities,
        saveFormEntities,
        withEntities;
import 'package:dartrosa_external_data/dartrosa_external_data.dart'
    show ExternalDataPlugin;
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'corpus.dart';

/// A saved instance: a draft, or a finalized submission.
class SavedInstance {
  SavedInstance._(this.id, this.form, {this.editOf, this.editNumber});

  /// A local id.
  final int id;

  /// The form it is an instance of.
  final CorpusForm form;

  /// The finalized instance this edits, if it is an edit.
  final SavedInstance? editOf;

  /// Which edit of [editOf] this is.
  final int? editNumber;

  /// The instance XML (a draft, or the submission once finalized).
  String xml = '';

  /// Whether it was finalized.
  bool finalized = false;

  /// Its `meta/instanceID` once finalized; only instances with one can be
  /// edited.
  String? instanceId;

  /// The instance's `audit.csv`.
  final audit = InMemoryAuditLogStore();

  /// When it was last saved.
  DateTime saved = DateTime.now();
}

/// What a finalized instance exports: the files an OpenRosa upload sends.
class OutboxEntry {
  /// Creates an entry.
  OutboxEntry(
    this.instance,
    this.files, {
    required this.encrypted,
    this.entities = 0,
  });

  /// The finalized instance.
  final SavedInstance instance;

  /// File name → content (`submission.xml`, or the manifest and `.enc`
  /// files when encrypted).
  final Map<String, Uint8List> files;

  /// Whether the submission was encrypted with the form's public key.
  final bool encrypted;

  /// How many entities the submission created or updated.
  final int entities;
}

/// The app's in-memory storage and form services: loads corpus forms with
/// ODK Collect's services (last-saved, fast itemsets, external data,
/// entities, edits), keeps drafts and finalized instances, and exports
/// submissions to an outbox.
class Workspace extends ChangeNotifier {
  /// Creates a workspace over [corpus] read from [bundle].
  Workspace(this.corpus, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  /// The bundled forms.
  final Corpus corpus;

  /// Where the forms are read from.
  final AssetBundle bundle;

  /// Local entity lists, shared by all forms.
  final EntitiesRepository entities = InMemEntitiesRepository();

  /// Last-saved instances by form path.
  final lastSaved = InMemoryLastSavedStore();

  /// Saved instances, newest first.
  final List<SavedInstance> instances = [];

  /// Exported submissions, newest first.
  final List<OutboxEntry> outbox = [];

  var _nextId = 1;

  /// Parses [form] the way ODK Collect loads it.
  Future<FormDefinition> load(CorpusForm form) async {
    final xml = await bundle.loadString('$corpusRoot/${form.path}');
    final media = AssetResolver(bundle, form.folder);
    final config = withEntities(
      collectFormConfig(
        media: media,
        lastSaved: LastSaved(lastSaved, form.path),
        plugins: [
          ExternalDataPlugin(
            // Collect imports every CSV of the form's media folder; corpus
            // forms share folders, so only the CSVs a form names count.
            listMedia: (_) => [
              for (final name in corpus.mediaOf(form))
                if (name.endsWith('.csv') &&
                    xml.contains(name.substring(0, name.length - 4)))
                  name,
            ],
          ),
        ],
      ),
      entitiesRepository: () => entities,
    );
    return FormDefinition.parse(xml, config: config);
  }

  /// A session filling [instance] (new when it has no XML yet), marked
  /// as an edit when [instance] edits a finalized one.
  FormSession open(FormDefinition definition, SavedInstance instance) {
    final session = definition.createSession(
      existingInstance: instance.xml.isEmpty ? null : instance.xml,
    );
    if (instance.editOf case final original?) {
      InstanceEdit(
        editOf: original.id,
        editNumber: instance.editNumber,
      ).markSession(session);
    }
    return session;
  }

  /// Opens [instance] for filling: loads its form, starts a session and
  /// its audit log.
  Future<Filling> startFilling(SavedInstance instance) async =>
      Filling._(open(await load(instance.form), instance), instance);

  /// A new instance of [form], or an edit of the finalized [editOf].
  SavedInstance newInstance(CorpusForm form, {SavedInstance? editOf}) =>
      SavedInstance._(
        _nextId++,
        form,
        editOf: editOf,
        editNumber: editOf == null
            ? null
            : instances.where((i) => i.editOf == editOf).length + 1,
      )..xml = editOf?.xml ?? '';

  /// Saves [session] as a draft in [instance].
  Future<void> saveDraft(SavedInstance instance, FormSession session) async {
    instance
      ..xml = session.saveDraft()
      ..saved = DateTime.now();
    _remember(instance);
    await LastSaved(lastSaved, instance.form.path).instanceSaved(session);
    notifyListeners();
  }

  /// Records the finalized [submission] of [session] in [instance]: saves
  /// its entities, encrypts it when the form has a public key, and puts
  /// it in the outbox.
  Future<OutboxEntry> finalize(
    SavedInstance instance,
    FormSession session,
    Submission submission,
  ) async {
    instance
      ..xml = submission.xml
      ..finalized = true
      ..instanceId = submission.instanceId
      ..saved = DateTime.now();
    _remember(instance);
    final entityCount = formEntities(session)?.entities.length ?? 0;
    saveFormEntities(session, entities);
    final xml = utf8.encode(submission.xml);
    final form = session.definition.formDef;
    final encrypted = isEncrypted(form)
        ? encryptSubmission(
            xml,
            const {},
            form,
            instanceId: submission.instanceId,
          )
        : null;
    final lastSavedInstance = LastSaved(lastSaved, instance.form.path);
    if (encrypted == null) {
      await lastSavedInstance.instanceSaved(session);
    } else {
      await lastSavedInstance.encryptedInstanceFinalized();
    }
    final entry = OutboxEntry(
      instance,
      encrypted == null
          ? {'submission.xml': xml}
          : {
              'submission.xml': encrypted.manifestBytes,
              ...encrypted.encryptedFiles,
            },
      encrypted: encrypted != null,
      entities: entityCount,
    );
    outbox.insert(0, entry);
    notifyListeners();
    return entry;
  }

  void _remember(SavedInstance instance) {
    instances
      ..remove(instance)
      ..insert(0, instance);
  }
}

/// Whether [form]'s submissions are encrypted (it has a public key).
bool isEncrypted(FormDef form) =>
    form.defaultSubmission
        ?.attribute(base64RsaPublicKeyAttribute)
        ?.isNotEmpty ??
    false;

/// A session filling a [SavedInstance] and its audit log.
class Filling {
  Filling._(this.session, SavedInstance instance)
    : audit = FormAudit(
        session,
        store: instance.audit,
        isEditing: instance.editOf != null,
      ) {
    // The pager moves without telling the app: log a new screen when an
    // answer is given somewhere else.
    var position = session.navigator.position;
    _changes = session.changes.listen((_) {
      if (session.navigator.position != position) {
        position = session.navigator.position;
        audit.screenChanged();
      }
    });
  }

  /// The form being filled.
  final FormSession session;

  /// Its audit log.
  final FormAudit audit;

  late final StreamSubscription<FormChange> _changes;

  /// Stops logging and closes the audit.
  Future<void> close() async {
    await _changes.cancel();
    await audit.close();
  }
}
