// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

/// An encryption produced by ODK Collect's algorithm on the JVM
/// (`tool/golden/Golden.java`), with deterministic randomness: the random
/// bytes are `seed, seed + 1, ...` (mod 256).
final class GoldenCase {
  /// Creates a case.
  const GoldenCase({
    required this.name,
    required this.seed,
    required this.formId,
    required this.formVersion,
    required this.instanceId,
    required this.submissionXml,
    required this.media,
    required this.manifest,
    required this.signatureSource,
    required this.encryptedFiles,
  });

  /// The test name.
  final String name;

  /// The first random byte.
  final int seed;

  /// The form id.
  final String formId;

  /// The form version.
  final String? formVersion;

  /// The instance id.
  final String instanceId;

  /// `submission.xml`, base64.
  final String submissionXml;

  /// Media file name → content (base64), in encryption order.
  final Map<String, String> media;

  /// The expected submission manifest.
  final String manifest;

  /// The expected element signature source.
  final String signatureSource;

  /// The expected encrypted files: name → content (base64).
  final Map<String, String> encryptedFiles;
}
