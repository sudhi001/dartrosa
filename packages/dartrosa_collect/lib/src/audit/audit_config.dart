// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocationClient, AuditConfig, Builder,
//  JavaRosaFormController), Copyright 2018 Nafundi; Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart' show StringValue;
import 'package:dartrosa/javarosa.dart';

/// The priority of the location requests an audit asks for.
///
/// Port of the values of Collect's `LocationClient.Priority` used by
/// audits.
enum LocationPriority {
  /// `PRIORITY_HIGH_ACCURACY`: the most accurate location available.
  highAccuracy,

  /// `PRIORITY_BALANCED_POWER_ACCURACY`: block-level accuracy.
  balancedPowerAccuracy,

  /// `PRIORITY_LOW_POWER`: city-level accuracy.
  lowPower,

  /// `PRIORITY_NO_POWER`: only locations other apps request.
  noPower,
}

/// The audit configuration of a form: the attributes of its `meta/audit`
/// bind.
///
/// Port of Collect's `AuditConfig` (and its `Builder`), plus the parsing
/// done by `JavaRosaFormController.getSubmissionMetadata` ([fromForm]).
final class AuditConfig {
  /// Creates a configuration from the raw attribute values: [mode] is
  /// `odk:location-priority`, [locationMinInterval] and [locationMaxAge]
  /// are in seconds (`odk:location-min-interval`, `odk:location-max-age`).
  ///
  /// Throws [FormatException] when an interval isn't an integer (Collect:
  /// `NumberFormatException`).
  AuditConfig({
    String? mode,
    String? locationMinInterval,
    String? locationMaxAge,
    this.isTrackingChangesEnabled = false,
    this.isIdentifyUserEnabled = false,
    this.isTrackChangesReasonEnabled = false,
  }) : locationPriority = mode != null ? _getMode(mode) : null,
       _locationMinInterval = locationMinInterval != null
           ? _parseLong(locationMinInterval) * 1000
           : null,
       locationMaxAge = locationMaxAge != null
           ? _parseLong(locationMaxAge) * 1000
           : null;

  /// The file name Collect gives the audit log, stored as the value of
  /// `meta/audit` (`JavaRosaFormController.AUDIT_FILE_NAME`).
  static const auditFileName = 'audit.csv';

  static const _minAllowedLocationMinInterval = 1000;

  /// The audit configuration of [form] if its main instance has exactly
  /// one `meta/audit` node, else `null`. Like Collect, also sets that
  /// node's value to [auditFileName] (the log is attached to the
  /// submission under that name).
  ///
  /// Port of the audit part of `JavaRosaFormController
  /// .getSubmissionMetadata`.
  static AuditConfig? fromForm(FormDef form) {
    final meta = form.mainInstance.root.firstChild('meta');
    if (meta == null) return null;
    final audits = meta.childrenWithName('audit');
    if (audits.length != 1) return null;
    final audit = audits.single;
    String? attribute(String name) =>
        audit.getBindAttributeValue(namespaceOdk, name);
    final config = AuditConfig(
      mode: attribute('location-priority'),
      locationMinInterval: attribute('location-min-interval'),
      locationMaxAge: attribute('location-max-age'),
      isTrackingChangesEnabled: _parseBoolean(attribute('track-changes')),
      isIdentifyUserEnabled: _parseBoolean(attribute('identify-user')),
      isTrackChangesReasonEnabled:
          attribute('track-changes-reasons') == 'on-form-edit',
    );
    audit.value = const StringValue(auditFileName);
    return config;
  }

  /// The priority of location requests, or `null` without
  /// `odk:location-priority`.
  final LocationPriority? locationPriority;

  final int? _locationMinInterval;

  /// The time in milliseconds a location stays valid, or `null`.
  final int? locationMaxAge;

  /// Whether old and new answers are logged (`odk:track-changes`).
  final bool isTrackingChangesEnabled;

  /// Whether the user must identify themselves (`odk:identify-user`).
  final bool isIdentifyUserEnabled;

  /// Whether a reason is asked for when saving an edited form
  /// (`odk:track-changes-reasons="on-form-edit"`).
  final bool isTrackChangesReasonEnabled;

  /// The desired minimum interval in milliseconds between location
  /// fetches (at least one second), or `null`.
  int? get locationMinInterval => _locationMinInterval == null
      ? null
      : _locationMinInterval > _minAllowedLocationMinInterval
      ? _locationMinInterval
      : _minAllowedLocationMinInterval;

  /// Whether locations are logged: priority, minimum interval and maximum
  /// age are all set.
  bool get isLocationEnabled =>
      locationPriority != null &&
      _locationMinInterval != null &&
      locationMaxAge != null;

  static LocationPriority _getMode(String mode) => switch (mode.toLowerCase()) {
    'balanced' => LocationPriority.balancedPowerAccuracy,
    'low_power' || 'low-power' => LocationPriority.lowPower,
    'no_power' || 'no-power' => LocationPriority.noPower,
    _ => LocationPriority.highAccuracy,
  };

  static int _parseLong(String s) =>
      javaParseInt(s, bits: 64) ??
      (throw FormatException('For input string: "$s"'));

  /// Java's `Boolean.parseBoolean`.
  static bool _parseBoolean(String? s) => s?.toLowerCase() == 'true';
}
