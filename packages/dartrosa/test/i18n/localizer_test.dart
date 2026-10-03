// Port of JavaRosa v6.0.0 LocalizerTest.
//
// Not ported: testSerialization (JavaRosa's Externalizable serialization is
// replaced in DartRosa) and the null-argument cases of testNullArgs whose
// parameters are non-nullable in Dart (addAvailableLocale, the locale and
// resource of registerLocaleResource, setLocaleMapping's id, destroyLocale,
// getText's id): the type system rejects those calls.
import 'package:dartrosa/src/i18n/locale_exceptions.dart';
import 'package:dartrosa/src/i18n/locale_source.dart';
import 'package:dartrosa/src/i18n/localizer.dart';
import 'package:test/test.dart';

const testLocale = 'test';

final throwsUnregistered = throwsA(isA<UnregisteredLocaleException>());

final class LocalizationObserver implements Localizable {
  bool flag = false;
  String? locale;
  Localizer? localizer;

  @override
  void localeChanged(String locale, Localizer localizer) {
    flag = true;
    this.locale = locale;
    this.localizer = localizer;
  }
}

void main() {
  test('empty', () {
    final l = Localizer();
    expect(l.availableLocales, isEmpty);
    expect(l.locale, isNull);
    expect(l.defaultLocale, isNull);
  });

  test('add locale', () {
    final l = Localizer();
    expect(l.hasLocale(testLocale), isFalse);
    expect(l.addAvailableLocale(testLocale), isTrue);
    expect(l.hasLocale(testLocale), isTrue);
    expect(l.getLocaleData(testLocale), isEmpty);
  });

  test('add locale with data', () {
    final l = Localizer();
    final data = TableLocaleSource()..setLocaleMapping('textID', 'text');
    expect(l.hasLocale(testLocale), isFalse);
    l
      ..addAvailableLocale(testLocale)
      ..registerLocaleResource(testLocale, data);
    expect(l.hasLocale(testLocale), isTrue);
    expect(l.getRawText(testLocale, 'textID'), data.localizedText['textID']);
  });

  test('add existing locale', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    final table = TableLocaleSource()..setLocaleMapping('textID', 'text');
    l.registerLocaleResource(testLocale, table);
    final before = l.getLocaleData(testLocale);
    expect(l.addAvailableLocale(testLocale), isFalse);
    expect(l.getLocaleData(testLocale), before);
  });

  test('set current locale that exists', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..locale = testLocale;
    expect(l.locale, testLocale);
  });

  test('set current locale that does not exist', () {
    expect(() => Localizer().locale = testLocale, throwsUnregistered);
  });

  test('unset current locale', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..locale = testLocale;
    expect(() => l.locale = null, throwsUnregistered);
  });

  test('set default locale that exists', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..defaultLocale = testLocale;
    expect(l.defaultLocale, testLocale);
  });

  test('set default locale that does not exist', () {
    expect(() => Localizer().defaultLocale = testLocale, throwsUnregistered);
  });

  test('unset default locale', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..defaultLocale = testLocale
      ..defaultLocale = null;
    expect(l.defaultLocale, isNull);
  });

  test('set to default', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..defaultLocale = testLocale
      ..setToDefault();
    expect(l.locale, testLocale);
  });

  test('set to default with no default', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    expect(l.setToDefault, throwsStateError);
  });

  test('destroy locale', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    expect(l.destroyLocale(testLocale), isTrue);
    expect(l.hasLocale(testLocale), isFalse);
  });

  test('destroy locale that does not exist', () {
    expect(Localizer().destroyLocale(testLocale), isFalse);
  });

  test('destroy current locale', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..locale = testLocale;
    expect(() => l.destroyLocale(testLocale), throwsArgumentError);
  });

  test('destroy default locale', () {
    final l = Localizer()
      ..addAvailableLocale(testLocale)
      ..defaultLocale = testLocale
      ..destroyLocale(testLocale);
    expect(l.defaultLocale, isNull);
  });

  test('available locales', () {
    final l = Localizer()..addAvailableLocale('test1');
    expect(l.availableLocales, ['test1']);
    l.addAvailableLocale('test2');
    expect(l.availableLocales, ['test1', 'test2']);
    l.addAvailableLocale('test3');
    expect(l.availableLocales, ['test1', 'test2', 'test3']);
    l.destroyLocale('test2');
    expect(l.availableLocales, ['test1', 'test3']);
    l.destroyLocale('test1');
    expect(l.availableLocales, ['test3']);
    l.destroyLocale('test3');
    expect(l.availableLocales, isEmpty);
  });

  test('next locale', () {
    final l = Localizer()
      ..addAvailableLocale('test1')
      ..addAvailableLocale('test2')
      ..addAvailableLocale('test3');
    expect(l.nextLocale, isNull);
    l.defaultLocale = 'test3';
    expect(l.nextLocale, 'test3');
    l
      ..defaultLocale = null
      ..locale = 'test1';
    expect(l.nextLocale, 'test2');
    l.locale = 'test2';
    expect(l.nextLocale, 'test3');
    l.locale = 'test3';
    expect(l.nextLocale, 'test1');
  });

  test('locale map', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    expect(l.getLocaleMap(testLocale), l.getLocaleData(testLocale));
  });

  test('locale map for a locale that does not exist', () {
    expect(() => Localizer().getLocaleMap(testLocale), throwsUnregistered);
  });

  test('text mapping', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    expect(l.hasMapping(testLocale, 'textID'), isFalse);
    l.registerLocaleResource(
      testLocale,
      TableLocaleSource()..setLocaleMapping('textID', 'text'),
    );
    expect(l.hasMapping(testLocale, 'textID'), isTrue);
    expect(l.getLocaleData(testLocale)!['textID'], 'text');
  });

  test('text mapping overwrite', () {
    final l = Localizer()..addAvailableLocale(testLocale);
    l.registerLocaleResource(
      testLocale,
      TableLocaleSource()
        ..setLocaleMapping('textID', 'oldText')
        ..setLocaleMapping('textID', 'newText'),
    );
    expect(l.hasMapping(testLocale, 'textID'), isTrue);
    expect(l.getLocaleData(testLocale)!['textID'], 'newText');
  });

  group('getText fallback matrix', () {
    const defaultLocaleCase = 1;
    const nonDefaultLocaleCase = 2;
    const customForm = 2;

    Localizer build(
      int i,
      int j,
      int k,
      String ourLocale,
      String? otherLocale,
    ) {
      final l = Localizer(
        fallbackDefaultLocale: i ~/ 2 == 0,
        fallbackDefaultForm: i % 2 == 0,
      );
      final first = TableLocaleSource();
      final second = TableLocaleSource();
      if (j ~/ 2 == 0 || ourLocale == 'default') {
        first.setLocaleMapping('textID', 'text:$ourLocale:base');
      }
      if (j % 2 == 0 || ourLocale == 'default') {
        first.setLocaleMapping('textID;form', 'text:$ourLocale:form');
      }
      if (otherLocale != null) {
        if (k ~/ 2 == 0 || otherLocale == 'default') {
          second.setLocaleMapping('textID', 'text:$otherLocale:base');
        }
        if (k % 2 == 0 || otherLocale == 'default') {
          second.setLocaleMapping('textID;form', 'text:$otherLocale:form');
        }
      }
      l
        ..addAvailableLocale(ourLocale)
        ..registerLocaleResource(ourLocale, first);
      if (otherLocale != null) {
        l
          ..addAvailableLocale(otherLocale)
          ..registerLocaleResource(otherLocale, second);
      }
      if (l.hasLocale('default')) l.defaultLocale = 'default';
      l.locale = ourLocale;
      return l;
    }

    String? expectedText(String textId, Localizer l) {
      final hasForm = textId.contains(';');
      final hasDefault = l.defaultLocale != null && l.defaultLocale != l.locale;
      final baseId = hasForm
          ? textId.substring(0, textId.indexOf(';'))
          : textId;
      final searchOrder = [
        hasForm,
        !hasForm || l.fallbackDefaultForm,
        hasForm && hasDefault && l.fallbackDefaultLocale,
        (!hasForm || l.fallbackDefaultForm) &&
            hasDefault &&
            l.fallbackDefaultLocale,
      ];
      String? text;
      for (var i = 0; text == null && i < 4; i++) {
        if (!searchOrder[i]) continue;
        text = switch (i + 1) {
          1 => l.getRawText(l.locale, textId),
          2 => l.getRawText(l.locale, baseId),
          3 => l.getRawText(l.defaultLocale, textId),
          _ => l.getRawText(l.defaultLocale, baseId),
        };
      }
      return text;
    }

    void check(
      int i,
      int j,
      int k,
      String ourLocale,
      String? other,
      String textId,
    ) {
      final l = build(i, j, k, ourLocale, other);
      final expected = expectedText(textId, l);
      expect(l.getTextForLocale(textId, ourLocale), expected);
      if (expected == null) {
        expect(
          () => l.getLocalizedText(textId),
          throwsA(isA<NoLocalizedTextException>()),
        );
      } else {
        expect(l.getLocalizedText(textId), expected);
      }
    }

    for (var localeCase = 1; localeCase <= 3; localeCase++) {
      for (var formCase = 1; formCase <= 2; formCase++) {
        test('locale case $localeCase, form case $formCase', () {
          final (ourLocale, otherLocale) = switch (localeCase) {
            defaultLocaleCase => ('default', null),
            nonDefaultLocaleCase => ('other', 'default'),
            _ => ('neutral', null),
          };
          final textId = 'textID${formCase == customForm ? ';form' : ''}';
          for (var i = 0; i < 4; i++) {
            for (var j = 0; j < 4; j++) {
              if (otherLocale == null) {
                check(i, j, -1, ourLocale, otherLocale, textId);
              } else {
                for (var k = 0; k < 4; k++) {
                  check(i, j, k, ourLocale, otherLocale, textId);
                }
              }
            }
          }
        });
      }
    }
  });

  test('getText with no current locale', () {
    final l = Localizer()
      ..addAvailableLocale('test')
      ..defaultLocale = 'test'
      ..registerLocaleResource(
        'test',
        TableLocaleSource()..setLocaleMapping('textID', 'text'),
      );
    expect(() => l.getText('textID'), throwsUnregistered);
  });

  test('localization observers', () {
    final l = Localizer()
      ..addAvailableLocale('test1')
      ..addAvailableLocale('test2');
    final lo = LocalizationObserver();
    l.registerLocalizable(lo);
    expect((lo.flag, lo.locale, lo.localizer), (false, null, null));
    l.locale = 'test1';
    expect(lo.flag, isTrue);
    expect(lo.locale, 'test1');
    expect(identical(lo.localizer, l), isTrue);
    lo.flag = false;
    l.locale = 'test2';
    expect((lo.flag, lo.locale), (true, 'test2'));
    lo.flag = false;
    l.locale = 'test2';
    expect((lo.flag, lo.locale), (false, 'test2'));
    l
      ..unregisterLocalizable(lo)
      ..locale = 'test1';
    expect((lo.flag, lo.locale), (false, 'test2'));
  });

  test('observer is updated on registration', () {
    final l = Localizer()
      ..addAvailableLocale('test1')
      ..locale = 'test1';
    final lo = LocalizationObserver();
    l.registerLocalizable(lo);
    expect((lo.flag, lo.locale), (true, 'test1'));
    expect(identical(lo.localizer, l), isTrue);
  });

  test('null arguments (those Dart allows)', () {
    final l = Localizer()..addAvailableLocale('test');
    expect(l.hasLocale(null), isFalse);
    expect(l.getLocaleData(null), isNull);
    expect(() => l.getLocaleMap(null), throwsUnregistered);
    expect(() => l.hasMapping(null, 'textID'), throwsUnregistered);
    expect(l.hasMapping('test', null), isFalse);
    expect(() => l.getTextForLocale('textID', null), throwsUnregistered);
  });

  test('linear substitution', () {
    const f = 'first';
    const s = 'second';
    const res = ['One', 'Two'];
    expect(Localizer.processArguments(r'${0}', [f]), f);
    expect(Localizer.processArguments(r'${0},${1}', [f, s]), '$f,$s');
    expect(Localizer.processArguments(r'testing ${0}', [f]), 'testing $f');
    expect(Localizer.processArguments(r'1${arbitrary}2', [f]), '1${f}2');
    // Substituted text is not processed again.
    expect(Localizer.processArguments(r'${0}', [r'${0}']), r'${0}');
    var holder = Localizer.processArguments(r'${0}', [r'${1}${0}']);
    expect(holder, r'${1}${0}');
    holder = Localizer.processArguments(holder, res);
    expect(holder, '${res[1]}${res[0]}');
    expect(Localizer.processArguments(r'$ {0} ${1}', res), '\$ {0} ${res[1]}');
  });

  test('named substitution', () {
    const f = 'first';
    const s = 'second';
    final h = {'fir': f, 'also first': f, 'sec': s};
    expect(Localizer.processNamedArguments(r'${fir}', h), f);
    expect(Localizer.processNamedArguments(r'${fir},${sec}', h), '$f,$s');
    expect(Localizer.processNamedArguments(r'${sec},${fir}', h), '$s,$f');
    expect(Localizer.processNamedArguments(r'${empty}', h), r'${empty}');
    expect(
      Localizer.processNamedArguments(r'${fir},${fir},${also first}', h),
      '$f,$f,$f',
    );
  });

  test('fallbacks', () {
    final localizer =
        Localizer(fallbackDefaultLocale: true, fallbackDefaultForm: true)
          ..addAvailableLocale('one')
          ..addAvailableLocale('two');
    final first = TableLocaleSource()
      ..setLocaleMapping('data', 'val')
      ..setLocaleMapping('data2', 'vald2');
    localizer.registerLocaleResource('one', first);
    final second = TableLocaleSource();
    first.setLocaleMapping('data', 'val2');
    localizer
      ..registerLocaleResource('two', second)
      ..defaultLocale = 'one'
      ..locale = 'two';
    expect(localizer.getText('data2'), 'vald2');
    expect(localizer.getText('noexist'), isNull);
    localizer.setToDefault();
    expect(localizer.getText('noexist'), isNull);
  });

  // Not in LocalizerTest: the remaining public helpers.
  group('helpers', () {
    test('getArgs and clearArguments', () {
      expect(Localizer.getArgs(r'${a} and ${b} and ${a}'), ['a', 'b']);
      expect(Localizer.clearArguments(r'x${a}y${0}z'), 'xyz');
    });

    test('getTextWithArgs / getTextWithNamedArgs', () {
      final l = Localizer()
        ..addAvailableLocale('en')
        ..registerLocaleResource(
          'en',
          TableLocaleSource()..setLocaleMapping('greet', r'Hi ${0} ${name}'),
        )
        ..locale = 'en';
      // An explicit ${0} doesn't advance the counter (JavaRosa: 'Hi A A').
      expect(l.getTextWithArgs('greet', ['A', 'B']), 'Hi A A');
      expect(l.getTextWithNamedArgs('greet', {'name': 'N'}), r'Hi ${0} N');
      expect(
        () => l.getTextWithArgs('nope', []),
        throwsA(
          isA<NoLocalizedTextException>().having(
            (e) => e.message,
            'message',
            'The Localizer could not find a definition for ID: nope in the '
                "'en' locale.",
          ),
        ),
      );
    });

    test('missing keys in the default locale', () {
      final l = Localizer(fallbackDefaultLocale: true)
        ..addAvailableLocale('a')
        ..addAvailableLocale('b')
        ..defaultLocale = 'a'
        ..registerLocaleResource('b', TableLocaleSource({'x': '1'}));
      expect(
        () => l.getLocaleData('b'),
        throwsA(
          isA<NoLocalizedTextException>()
              .having((e) => e.missingKeyNames, 'keys', 'x,')
              .having((e) => e.localeMissingKey, 'locale', 'a'),
        ),
      );
    });

    test('parseLocaleInput', () {
      expect(
        parseLocaleInput('a=1\n# comment\nb = 2 # trailing\n\nc=\nd\r\ne=x=y'),
        {'a': '1', 'b ': ' 2 ', 'e': 'x=y'},
      );
    });
  });
}
