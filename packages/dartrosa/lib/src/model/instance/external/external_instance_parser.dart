/// Loading secondary instances from `src` URIs.
///
/// Port of `org.javarosa.xform.parse.ExternalInstanceParser` and
/// `XmlExternalInstance`. JavaRosa's global parser factory
/// (`XFormUtils.setExternalInstanceParserFactory`) is replaced by passing an
/// [ExternalInstanceParser] instance.
///
/// @docImport '../external_data_instance.dart';
library;

import 'dart:typed_data';

import '../../../reference/resource_resolver.dart';
import '../../../xml/tree_element_parser.dart';
import '../tree_element.dart';
import 'csv_instance.dart';
import 'geojson_instance.dart';

/// Parses the content of a secondary-instance file of some format.
///
/// Port of `ExternalInstanceParser.FileInstanceParser`.
abstract interface class FileInstanceParser {
  /// Whether this parser handles the instance [instanceId] at [instanceSrc].
  bool isSupported(String instanceId, String instanceSrc);

  /// Parses [bytes] into the instance's top-level element. [partial] asks
  /// for a quick, possibly incomplete parse (parsers may ignore it).
  TreeElement parse(String instanceId, Uint8List bytes, {bool partial = false});
}

/// Supplies secondary instances without reading a file, e.g. from a
/// database (ODK Collect uses this for entity lists).
///
/// Port of `ExternalInstanceParser.InstanceProvider`. Providers are
/// synchronous because a partial instance is completed on demand during
/// XPath evaluation (see [ExternalDataInstance]).
abstract interface class InstanceProvider {
  /// Whether this provider supplies the instance [instanceId] at
  /// [instanceSrc].
  bool isSupported(String instanceId, String instanceSrc);

  /// The instance's top-level element; with [partial], elements may be
  /// placeholders marked partial ([TreeElement.isPartial]) that are filled
  /// in later by a full [get].
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  });
}

/// Turns a secondary instance's `src` into a [TreeElement] tree.
///
/// Instance providers are consulted first, then file parsers by format
/// (CSV for `file-csv` URIs, GeoJSON for `.geojson`), and XML otherwise.
/// Registered providers and parsers take precedence over earlier ones.
final class ExternalInstanceParser {
  /// Creates a parser with the default CSV and GeoJSON file parsers.
  ExternalInstanceParser();

  var _fileParsers = <FileInstanceParser>[
    const CsvExternalInstance(),
    const GeoJsonExternalInstance(),
  ];
  var _providers = <InstanceProvider>[];

  /// Adds [parser] before the existing file parsers.
  void addFileInstanceParser(FileInstanceParser parser) =>
      _fileParsers = [parser, ..._fileParsers];

  /// Adds [provider] before the existing instance providers.
  void addInstanceProvider(InstanceProvider provider) =>
      _providers = [provider, ..._providers];

  /// The provider that supplies [instanceId] at [instanceSrc], if any.
  InstanceProvider? providerFor(String instanceId, String instanceSrc) {
    for (final provider in _providers) {
      if (provider.isSupported(instanceId, instanceSrc)) return provider;
    }
    return null;
  }

  /// Loads the instance [instanceId] from [instanceSrc].
  ///
  /// Throws [ResourceNotFoundException] when the file is missing, and the
  /// format parsers' exceptions when it is malformed.
  Future<TreeElement> parse(
    ResourceResolver resolver,
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) async => (await parseWithReload(
    resolver,
    instanceId,
    instanceSrc,
    partial: partial,
  )).$1;

  /// Like [parse], also returning a synchronous function that produces
  /// the complete instance (used to fill in partial elements, as
  /// JavaRosa's `ExternalDataInstance.parseExternalFile(false)` does). File
  /// instances are re-parsed from the bytes already read.
  Future<(TreeElement, TreeElement Function())> parseWithReload(
    ResourceResolver resolver,
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) async {
    final provider = providerFor(instanceId, instanceSrc);
    if (provider != null) {
      return (
        provider.get(instanceId, instanceSrc, partial: partial),
        () => provider.get(instanceId, instanceSrc),
      );
    }
    final bytes = await resolver.read(instanceSrc);
    for (final parser in _fileParsers) {
      if (parser.isSupported(instanceId, instanceSrc)) {
        return (
          parser.parse(instanceId, bytes, partial: partial),
          () => parser.parse(instanceId, bytes),
        );
      }
    }
    return (
      parseXmlExternalInstance(instanceId, bytes),
      () => parseXmlExternalInstance(instanceId, bytes),
    );
  }
}

/// Parses an XML secondary-instance file: its document element becomes the
/// instance's top-level element. Port of `XmlExternalInstance.parse`.
TreeElement parseXmlExternalInstance(String instanceId, Uint8List bytes) =>
    parseTreeElement(decodeXmlBytes(bytes), instanceId: instanceId);
