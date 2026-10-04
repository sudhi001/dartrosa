// Ports of Collect's CaseInsensitiveEmptyHeadersTest,
// OkHttpCaseInsensitiveHeadersTest, CollectThenSystemContentTypeMapperTest
// and the toUri cases of the entities module's StringExtTest.
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

void main() {
  group('CaseInsensitiveEmptyHeaders', () {
    const headers = CaseInsensitiveEmptyHeaders();

    test('getHeaders', () => expect(headers.headers, isEmpty));
    test('containsHeader', () => expect(headers.containsHeader(''), isFalse));
    test(
      'null header lookup',
      () => expect(headers.containsHeader(null), isFalse),
    );
    test('getAnyValue', () => expect(headers.getAnyValue(''), isNull));
    test('getValues', () => expect(headers.getValues(''), isNull));
  });

  group('ListCaseInsensitiveHeaders (OkHttpCaseInsensitiveHeaders)', () {
    late CaseInsensitiveHeaders headers;

    setUp(() {
      headers = ListCaseInsensitiveHeaders([
        ('Mixed-Case', 'value'),
        ('lower-case', 'value'),
        ('UPPER-CASE', 'value'),
        ('collision', 'v1'),
        ('Collision', 'v2'),
        ('COLLISION', 'v3'),
      ]);
    });

    test('mixed case header lookup', () {
      expect(headers.containsHeader('Mixed-Case'), isTrue);
      expect(headers.containsHeader('mixed-case'), isTrue);
      expect(headers.containsHeader('MIXED-CASE'), isTrue);
    });

    test('lower case header lookup', () {
      expect(headers.containsHeader('lower-case'), isTrue);
      expect(headers.containsHeader('Lower-Case'), isTrue);
      expect(headers.containsHeader('LOWER-CASE'), isTrue);
    });

    test('upper case header lookup', () {
      expect(headers.containsHeader('UPPER-CASE'), isTrue);
      expect(headers.containsHeader('upper-case'), isTrue);
      expect(headers.containsHeader('Upper-Case'), isTrue);
    });

    test('null header lookup', () {
      expect(headers.containsHeader(null), isFalse);
    });

    test('get any for single value', () {
      expect(headers.getValues('Mixed-Case')!.length, 1);
      expect(headers.getAnyValue('Mixed-Case'), 'value');
    });

    test('get any for multiple value', () {
      expect(headers.getValues('Collision')!.length, greaterThan(1));
      expect(['v1', 'v2', 'v3'], contains(headers.getAnyValue('Collision')));
    });

    test('case insensitive name collisions', () {
      expect(headers.containsHeader('Collision'), isTrue);
      expect(headers.getValues('Collision')!.length, greaterThan(1));
      expect(headers.headers!.length, 4);
    });
  });

  group('CollectThenSystemContentTypeMapper', () {
    test('when extension is recognized returns type for file', () {
      final mapper = CollectThenSystemContentTypeMapper((_) => null);
      expect(mapper.map('file.amr'), 'audio/amr');
      expect(mapper.map('file.oga'), 'audio/ogg');
      expect(mapper.map('file.ogv'), 'video/ogg');
      expect(mapper.map('file.webm'), 'video/webm');
    });

    test('when extension is not recognized returns type from system', () {
      final mapper = CollectThenSystemContentTypeMapper(
        (e) => e == 'mystery' ? 'text/mystery' : null,
      );
      expect(mapper.map('file.mystery'), 'text/mystery');
    });

    test(
      'when extension is not recognized and system does not recognize returns octet stream type',
      () {
        final mapper = CollectThenSystemContentTypeMapper((_) => null);
        expect(mapper.map('file.bizarre'), 'application/octet-stream');
      },
    );

    test('defaults to package:mime', () {
      final mapper = CollectThenSystemContentTypeMapper();
      expect(mapper.map('photo.JPG'), 'image/jpeg');
      expect(mapper.map('noextension'), 'application/octet-stream');
      expect(mapper.map('file.amr'), 'audio/amr');
    });
  });

  group('appendQueryParameters (StringExt.toUri)', () {
    test('adds single query param to uri', () {
      expect(
        appendQueryParameters('https://example.com', [('id', '123')]),
        'https://example.com?id=123',
      );
    });

    test('preserves existing query parameters', () {
      expect(
        appendQueryParameters('https://example.com?foo=bar', [('id', '123')]),
        'https://example.com?foo=bar&id=123',
      );
    });

    test('sets null value as query param', () {
      expect(
        appendQueryParameters('https://example.com', [('id', null)]),
        'https://example.com?id=null',
      );
    });

    test('does not change uri path', () {
      expect(
        appendQueryParameters('https://example.com/path/subpath', [
          ('id', '123'),
        ]),
        'https://example.com/path/subpath?id=123',
      );
    });

    test('encodes like Android Uri.encode', () {
      expect(
        appendQueryParameters('https://e.com?#f', [('a b', "x,y/z=é!*'()~")]),
        "https://e.com?a%20b=x%2Cy%2Fz%3D%C3%A9!*'()~#f",
      );
    });
  });
}
