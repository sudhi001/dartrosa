import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../model/form_def.dart';
import '../reference/resource_resolver.dart';
import '../xform/xform_parser.dart';
import '../xform/xform_serializing_visitor.dart';

/// Saves a form being filled and restores it later (for app restarts,
/// form caches and JavaRosa's `serializeAndDeserializeForm` tests).
///
/// Replaces JavaRosa's `Externalizable` `FormDef` serialization. Instead
/// of a binary object graph it stores the form's source XML, the whole
/// main instance (non-relevant values included) and the language, and
/// restores by parsing again and loading the instance; calculations and
/// relevance are recomputed when the restored form is initialized
/// (`initialize(newInstance: false)`), as after JavaRosa's
/// deserialization. Restoring costs a parse, which JavaRosa's binary
/// cache avoids.
abstract final class FormDefCodec {
  /// The encoding version; bump when the format changes.
  static const version = 1;

  /// A cache key for the form XML [formXml]: invalidated by a different
  /// form or codec version.
  static String cacheKey(String formXml) =>
      'v$version-${sha256.convert(utf8.encode(formXml))}';

  /// Encodes [form] (parsed by DartRosa's `XFormParser`).
  static Uint8List encode(FormDef form) {
    final sourceXml = form.sourceXml;
    if (sourceXml == null) {
      throw StateError('The form has no source XML (not parsed from XML)');
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': version,
          'formXml': sourceXml,
          'formXmlPath': form.formXmlPath,
          'lastSavedSrc': form.lastSavedSrc,
          'instance': XFormSerializingVisitor(
            respectRelevance: false,
          ).serializeInstanceToString(form.mainInstance),
          'language': form.localizer?.locale,
        }),
      ),
    );
  }

  /// Restores a form encoded by [encode], reading external secondary
  /// instances through [resolver] (or a configured [parser]). As in
  /// JavaRosa's `ExternalDataInstance.readExternal`, external instances are
  /// read again, and a missing file throws [ResourceNotFoundException]
  /// (a client would then parse the form again, using a placeholder).
  static Future<FormDef> decode(
    Uint8List bytes, {
    ResourceResolver? resolver,
    XFormParser? parser,
  }) async {
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    if (data['version'] != version) {
      throw FormatException(
        'Unsupported FormDefCodec version ${data['version']}',
      );
    }
    final form = await (parser ?? XFormParser(resolver: resolver)).parse(
      data['formXml']! as String,
      formXmlSrc: data['formXmlPath'] as String?,
      lastSavedSrc: data['lastSavedSrc'] as String?,
      instanceXml: data['instance']! as String,
      restoringCachedForm: true,
    );
    final language = data['language'] as String?;
    if (language != null) form.localizer?.locale = language;
    return form;
  }
}
