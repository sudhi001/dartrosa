// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import '../model/form_index.dart';

/// The outcome of answering a question.
///
/// A sealed class, so a `switch` over it handles every case:
///
/// ```dart
/// switch (session.answer(age.index, const IntegerValue(-3))) {
///   case AnswerAccepted():
///     break;
///   case AnswerRequired(:final message) ||
///       AnswerConstraintViolated(:final message):
///     print(message ?? 'Invalid answer');
///   case AnswerRejected(:final message):
///     print('Not a valid value: $message');
/// }
/// ```
sealed class AnswerResult {
  const AnswerResult();
}

/// The answer was saved.
final class AnswerAccepted extends AnswerResult {
  /// Creates the result.
  const AnswerAccepted();
}

/// Not saved: the question is required and the answer is empty.
final class AnswerRequired extends AnswerResult {
  /// Creates the result with the localized [message], if the form has one.
  const AnswerRequired(this.message);

  /// The form's required message (`jr:requiredMsg`), if any.
  final String? message;
}

/// Not saved: the answer violates the question's constraint.
final class AnswerConstraintViolated extends AnswerResult {
  /// Creates the result with the localized [message], if the form has one.
  const AnswerConstraintViolated(this.message);

  /// The form's constraint message (`jr:constraintMsg`), if any.
  final String? message;
}

/// Not saved: the value doesn't fit the question — text that can't be
/// read as the question's data type, a value of another type, or a
/// choice the question doesn't offer.
final class AnswerRejected extends AnswerResult {
  /// Creates the result explaining why in [message].
  const AnswerRejected(this.message);

  /// Why the value was rejected (English, for developers and logs).
  final String message;
}

/// Why finalizing failed: the first question that doesn't validate.
final class ValidationFailure {
  /// Creates the failure.
  const ValidationFailure(this.index, this.result);

  /// Where the question is.
  final FormIndex index;

  /// Why it fails ([AnswerRequired] or [AnswerConstraintViolated]).
  final AnswerResult result;
}

/// The outcome of finalizing a form.
sealed class FinalizeResult {
  const FinalizeResult();
}

/// A finalized instance, ready to submit.
final class Submission {
  /// Creates a submission.
  const Submission(this.xml, this.instanceId, this.attachments);

  /// The submission XML (non-relevant nodes left out), UTF-8.
  final String xml;

  /// The value of `meta/instanceID` (or `orx:meta/orx:instanceID`), if
  /// the form has one.
  final String? instanceId;

  /// The names of the files the submission refers to, to send with it
  /// (for multipart submission and encryption).
  ///
  /// These are the answers to `binary` questions (image, audio, video,
  /// file, signature, drawing, annotation: the file name a media widget
  /// stored) and `PointerValue` answers that are in [xml], in document
  /// order and without duplicates. Answers to non-relevant questions are
  /// left out, as they are from [xml].
  final List<String> attachments;
}

/// The form is valid and was finalized.
final class FinalizeSuccess extends FinalizeResult {
  /// Creates the result.
  const FinalizeSuccess(this.submission);

  /// What to submit.
  final Submission submission;
}

/// The form is not valid; nothing was finalized.
final class FinalizeFailure extends FinalizeResult {
  /// Creates the result.
  const FinalizeFailure(this.failure);

  /// The first failing question.
  final ValidationFailure failure;
}
