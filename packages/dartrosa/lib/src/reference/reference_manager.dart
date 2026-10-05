// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (InvalidReferenceException, Reference,
//  ResourceReference, ReferenceFactory, PrefixedRootFactory,
//  ReferenceManagerTestUtils, ResourceReferenceFactory, RootTranslator,
//  ReferenceManager), Copyright (C) 2009 JavaRosa and contributors; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'resource_resolver.dart';

final _log = Logger('dartrosa.reference');

/// Thrown when a URI can't be derived into a [Reference].
///
/// Port of `org.javarosa.core.reference.InvalidReferenceException` (renamed:
/// DartRosa already has an `InvalidReferenceException` for tree references,
/// as JavaRosa does in another package).
final class InvalidReferenceUriException implements Exception {
  /// Creates the exception for [reference].
  const InvalidReferenceUriException(this.message, this.reference);

  /// What went wrong.
  final String message;

  /// The URI that couldn't be derived.
  final String? reference;

  @override
  String toString() => 'InvalidReferenceUriException: $message';
}

/// A derived reference to a resource.
///
/// Port of `org.javarosa.core.reference.Reference`, without the stream
/// methods: DartRosa's core does no I/O, so apps read [localUri] themselves
/// (see [ReferenceManagerResolver]).
abstract interface class Reference {
  /// The `jr://` URI of this reference.
  String get uri;

  /// The local location (for example a file path) this reference points to.
  String get localUri;
}

/// A [Reference] whose local URI is a fixed string.
///
/// Port of `org.javarosa.core.reference.ResourceReference`.
@immutable
final class ResourceReference implements Reference {
  /// Creates a reference to [localUri].
  const ResourceReference(this.localUri);

  @override
  final String localUri;

  @override
  String get uri => 'jr://resource$localUri';

  @override
  bool operator ==(Object other) =>
      other is ResourceReference && other.localUri == localUri;

  @override
  int get hashCode => localUri.hashCode;
}

/// Derives [Reference]s for the URIs it accepts.
///
/// Port of `org.javarosa.core.reference.ReferenceFactory`; the `manager`
/// argument of [derive] replaces JavaRosa's `ReferenceManager.instance()` calls.
abstract interface class ReferenceFactory {
  /// Whether this factory derives [uri].
  bool derives(String uri);

  /// Derives [uri], relative to [context] when given.
  Reference derive(String uri, ReferenceManager manager, [String? context]);
}

/// Derives URIs starting with one of its roots (`jr://` is prepended to
/// roots without a scheme) through [factory], which receives the rest of
/// the URI.
///
/// Port of `org.javarosa.core.reference.PrefixedRootFactory`.
final class PrefixedRootFactory implements ReferenceFactory {
  /// Creates a factory for [roots].
  PrefixedRootFactory(List<String> roots, this.factory)
    : roots = List.unmodifiable([
        for (final root in roots) root.contains('://') ? root : 'jr://$root',
      ]);

  /// A factory deriving `jr://<scheme>/x` to `<path>/x`. Port of
  /// `ReferenceManagerTestUtils.buildReferenceFactory`.
  factory PrefixedRootFactory.directory(String scheme, String path) =>
      PrefixedRootFactory([
        '$scheme/',
      ], (terminal, uri) => ResourceReference('$path/$terminal'));

  /// `jr://resource/...` references. Port of `ResourceReferenceFactory`.
  factory PrefixedRootFactory.resource() => PrefixedRootFactory([
    'resource',
  ], (terminal, uri) => ResourceReference(terminal));

  /// The URI prefixes this factory derives.
  final List<String> roots;

  /// Builds the reference for `terminal` (the URI after the root) and the
  /// full `uri`.
  final Reference Function(String terminal, String uri) factory;

  @override
  bool derives(String uri) => roots.any(uri.contains);

  @override
  Reference derive(String uri, ReferenceManager manager, [String? context]) {
    if (context != null) {
      return manager.deriveReference(
        context.substring(0, context.lastIndexOf('/') + 1) + uri,
      );
    }
    for (final root in roots) {
      if (uri.contains(root)) return factory(uri.substring(root.length), uri);
    }
    throw InvalidReferenceUriException(
      'Invalid attempt to derive a reference from a prefixed root. Valid '
      'prefixes for this factory are [${roots.join(', ')}]',
      uri,
    );
  }

  @override
  String toString() => 'PrefixedRootFactory{roots=[${roots.join(', ')}]}';
}

/// Rewrites URIs starting with [prefix] to start with [translatedPrefix]
/// and derives the result again, for example `jr://images/` to
/// `jr://file/forms/my-form-media/`.
///
/// Port of `org.javarosa.core.reference.RootTranslator`.
@immutable
final class RootTranslator implements ReferenceFactory {
  /// Creates a translator from [prefix] to [translatedPrefix].
  const RootTranslator(this.prefix, this.translatedPrefix);

  /// The prefix to replace.
  final String prefix;

  /// Its replacement.
  final String translatedPrefix;

  @override
  bool derives(String uri) =>
      uri.startsWith(prefix) && !uri.startsWith(translatedPrefix);

