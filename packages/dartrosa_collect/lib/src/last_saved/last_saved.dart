import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';

/// Stores the last-saved instance of each form: the most recently saved
/// instance XML, which forms read through `jr://instance/last-saved`.
///
/// Collect keeps it as `last-saved.xml` in each form's media folder; a
/// form key identifies that folder (a form version). Apps implement it
/// over files; [InMemoryLastSavedStore] serves tests.
abstract interface class LastSavedStore {
  /// The last-saved instance of [formKey], or `null` if there is none.
  Future<String?> read(String formKey);

  /// Replaces the last-saved instance of [formKey] with [xml].
  Future<void> write(String formKey, String xml);

  /// Deletes the last-saved instance of [formKey].
  Future<void> delete(String formKey);
}

/// A [LastSavedStore] in memory.
final class InMemoryLastSavedStore implements LastSavedStore {
  /// Creates an empty store.
  InMemoryLastSavedStore();

  /// The stored instances by form key.
  final instances = <String, String>{};

  @override
  Future<String?> read(String formKey) async => instances[formKey];

  @override
  Future<void> write(String formKey, String xml) async =>
      instances[formKey] = xml;

  @override
  Future<void> delete(String formKey) async => instances.remove(formKey);
}

/// ODK Collect's last-saved instance for one form: what
/// `jr://instance/last-saved` reads when the form is loaded, updated each
/// time an instance of the form is saved.
///
/// ```dart
/// final lastSaved = LastSaved(store, formKey);
/// final config = DartRosaConfig(
///   lastSavedSrc: LastSaved.src,
///   resolver: lastSaved.resolver(mediaResolver),
/// );
/// // ... after saving or finalizing an instance:
/// await lastSaved.instanceSaved(session);
/// ```
///
/// Ports `FileUtils.getOrCreateLastSavedSrc` (used by `FormLoaderTask`
/// and `FormEntryUseCases`), the last-saved part of
/// `SaveFormToDisk.exportData` and of `EncryptionUtils
/// .deletePlaintextFiles`.
final class LastSaved {
  /// The last-saved instance of [formKey] in [store].
  const LastSaved(this.store, this.formKey);

  /// The file name Collect uses (`FileUtils.LAST_SAVED_FILENAME`).
  static const fileName = 'last-saved.xml';

  /// The `src` Collect gives `jr://instance/last-saved`; use it as
  /// `DartRosaConfig.lastSavedSrc`.
  static const src = 'jr://file/$fileName';

  /// The valid XML stub used while no instance was saved
  /// (`FileUtils.STUB_XML`).
  static const stubXml = "<?xml version='1.0' ?><stub />";

  /// Where last-saved instances are kept.
  final LastSavedStore store;

  /// The form (version) whose last-saved instance this is.
  final String formKey;

  /// The last-saved instance, creating the stub first if there is none
  /// (`getOrCreateLastSavedSrc`).
  Future<String> readOrCreate() async {
    final xml = await store.read(formKey);
    if (xml != null) return xml;
    await store.write(formKey, stubXml);
    return stubXml;
  }

  /// A resolver serving [src] from the store and everything else from
  /// [media].
  ResourceResolver resolver(ResourceResolver media) =>
      _LastSavedResolver(this, media);

  /// Records the instance of [session] as the last-saved one: the whole
  /// instance including non-relevant values (`getFilledInFormXml`), as
  /// Collect writes it with every save (draft or finalized).
  Future<void> instanceSaved(FormSession session) =>
      store.write(formKey, session.saveDraft());

  /// Deletes the last-saved instance after an encrypted submission was
  /// finalized (no plaintext copy may remain).
  Future<void> encryptedInstanceFinalized() => store.delete(formKey);
}

final class _LastSavedResolver implements ResourceResolver {
  _LastSavedResolver(this._lastSaved, this._media);

  final LastSaved _lastSaved;
  final ResourceResolver _media;

  @override
  Future<Uint8List> read(String uri) async {
    if (uri != LastSaved.src) return _media.read(uri);
    return utf8.encode(await _lastSaved.readOrCreate());
  }
}

/// A version of a form, as needed to find the last-saved instance to
/// carry over to a newly downloaded version.
final class LastSavedFormVersion {
  /// Creates the description of a stored form version.
  const LastSavedFormVersion({
    required this.formId,
    required this.date,
    required this.formKey,
  });

  /// The form's id.
  final String formId;

  /// When this version was added (Collect's `Form.date`).
  final int date;

  /// The key of its last-saved instance in the store.
  final String formKey;
}

/// When a new version of a form is downloaded, copies the last-saved
/// instance of the newest stored version with [formId] (by date) to
/// [destinationFormKey], if that version has one.
///
/// Port of `ServerFormUseCases.copySavedFileFromPreviousFormVersionIfExists`.
Future<void> copySavedFileFromPreviousFormVersionIfExists(
  LastSavedStore store,
  Iterable<LastSavedFormVersion> forms,
  String formId,
  String destinationFormKey,
) async {
  LastSavedFormVersion? newest;
  for (final form in forms) {
    if (form.formId != formId) continue;
    if (newest == null || form.date > newest.date) newest = form;
  }
  if (newest == null) return;
  final xml = await store.read(newest.formKey);
  if (xml != null) await store.write(destinationFormKey, xml);
}
