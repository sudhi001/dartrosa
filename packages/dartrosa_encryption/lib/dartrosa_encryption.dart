/// Encrypted ODK submissions for DartRosa.
///
/// A port of ODK Collect's `EncryptionUtils`: when a form's `<submission>`
/// has a `base64RsaPublicKey`, the submission XML and its attachments are
/// encrypted with a random AES key (itself RSA-encrypted with the form's
/// key) and replaced by a plaintext manifest, decryptable by ODK Central
/// and ODK Briefcase.
///
/// ```dart
/// final encrypted = encryptSubmission(xmlBytes, {'photo.jpg': photo}, form);
/// if (encrypted != null) {
///   upload(encrypted.manifestBytes, encrypted.encryptedFiles);
/// }
/// ```
library;

export 'src/encrypted_form_information.dart';
export 'src/encryption_exception.dart';
export 'src/encryption_utils.dart';
export 'src/rsa_public_key.dart';
