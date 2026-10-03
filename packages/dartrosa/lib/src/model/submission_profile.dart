import 'instance/tree_reference.dart';

/// A `<submission>`: where and how to send the form.
///
/// Port of `org.javarosa.core.model.SubmissionProfile`.
final class SubmissionProfile {
  /// Creates a profile.
  SubmissionProfile(
    this.ref,
    this.method,
    this.action,
    this.mediaType, [
    Map<String, String>? attributes,
  ]) : attributes = Map.unmodifiable(attributes ?? {});

  /// The part of the instance to submit.
  final TreeReference ref;

  /// The `method` attribute.
  final String? method;

  /// The `action` attribute (URL).
  final String? action;

  /// The `mediatype` attribute.
  final String? mediaType;

  /// All other attributes, such as `base64RsaPublicKey` or
  /// `orx:auto-send`.
  final Map<String, String> attributes;

  /// The attribute called [name], if any.
  String? attribute(String name) => attributes[name];
}
