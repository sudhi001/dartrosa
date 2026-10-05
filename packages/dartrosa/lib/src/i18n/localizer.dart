// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (Localizable, Localizer), Copyright (C) 2009 JavaRosa;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../util/java_lang.dart';
import 'locale_exceptions.dart';
import 'locale_source.dart';

/// Receives locale changes from a [Localizer].
///
/// Port of `org.javarosa.core.services.locale.Localizable`.
abstract interface class Localizable {
  /// Called when the current locale of [localizer] becomes [locale].
  void localeChanged(String locale, Localizer localizer);
}

/// Translated text for a form: the itext engine.
///
/// Port of `org.javarosa.core.services.locale.Localizer`. A text id may
/// carry a form after a semicolon (`id;short`, `id;image`, `id;audio`,
/// `id;video`, `id;big-image`, `id;guidance`). Lookups can fall back to the
/// form-less id ([fallbackDefaultForm]) and to the default locale
/// ([fallbackDefaultLocale]); see [getTextForLocale].
final class Localizer {
  /// Creates an empty localizer; both fallback modes are off by default.
  Localizer({
    this.fallbackDefaultLocale = false,
    this.fallbackDefaultForm = false,
  });

  /// Whether lookups fall back to the default locale.
  final bool fallbackDefaultLocale;

  /// Whether lookups of `id;form` fall back to `id`.
  final bool fallbackDefaultForm;

  final _locales = <String>[];
  final _localeResources = <String, List<LocaleDataSource>>{};
  Map<String, String> _currentLocaleData = {};
  String? _defaultLocale;
  String? _currentLocale;
  final _observers = <Localizable>[];

  // ------------------------------------------------------------ locales

  /// Defines [locale] (with no mappings); returns `false` if it already
  /// exists.
  bool addAvailableLocale(String locale) {
    if (hasLocale(locale)) return false;
    _locales.add(locale);
    _localeResources[locale] = [];
    return true;
  }

  /// The defined locales, in the order they were added.
  List<String> get availableLocales => List.unmodifiable(_locales);

  /// Whether [locale] is defined (`false` for `null`).
  bool hasLocale(String? locale) => locale != null && _locales.contains(locale);

  /// The locale after the current one (cycling), the default locale if
  /// none is current, or `null`.
  String? get nextLocale => _currentLocale == null
      ? _defaultLocale
      : _locales[(_locales.indexOf(_currentLocale!) + 1) % _locales.length];

  /// The current locale, or `null` if none is set.
  String? get locale => _currentLocale;

  /// Makes [locale] current, notifying [Localizable]s if it changed.
  ///
  /// Throws [UnregisteredLocaleException] if [locale] isn't defined.
  set locale(String? locale) {
    if (locale == null || !hasLocale(locale)) {
      throw UnregisteredLocaleException(
        'Attempted to set to a locale that is not defined. Attempted '
        'Locale: $locale',
      );
    }
    final changed = locale != _currentLocale;
    _currentLocale = locale;
    _loadCurrentLocaleResources();
    if (changed) _alertLocalizables();
  }

  /// The default locale, or `null`.
  String? get defaultLocale => _defaultLocale;

  /// Sets (or, with `null`, clears) the default locale.
  ///
  /// Throws [UnregisteredLocaleException] if [locale] isn't defined.
  set defaultLocale(String? locale) {
    if (locale != null && !hasLocale(locale)) {
      throw const UnregisteredLocaleException(
        'Attempted to set default to a locale that is not defined',
      );
    }
    _defaultLocale = locale;
  }

  /// Makes the default locale current. Throws [StateError] if there is no
  /// default locale.
  void setToDefault() {
    final defaultLocale = _defaultLocale;
    if (defaultLocale == null) {
      throw StateError(
        'Attempted to set to default locale when default locale not set',
      );
    }
    locale = defaultLocale;
  }

  /// Removes [locale] and its data; clears the default locale if it was
  /// [locale]. Returns whether it existed.
  ///
  /// Throws [ArgumentError] for the current locale.
  bool destroyLocale(String locale) {
    if (locale == _currentLocale) {
      throw ArgumentError('Attempted to destroy the current locale');
    }
    final removed = hasLocale(locale);
    _locales.remove(locale);
    _localeResources.remove(locale);
    if (locale == _defaultLocale) _defaultLocale = null;
    return removed;
  }

  // ------------------------------------------------------------ data

