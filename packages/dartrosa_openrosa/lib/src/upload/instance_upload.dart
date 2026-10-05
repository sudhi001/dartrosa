// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// @docImport 'open_rosa_instance_uploader.dart';
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart' show Submission;
import 'package:dartrosa/javarosa.dart' show FormDef;
import 'package:dartrosa_encryption/dartrosa_encryption.dart';

import '../http/open_rosa_http_interface.dart';

/// A finalized instance to upload: the files of its instance directory
/// and where the form says to submit it.
///
/// Collect uploads an instance from its directory: the instance XML (or
/// `submission.xml`, see [OpenRosaInstanceUploader]) as
/// `xml_submission_file` and every other file as an attachment. [files]
/// is that directory's listing.
final class InstanceUpload {
  /// Creates an upload of the instance called [instanceFileName] among
  /// [files].
  InstanceUpload({
    required this.instanceFileName,
    required List<UploadFile> files,
    this.submissionUri,
  }) : files = List.unmodifiable(files);

  /// An upload of a DartRosa [submission] (from `FormSession.finalize`)
  /// and the content of its attachments by file name, as
  /// [instanceFileName] (Collect names instance files
  /// `<form name>_<yyyy-MM-dd_HH-mm-ss>.xml`).
  ///
  /// Every given attachment is uploaded, as Collect uploads every file in
  /// the instance directory; [Submission.attachments] lists the ones the
  /// instance refers to.
  factory InstanceUpload.fromSubmission(
    Submission submission, {
    Map<String, Uint8List> attachments = const {},
    String instanceFileName = submissionXmlFileName,
    String? submissionUri,
  }) => InstanceUpload(
    instanceFileName: instanceFileName,
    files: [
      BytesUploadFile(instanceFileName, utf8.encode(submission.xml)),
      for (final MapEntry(:key, :value) in attachments.entries)
        if (key != instanceFileName) BytesUploadFile(key, value),
    ],
    submissionUri: submissionUri,
  );

  /// An upload of an [EncryptedSubmission]: its manifest as
  /// `submission.xml` and its encrypted files, as Collect leaves the
  /// instance directory after encrypting it.
  factory InstanceUpload.fromEncryptedSubmission(
    EncryptedSubmission submission, {
    String? submissionUri,
  }) => InstanceUpload(
    instanceFileName: submissionXmlFileName,
    files: [
      BytesUploadFile(submissionXmlFileName, submission.manifestBytes),
      for (final MapEntry(:key, :value) in submission.encryptedFiles.entries)
        BytesUploadFile(key, value),
    ],
    submissionUri: submissionUri,
  );

  /// An upload of a [submission] of [form], encrypted (with
  /// `dartrosa_encryption`'s `encryptSubmission`) if the form asks for
  /// it, and sent to the form's submission URL (`<submission action>`) if
  /// it has one.
  ///
  /// [random] is for encryption; [instanceFileName] names an unencrypted
  /// instance.
  factory InstanceUpload.forForm(
    FormDef form,
    Submission submission, {
    Map<String, Uint8List> attachments = const {},
    String instanceFileName = submissionXmlFileName,
    Random? random,
  }) {
    final submissionUri = form.defaultSubmission?.action;
    final encrypted = encryptSubmission(
      utf8.encode(submission.xml),
      attachments,
      form,
      instanceId: submission.instanceId,
      random: random,
    );
    if (encrypted != null) {
      return InstanceUpload.fromEncryptedSubmission(
        encrypted,
        submissionUri: submissionUri,
      );
    }
    return InstanceUpload.fromSubmission(
      submission,
      attachments: attachments,
      instanceFileName: instanceFileName,
      submissionUri: submissionUri,
    );
  }

  /// The name of the instance XML file among [files].
  final String instanceFileName;

  /// The files of the instance directory.
  final List<UploadFile> files;

  /// The form's submission URL, if it has one.
  final String? submissionUri;
}
