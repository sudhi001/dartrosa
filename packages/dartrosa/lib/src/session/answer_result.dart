import '../model/form_index.dart';

/// The outcome of answering a question.
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

  /// The attached files' names (for multipart submission).
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
