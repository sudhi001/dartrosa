import 'package:dartrosa/dartrosa.dart';
import 'package:test/test.dart';

void main() {
  group('XPathException messages match JavaRosa', () {
    test('arity with exact count', () {
      expect(
        XPathArityException('concat', 2, 1).message,
        'XPath evaluation: The concat function was provided the incorrect '
        'number of arguments:1. It expected 2 arguments.',
      );
    });

    test('arity with description', () {
      expect(
        XPathArityException.described('min', 'at least 1 argument', 0).message,
        'XPath evaluation: The min function was provided the incorrect '
        'number of arguments:0. It expected at least 1 argument.',
      );
    });

    test('type mismatch', () {
      expect(
        XPathTypeMismatchException('x').message,
        'XPath evaluation: type mismatch \nx',
      );
    });

    test('unhandled and unsupported', () {
      expect(
        XPathUnhandledException('function \'floor\'').message,
        'XPath evaluation: cannot handle function \'floor\'',
      );
      expect(
        XPathUnsupportedException('axis').message,
        'XPath evaluation: unsupported construct [axis]',
      );
    });

    test('missing instance', () {
      final e = XPathMissingInstanceException('towns');
      expect(e.message, 'XPath evaluation: Instance towns is missing');
      expect(e.instanceName, 'towns');
    });

    test('source is prepended', () {
      final e = XPathUnhandledException('x')..source = '/data/q1';
      expect(
        e.message,
        'The problem was located in /data/q1\nXPath evaluation: cannot handle x',
      );
    });

    test('no-arg exceptions have no message', () {
      expect(XPathUnhandledException().message, isNull);
    });
  });

  test('syntax exception keeps raw message', () {
    expect(const XPathSyntaxException('bad').toString(), 'bad');
  });
}
