// DartRosa tests (not ports) of ReferenceManager behaviour beyond JavaRosa's
// ReferenceManagerTest: duplicate registration, removal and reset,
// relative references without a context or through a root translator,
// the resource factory, and the error text for non-prefixed factories.
// Expected behaviour follows JavaRosa 6.0.0's ReferenceManager,
// PrefixedRootFactory and RootTranslator sources.
import 'package:dartrosa/src/reference/reference_manager.dart';
import 'package:dartrosa/src/reference/resource_resolver.dart';
import 'package:test/test.dart';

/// A factory deriving everything under `custom:` (not a prefixed root).
final class CustomFactory implements ReferenceFactory {
  @override
  bool derives(String uri) => uri.startsWith('custom:');

  @override
  Reference derive(String uri, ReferenceManager manager, [String? context]) =>
      ResourceReference('/custom/${uri.replaceFirst('custom:', '')}');
}

/// A factory that can't derive a blank URI.
final class FailingFactory implements ReferenceFactory {
  @override
  bool derives(String uri) => false;

  @override
  Reference derive(String uri, ReferenceManager manager, [String? context]) =>
      throw const InvalidReferenceUriException('no', null);
}

void main() {
  late ReferenceManager manager;
  setUp(() => manager = ReferenceManager());

  test('translators and factories are registered once', () {
    const translator = RootTranslator('jr://image/', 'jr://file/media/');
    final factory = PrefixedRootFactory.directory('file', '/root');
    manager
      ..addRootTranslator(translator)
      ..addRootTranslator(
        const RootTranslator('jr://image/', 'jr://file/media/'),
      )
      ..addReferenceFactory(factory)
      ..addReferenceFactory(factory);
    expect(manager.translators, [translator]);
    expect(
      manager.deriveReference('jr://image/a.png').localUri,
      '/root/media/a.png',
    );

    expect(manager.removeReferenceFactory(factory), isTrue);
    expect(manager.removeReferenceFactory(factory), isFalse);
    expect(
      () => manager.deriveReference('jr://image/a.png'),
      throwsA(isA<InvalidReferenceUriException>()),
    );

    manager
      ..addReferenceFactory(factory)
      ..reset();
    expect(manager.translators, isEmpty);
    expect(
      () => manager.deriveReference('jr://file/a.png'),
      throwsA(isA<InvalidReferenceUriException>()),
    );
  });

  test('relative references need a context', () {
    manager.addReferenceFactory(PrefixedRootFactory.directory('file', '/r'));
    expect(
      () => manager.deriveReference('./a.png'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Attempted to retrieve local reference with no context',
        ),
      ),
    );
    expect(
      manager
          .deriveReference('./b.png', context: 'jr://file/dir/a.png')
          .localUri,
      '/r/dir/b.png',
    );
  });

  test('relative references through a translator lose their prefix', () {
    // JavaRosa passes the relative part on as if it were absolute, which
    // no root derives.
    manager
      ..addReferenceFactory(PrefixedRootFactory.directory('file', '/r'))
      ..addRootTranslator(
        const RootTranslator('jr://image/', 'jr://file/media/'),
      );
    expect(
      () => manager.deriveReference('./b.png', context: 'jr://image/a.png'),
      throwsA(
        isA<InvalidReferenceUriException>().having(
          (e) => e.reference,
          'reference',
          'b.png',
        ),
      ),
    );
  });

  test('the resource factory', () {
    manager.addReferenceFactory(PrefixedRootFactory.resource());
    final reference = manager.deriveReference('jr://resource/forms/a.xml');
    expect(reference, const ResourceReference('/forms/a.xml'));
    expect(reference.uri, 'jr://resource/forms/a.xml');
    expect(
      reference.hashCode,
      const ResourceReference('/forms/a.xml').hashCode,
    );
  });

  test('a prefixed root factory only derives its roots', () {
    final factory = PrefixedRootFactory(['images', 'http://x/'], (t, u) {
      return ResourceReference('/$t');
    });
    expect(factory.roots, ['jr://images', 'http://x/']);
    expect('$factory', 'PrefixedRootFactory{roots=[jr://images, http://x/]}');
    expect(factory.derive('http://x/a', manager).localUri, '/a');
    expect(
      () => factory.derive('jr://audio/a', manager),
      throwsA(
        isA<InvalidReferenceUriException>()
            .having(
              (e) => e.message,
              'message',
              'Invalid attempt to derive a reference from a prefixed root. '
                  'Valid prefixes for this factory are [jr://images, '
                  'http://x/]',
            )
            .having(
              (e) => '$e',
              'toString',
              startsWith('InvalidReferenceUriException: Invalid attempt'),
            ),
      ),
    );
  });

  test('root translators', () {
    const translator = RootTranslator('jr://image/', 'jr://file/');
    expect(
      '$translator',
      "RootTranslator{prefix='jr://image/', translatedPrefix='jr://file/'}",
    );
    expect(
      translator.hashCode,
      const RootTranslator('jr://image/', 'jr://file/').hashCode,
    );
    expect(translator, isNot(const RootTranslator('jr://image/', 'x')));
  });

  test('the error lists roots other factories can derive', () {
    manager
      ..addReferenceFactory(CustomFactory())
      ..addReferenceFactory(FailingFactory());
    expect(manager.deriveReference('custom:a').localUri, '/custom/a');
    expect(
      () => manager.deriveReference('jr://nope/a'),
      throwsA(
        isA<InvalidReferenceUriException>().having(
          (e) => e.message,
          'message',
          endsWith('Some available roots: \njr://resource/custom/'),
        ),
      ),
    );
  });

  test('resource not found', () {
    expect(
      '${ResourceNotFoundException('jr://file/x')}',
      'Resource not found: jr://file/x',
    );
  });
}