  @override
  Reference derive(String uri, ReferenceManager manager, [String? context]) =>
      context == null
      ? manager.deriveReference(translatedPrefix + uri.substring(prefix.length))
      : manager.deriveReference(
          uri,
          context: translatedPrefix + context.substring(prefix.length),
        );

  @override
  bool operator ==(Object other) =>
      other is RootTranslator &&
      other.prefix == prefix &&
      other.translatedPrefix == translatedPrefix;

  @override
  int get hashCode => Object.hash(prefix, translatedPrefix);

  @override
  String toString() =>
      "RootTranslator{prefix='$prefix', translatedPrefix='$translatedPrefix'}";
}

/// Derives `jr://` URIs into [Reference]s through root translators and
/// reference factories.
///
/// Port of `org.javarosa.core.reference.ReferenceManager`, as an ordinary
/// object instead of a global singleton: an app (such as ODK Collect)
/// creates one, registers its media folders and passes it on.
final class ReferenceManager {
  /// Creates a manager with no translators or factories.
  ReferenceManager();

  final List<RootTranslator> _translators = [];
  final List<ReferenceFactory> _factories = [];
  final List<RootTranslator> _sessionTranslators = [];

  /// Removes all translators and factories.
  void reset() {
    _translators.clear();
    _factories.clear();
    _sessionTranslators.clear();
  }

  /// The registered root translators.
  List<RootTranslator> get translators => List.unmodifiable(_translators);

  /// Adds [translator] unless an equal one is registered.
  void addRootTranslator(RootTranslator translator) {
    if (_translators.contains(translator)) {
      _log.fine('skipped adding already-present root translator $translator');
      return;
    }
    _translators.add(translator);
  }

  /// Adds [factory] unless an equal one is registered.
  void addReferenceFactory(ReferenceFactory factory) {
    if (_factories.contains(factory)) {
      _log.fine('skipped adding already-present reference factory $factory');
      return;
    }
    _factories.add(factory);
  }

  /// Removes [factory]; whether it was registered.
  bool removeReferenceFactory(ReferenceFactory factory) =>
      _factories.remove(factory);

  /// Adds a translator used until [clearSession] (for example for the
  /// form being filled). Session translators take precedence.
  void addSessionRootTranslator(RootTranslator translator) =>
      _sessionTranslators.add(translator);

  /// Removes the session translators.
  void clearSession() => _sessionTranslators.clear();

  /// Whether [uri] is relative (starts with `./`).
  static bool isRelative(String uri) => uri.startsWith('./');

  /// Derives [uri]; a relative URI (`./x`) is derived against [context].
  Reference deriveReference(String uri, {String? context}) {
    if (isRelative(uri)) {
      final relative = uri.substring(2);
      if (context == null) {
        throw StateError(
          'Attempted to retrieve local reference with no context',
        );
      }
      return _derivingRoot(context).derive(relative, this, context);
    }
    return _derivingRoot(uri).derive(uri, this);
  }

  ReferenceFactory _derivingRoot(String uri) {
    for (final factories in [_sessionTranslators, _translators, _factories]) {
      for (final factory in factories) {
        if (factory.derives(uri)) return factory;
      }
    }
    throw InvalidReferenceUriException(_prettyPrintException(uri), uri);
  }

  String _prettyPrintException(String uri) {
    if (uri.isEmpty) return 'Attempt to derive a blank reference';
    var uriRoot = uri;
    var portion = 'reference type';
    if (uri.contains('jr://')) {
      uriRoot = uri.substring('jr://'.length);
      portion = 'javarosa jr:// reference root';
    }
    var endOfRoot = uriRoot.indexOf('://') + '://'.length;
    if (endOfRoot == '://'.length - 1) endOfRoot = uriRoot.indexOf('/');
    if (endOfRoot != -1) uriRoot = uriRoot.substring(0, endOfRoot);
    final message = StringBuffer(
      'The reference "$uri" was invalid and couldn\'t be understood. The '
      '$portion "$uriRoot" is not available on this system and may have been '
      'mis-typed. Some available roots: ',
    );
    for (final root in _sessionTranslators.followedBy(_translators)) {
      message.write('\n${root.prefix}');
    }
    for (final factory in _factories) {
      if (factory is PrefixedRootFactory) {
        for (final root in factory.roots) {
          message.write('\n$root');
        }
      } else {
        try {
          message.write('\n${factory.derive('', this).uri}');
        } on Object {
          // JavaRosa skips factories that can't derive a blank URI.
        }
      }
    }
    return message.toString();
  }
}

/// A [ResourceResolver] that derives each URI through [manager] and reads
/// the derived local URI with [reader] (for example from the file system).
final class ReferenceManagerResolver implements ResourceResolver {
  /// Creates a resolver deriving through [manager] and reading with [reader].
  const ReferenceManagerResolver(this.manager, this.reader);

  /// Derives the URIs.
  final ReferenceManager manager;

  /// Reads the bytes at a derived local URI; throws
  /// [ResourceNotFoundException] when there is nothing there.
  final Future<Uint8List> Function(String localUri) reader;

  @override
  Future<Uint8List> read(String uri) async {
    final Reference reference;
    try {
      reference = manager.deriveReference(uri);
    } on InvalidReferenceUriException {
      throw ResourceNotFoundException(uri);
    }
    return reader(reference.localUri);
  }
}
