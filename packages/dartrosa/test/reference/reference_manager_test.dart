// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ReferenceManagerTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ReferenceManagerTest (ReferenceManager is a
// plain object in DartRosa, so there is no singleton to reset).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/src/reference/reference_manager.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:test/test.dart';

void main() {
  late ReferenceManager refManager;
  setUp(() => refManager = ReferenceManager());

  test('derives uris according to a reference factory', () {
    refManager.addReferenceFactory(
      PrefixedRootFactory.directory('file', '/some/path'),
    );
    expect(
      refManager.deriveReference('jr://file/some-file.jpg').localUri,
      '/some/path/some-file.jpg',
    );
  });

  test('derives uris according to a root translator', () {
    refManager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/some/path'))
      ..addRootTranslator(
        const RootTranslator('jr://image/', 'jr://file/forms/some-form-media/'),
      );
    expect(
      refManager.deriveReference('jr://image/some-file.jpg').localUri,
      '/some/path/forms/some-form-media/some-file.jpg',
    );
  });

  test('can define and use root translators during a session', () {
    refManager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/some/path'))
      ..addRootTranslator(
        const RootTranslator('jr://image/', 'jr://file/forms/some-form-media/'),
      )
      ..addSessionRootTranslator(
        const RootTranslator('jr://images/', 'jr://image/'),
      );
    expect(
      refManager.deriveReference('jr://images/some-file.jpg').localUri,
      '/some/path/forms/some-form-media/some-file.jpg',
    );
  });

  test('session root translators are removed after cleaning the session', () {
    refManager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/some/path'))
      ..addRootTranslator(
        const RootTranslator('jr://image/', 'jr://file/forms/some-form-media/'),
      )
      ..addSessionRootTranslator(
        const RootTranslator('jr://images/', 'jr://image/'),
      )
      ..clearSession();
    expect(
      () => refManager.deriveReference('jr://images/some-file.jpg'),
      throwsA(isA<InvalidReferenceUriException>()),
    );
  });

  test('avoids infinite recursion', () {
    refManager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/some/path'))
      ..addSessionRootTranslator(
        const RootTranslator('jr://file/', 'jr://file/forms/some-form-media/'),
      );
    expect(
      refManager.deriveReference('jr://file/some-file.xml').localUri,
      '/some/path/forms/some-form-media/some-file.xml',
    );
  });

  // DartRosa additions.
  test('relative uris are derived against their context', () {
    refManager.addReferenceFactory(
      PrefixedRootFactory.directory('file', '/some/path'),
    );
    expect(
      refManager
          .deriveReference('./b.jpg', context: 'jr://file/dir/a.xml')
          .localUri,
      '/some/path/dir/b.jpg',
    );
  });

  test('the error lists the available roots', () {
    refManager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/p'))
      ..addRootTranslator(const RootTranslator('jr://image/', 'jr://file/'));
    expect(
      () => refManager.deriveReference('jr://audio/x.mp3'),
      throwsA(
        isA<InvalidReferenceUriException>().having(
          (e) => e.message,
          'message',
          'The reference "jr://audio/x.mp3" was invalid and couldn\'t be '
              'understood. The javarosa jr:// reference root "audio" is not '
              'available on this system and may have been mis-typed. Some '
              'available roots: \njr://image/\njr://file/',
        ),
      ),
    );
  });

  test('ReferenceManagerResolver reads derived local uris', () async {
    refManager.addReferenceFactory(PrefixedRootFactory.directory('file', '/d'));
    final resolver = ReferenceManagerResolver(
      refManager,
      (localUri) async => Uint8List.fromList(utf8.encode(localUri)),
    );
    expect(utf8.decode(await resolver.read('jr://file/a.csv')), '/d/a.csv');
    expect(
      resolver.read('jr://nope/a.csv'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });
}
