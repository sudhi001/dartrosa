// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EncryptionUtils), Copyright (C) 2011 University of
//  Washington; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartrosa/javarosa.dart';

import 'encrypted_form_information.dart';

/// The name Collect gives the submission file.
const submissionXmlFileName = 'submission.xml';

/// The suffix of encrypted files.
const encryptedFileSuffix = '.enc';

/// The namespace of the submission manifest.
const encryptedSubmissionNamespace =
    'http://www.opendatakit.org/xforms/encrypted';

/// The OpenRosa namespace (of `orx:meta`).
const openRosaNamespace = 'http://openrosa.org/xforms';

/// An encrypted submission: the plaintext manifest to submit as
/// `xml_submission_file` and the encrypted files to attach.
final class EncryptedSubmission {
  /// Creates a submission.
  EncryptedSubmission({
    required this.manifest,
    required Map<String, Uint8List> encryptedFiles,
    required List<String> mediaFileNames,
  }) : encryptedFiles = Map.unmodifiable(encryptedFiles),
       mediaFileNames = List.unmodifiable(mediaFileNames);

  /// The submission manifest XML (`<data encrypted="yes" ...>`), which
  /// replaces `submission.xml`.
  final String manifest;

  /// The manifest as UTF-8, as Collect writes it.
  Uint8List get manifestBytes => utf8.encode(manifest);

  /// The encrypted files by name (`<name>.enc`): the media files in
  /// encryption order, then `submission.xml.enc`.
  final Map<String, Uint8List> encryptedFiles;

  /// The (unencrypted) names of the media files that were encrypted, in
  /// order.
  final List<String> mediaFileNames;

  /// The name of the encrypted submission XML (`submission.xml.enc`).
  String get encryptedXmlFileName => encryptedFiles.keys.last;
}

/// Encrypts [submissionXml] and [mediaFiles] (name → content, encrypted
/// in iteration order) with [formInfo] and builds the submission manifest.
///
/// As Collect does for the files in the instance directory, media files
/// whose names start with `.` or end with `.enc`, or that are named
/// [submissionXmlName], are skipped. Only the
/// [EncryptedSubmission.mediaFileNames] were encrypted; the attachments not
/// listed there must not be submitted.
///
/// [formInfo] is single-use: it advances through the IVs as it encrypts.
///
/// Port of `EncryptionUtils.generateEncryptedSubmission` (with
/// `encryptSubmissionFiles`, `encryptFile` and `writeSubmissionManifest`),
/// working on bytes instead of files.
EncryptedSubmission generateEncryptedSubmission(
  EncryptedFormInformation formInfo, {
  required Uint8List submissionXml,
  Map<String, Uint8List> mediaFiles = const {},
  String submissionXmlName = submissionXmlFileName,
}) {
  final toProcess = [
    for (final name in mediaFiles.keys)
      if (name != submissionXmlName &&
          !name.startsWith('.') &&
          !name.endsWith(encryptedFileSuffix))
        name,
  ];
  final encrypted = <String, Uint8List>{};
  void encryptFile(String name, Uint8List content) {
    // add elementSignatureSource for this file...
    formInfo.appendFileSignatureSource(name, content);
    encrypted['$name$encryptedFileSuffix'] = formInfo.encryptNextFile(content);
  }

  // Step 1: encrypt the media files, then the submission.xml as the last
  // file...
  for (final name in toProcess) {
    encryptFile(name, mediaFiles[name]!);
  }
  encryptFile(submissionXmlName, submissionXml);
  // Step 2: build the encrypted-submission manifest.
  return EncryptedSubmission(
    manifest: _submissionManifest(formInfo, submissionXmlName, toProcess),
    encryptedFiles: encrypted,
    mediaFileNames: toProcess,
  );
}

/// Encrypts a submission of [form] if the form asks for encryption: its
/// [submissionXml] and [attachments] (name → content).
///
/// Returns `null` if the form isn't encrypted.
///
/// Uses [getEncryptedFormInformation] (with [instanceId] and [random]) and
/// [generateEncryptedSubmission]; throws an `EncryptionException` if the
/// form is encrypted but the submission can't be.
///
/// ```dart
/// final encrypted = encryptSubmission(
///   utf8.encode(submission.xml),
///   {'photo.jpg': photoBytes}, // attachments: file name -> bytes
///   definition.formDef,
/// );
/// if (encrypted != null) {
///   print(encrypted.mediaFileNames); // [photo.jpg]
/// }
/// ```
EncryptedSubmission? encryptSubmission(
  Uint8List submissionXml,
  Map<String, Uint8List> attachments,
  FormDef form, {
  String? instanceId,
  Random? random,
}) {
  final formInfo = getEncryptedFormInformation(
    form,
    instanceId: instanceId,
    random: random,
  );
  if (formInfo == null) return null;
  return generateEncryptedSubmission(
    formInfo,
    submissionXml: submissionXml,
    mediaFiles: attachments,
  );
}

/// Serializes the manifest exactly as Collect's kdom document through
/// kXML 2.3.0's `KXmlSerializer` (UTF-8, no XML declaration, namespace
/// declarations after the attributes).
String _submissionManifest(
  EncryptedFormInformation formInfo,
  String submissionXmlName,
  List<String> mediaFiles,
) {
  final out = StringBuffer('<data');
  void attribute(String name, String value) {
    final quote = value.contains('"') ? "'" : '"';
    out.write(' $name=$quote');
    _kxmlEscape(out, value, quote);
    out.write(quote);
  }

  void element(String name, String text) {
    out.write('<$name>');
    _kxmlEscape(out, text, null);
    out.write('</$name>');
  }

  attribute('id', formInfo.formId);
  if (formInfo.formVersion != null) {
    attribute('version', formInfo.formVersion!);
  }
  attribute('encrypted', 'yes');
  attribute('xmlns', encryptedSubmissionNamespace);
  out.write('>');
  element('base64EncryptedKey', formInfo.base64RsaEncryptedSymmetricKey);
  out.write('<orx:meta');
  attribute('xmlns:orx', openRosaNamespace);
  out.write('>');
  element('orx:instanceID', formInfo.instanceId);
  out.write('</orx:meta>\n');
  for (final name in mediaFiles) {
    out.write('<media>');
    element('file', '$name$encryptedFileSuffix');
    out.write('</media>\n');
  }
  element('encryptedXmlFile', '$submissionXmlName$encryptedFileSuffix');
  element(
    'base64EncryptedElementSignature',
    formInfo.getBase64EncryptedElementSignature(),
  );
  out.write('</data>');
  return out.toString();
}

/// kXML's `KXmlSerializer.writeEscaped` with a UTF-8 output: in attribute
/// values ([quote] given) tabs and line breaks become numeric references
/// and the quote is escaped; `&`, `<`, `>` always are; `@` and control
/// characters become `&#N;`.
void _kxmlEscape(StringBuffer out, String s, String? quote) {
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x0A || 0x0D || 0x09:
        if (quote == null) {
          out.writeCharCode(c);
        } else {
          out.write('&#$c;');
        }
      case 0x26:
        out.write('&amp;');
      case 0x3E:
        out.write('&gt;');
      case 0x3C:
        out.write('&lt;');
      default:
        if (quote != null && c == quote.codeUnitAt(0)) {
          out.write(c == 0x22 ? '&quot;' : '&apos;');
        } else if (c >= 0x20 && c != 0x40) {
          out.writeCharCode(c);
        } else {
          out.write('&#$c;');
        }
    }
  }
}