  /// Adds [resource] as a source of text for [locale] (which need not have
  /// been defined with [addAvailableLocale]).
  void registerLocaleResource(String locale, LocaleDataSource resource) {
    (_localeResources[locale] ??= []).add(resource);
    if (locale == _currentLocale || locale == _defaultLocale) {
      _loadCurrentLocaleResources();
    }
  }

  void _loadCurrentLocaleResources() {
    _currentLocaleData = getLocaleData(_currentLocale) ?? {};
  }

  /// All mappings of [locale] (with the default locale's underneath when
  /// [fallbackDefaultLocale] is on), or `null` if [locale] isn't defined.
  ///
  /// Throws [NoLocalizedTextException] if, with the default-locale
  /// fallback, [locale] has keys the default locale lacks.
  Map<String, String>? getLocaleData(String? locale) {
    if (locale == null || !_locales.contains(locale)) return null;
    final defaultKeys = <String>{};
    final data = <String, String>{};
    final defaultLocale = _defaultLocale;
    final useDefault = fallbackDefaultLocale && defaultLocale != null;
    if (useDefault) {
      for (final resource in _localeResources[defaultLocale]!) {
        data.addAll(resource.localizedText);
      }
      defaultKeys.addAll(data.keys);
    }
    for (final resource in _localeResources[locale]!) {
      data.addAll(resource.localizedText);
    }
    if (useDefault) {
      final missing = data.keys.where((k) => !defaultKeys.contains(k)).toList();
      if (missing.isNotEmpty) {
        final missingKeys = missing.map((k) => '$k,').join();
        throw NoLocalizedTextException(
          'Error loading locale $locale. There were ${missing.length} keys '
          'which were contained in this locale, but were not properly '
          'registered in the default Locale. Any keys which are added to a '
          'locale should always be added to the default locale to ensure '
          'appropriate functioning.\n'
          'The missing translations were for the keys: $missingKeys',
          missingKeys,
          defaultLocale,
        );
      }
    }
    return data;
  }

  /// Like [getLocaleData], but throws [UnregisteredLocaleException] for an
  /// undefined locale.
  Map<String, String> getLocaleMap(String? locale) =>
      getLocaleData(locale) ??
      (throw const UnregisteredLocaleException(
        'Attempted to access an undefined locale.',
      ));

  /// Whether [locale]'s own sources map [textId] (no fallbacks). Throws
  /// [UnregisteredLocaleException] if [locale] isn't defined.
  bool hasMapping(String? locale, String? textId) {
    if (locale == null || !_locales.contains(locale)) {
      throw UnregisteredLocaleException(
        'Attempted to access an undefined locale ($locale) while checking for '
        'a mapping for  $textId',
      );
    }
    return _localeResources[locale]!.any(
      (source) => source.localizedText.containsKey(textId),
    );
  }

  // ------------------------------------------------------------ lookup

  /// The text for [textId] in the current locale with fallbacks, or `null`.
  ///
  /// Throws [UnregisteredLocaleException] if no locale is current.
  String? getText(String textId) => getTextForLocale(textId, _currentLocale);

  /// The text for [textId] in the current locale with `${0}`, `${1}`…
  /// replaced by [args]. Throws [NoLocalizedTextException] if missing.
  String getTextWithArgs(String textId, List<String> args) {
    final text = getText(textId);
    if (text == null) throw _noText(textId);
    return processArguments(text, args);
  }

  /// The text for [textId] in the current locale with `${name}` replaced
  /// from [args]. Throws [NoLocalizedTextException] if missing.
  String getTextWithNamedArgs(String textId, Map<String, String> args) {
    final text = getText(textId);
    if (text == null) throw _noText(textId);
    return processNamedArguments(text, args);
  }

  /// Like [getText], but throws [NoLocalizedTextException] if there is no
  /// text.
  String getLocalizedText(String textId) =>
      getText(textId) ?? (throw _noText(textId));

  NoLocalizedTextException _noText(String textId) => NoLocalizedTextException(
    'The Localizer could not find a definition for ID: $textId in the '
    "'$_currentLocale' locale.",
    textId,
    _currentLocale,
  );

