// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ResponseMessageParser), Copyright University of
//  Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

final _log = Logger('dartrosa_openrosa');

/// Reads the `<message>` of an `<OpenRosaResponse>` submission response.
///
/// Port of Collect's `org.odk.collect.android.utilities.ResponseMessageParser`.
final class ResponseMessageParser {
  static const _messageXmlTag = 'message';

  bool _isValid = false;
  String? _messageResponse;

  /// Whether the last response had a message.
  bool get isValid => _isValid;

  /// The message (all the text of the first `<message>` element).
  String? get messageResponse => _messageResponse;

  /// Parses [response].
  void setMessageResponse(String response) {
    _isValid = false;
    try {
      if (response.contains('OpenRosaResponse')) {
        final doc = XmlDocument.parse(response);
        // A non-namespace-aware DOM's getElementsByTagName: by qualified
        // name, in document order.
        final message = doc.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.qualified == _messageXmlTag)
            .firstOrNull;
        if (message != null) {
          _messageResponse = message.innerText;
          _isValid = true;
        }
      }
    } on XmlException catch (e) {
      _log.severe('Error parsing XML message due to ${e.message} ', e);
    }
  }
}