  /// The text for [textId] in [locale], searching in order:
  /// 1. [locale], the given form;
  /// 2. [locale], no form (if [fallbackDefaultForm] and a form was given);
  /// 3. then the same in the default locale, if both fallbacks are on and
  ///    [locale] isn't the default.
  ///
  /// Returns `null` if nothing is found. Throws
  /// [UnregisteredLocaleException] if [locale] is `null` or undefined.
  String? getTextForLocale(String textId, String? locale) {
    var text = getRawText(locale, textId);
    if (text == null && fallbackDefaultForm && textId.contains(';')) {
      text = getRawText(locale, textId.substring(0, textId.indexOf(';')));
    }
    final defaultLocale = _defaultLocale;
    if (text == null &&
        fallbackDefaultLocale &&
        locale != defaultLocale &&
        defaultLocale != null &&
        fallbackDefaultForm) {
      text = getTextForLocale(textId, defaultLocale);
    }
    return text;
  }

  /// The text for exactly [textId] in [locale], without fallbacks.
  ///
  /// For a locale other than the current one, the default locale's text is
  /// included when [fallbackDefaultLocale] is on (as in JavaRosa). Throws
  /// [UnregisteredLocaleException] if [locale] is `null` or undefined.
  String? getRawText(String? locale, String textId) {
    if (locale == null) {
      throw UnregisteredLocaleException(
        'Null locale when attempting to fetch text id: $textId',
      );
    }
    return locale == _currentLocale
        ? _currentLocaleData[textId]
        : getLocaleMap(locale)[textId];
  }

  // ------------------------------------------------------------ observers

  /// Registers [localizable] (once); it is told the current locale at once
  /// if one is set.
  void registerLocalizable(Localizable localizable) {
    if (_observers.contains(localizable)) return;
    _observers.add(localizable);
    final current = _currentLocale;
    if (current != null) localizable.localeChanged(current, this);
  }

  /// Unregisters [localizable].
  void unregisterLocalizable(Localizable localizable) =>
      _observers.remove(localizable);

  /// Unregisters all [Localizable]s.
  void unregisterAll() => _observers.clear();

  void _alertLocalizables() {
    for (final observer in [..._observers]) {
      observer.localeChanged(_currentLocale!, this);
    }
  }

  // ------------------------------------------------------------ arguments

  /// The distinct `${...}` argument names in [text], in order.
  static List<String> getArgs(String text) {
    final args = <String>[];
    var i = text.indexOf(r'${');
    while (i != -1) {
      final j = text.indexOf('}', i);
      if (j == -1) break; // unterminated ${...}
      final arg = text.substring(i + 2, j);
      if (!args.contains(arg)) args.add(arg);
      i = text.indexOf(r'${', j + 1);
    }
    return args;
  }

  /// Replaces `${name}` in [text] with values from [args]; unknown names
  /// are left as is. Substituted text is not processed again.
  static String processNamedArguments(String text, Map<String, String> args) {
    var result = text;
    var i = result.indexOf(r'${');
    while (i != -1) {
      var j = result.indexOf('}', i);
      if (j == -1) break; // unterminated ${...}
      final value = args[result.substring(i + 2, j)];
      if (value != null) {
        result = result.substring(0, i) + value + result.substring(j + 1);
        j = i + value.length - 1;
      }
      i = result.indexOf(r'${', j + 1);
    }
    return result;
  }

  /// Replaces `${...}` placeholders in [text] with [args]: `${n}` takes
  /// `args[n]` when n is a valid index, any other placeholder takes the
  /// next unused argument. Substituted text is not processed again.
  static String processArguments(
    String text,
    List<String> args, [
    int currentArg = 0,
  ]) {
    if (!text.contains(r'${') || args.length <= currentArg) return text;
    var index = _extractNextIndex(text, args);
    var nextArg = currentArg;
    if (index == -1) {
      index = currentArg;
      nextArg++;
    }
    final start = text.indexOf(r'${');
    final end = text.indexOf('}', start);
    return text.substring(0, start) +
        args[index] +
        processArguments(text.substring(end + 1), args, nextArg);
  }

  /// [text] with every `${...}` placeholder removed.
  static String clearArguments(String text) =>
      processArguments(text, List.filled(getArgs(text).length, ''));

  static int _extractNextIndex(String text, List<String> args) {
    final start = text.indexOf(r'${');
    final end = text.indexOf('}', start);
    if (start != -1 && end != -1) {
      final index = javaParseInt(text.substring(start + 2, end));
      if (index != null && index >= 0 && index < args.length) return index;
    }
    return -1;
  }
}
