import 'package:clock/clock.dart';
import 'package:logging/logging.dart';

import '../../util/java_lang.dart';
import '../../util/uuid.dart';
import '../data/answer_value.dart';
import '../instance/tree_element.dart';
import 'date_utils.dart' as date_utils;

final _log = Logger('dartrosa.preload');

/// Device and user properties such as `deviceid`, `username` or `email`,
/// read by `jr:preload="property"` and the XPath `property()` function.
///
/// Port of JavaRosa's global `PropertyManager` (its singular-property
/// subset), as an object the app provides.
abstract interface class PropertyManager {
  /// The value of property [name], if set.
  String? getProperty(String name);

  /// Sets property [name] (done by `property` preloads on finalization).
  void setProperty(String name, String value);
}

/// A [PropertyManager] backed by a map.
final class MapPropertyManager implements PropertyManager {
  /// Creates a manager with the initial [properties].
  MapPropertyManager([Map<String, String> properties = const {}])
    : _properties = {...properties};

  final Map<String, String> _properties;

  @override
  String? getProperty(String name) => _properties[name];

  @override
  void setProperty(String name, String value) => _properties[name] = value;
}

/// Fills a `jr:preload` node when a form starts, and optionally again when
/// it is finalized.
///
/// Port of `org.javarosa.core.model.utils.IPreloadHandler`.
abstract interface class PreloadHandler {
  /// The `jr:preload` value handled, for example `timestamp`.
  String get preloadHandled;

  /// The initial value for `jr:preloadParams` [params], if any.
  AnswerValue? handlePreload(String? params);

  /// Updates [node] on finalization; whether it changed.
  bool handlePostProcess(TreeElement node, String? params);
}

/// The `jr:preload` handlers of a form: `date`, `property`, `timestamp` and
/// `uid`, plus any added with [addPreloadHandler].
///
/// Port of `org.javarosa.core.model.utils.QuestionPreloader`.
final class QuestionPreloader {
  /// Creates a preloader reading properties from [properties].
  QuestionPreloader({PropertyManager? properties})
    : properties = properties ?? MapPropertyManager() {
    addPreloadHandler(_DatePreloadHandler());
    addPreloadHandler(_PropertyPreloadHandler(this));
    addPreloadHandler(_TimestampPreloadHandler());
    addPreloadHandler(_UidPreloadHandler());
  }

  /// The properties used by `property` preloads.
  final PropertyManager properties;

  final Map<String, PreloadHandler> _handlers = {};

  /// Adds (or replaces) the handler for [PreloadHandler.preloadHandled].
  void addPreloadHandler(PreloadHandler handler) =>
      _handlers[handler.preloadHandled] = handler;

  /// The initial value for a `jr:preload` [type] with [params].
  AnswerValue? getQuestionPreload(String type, String? params) {
    final handler = _handlers[type];
    if (handler == null) {
      _log.severe('Do not know how to handle preloader [$type]');
      return null;
    }
    return handler.handlePreload(params);
  }

  /// Runs the finalization step of preload [type] on [node]; whether the
  /// node changed.
  bool questionPostProcess(TreeElement node, String type, String? params) {
    final handler = _handlers[type];
    if (handler == null) {
      _log.severe('Do not know how to handle preloader [$type]');
      return false;
    }
    return handler.handlePostProcess(node, params);
  }
}

final class _DatePreloadHandler implements PreloadHandler {
  @override
  String get preloadHandled => 'date';

  @override
  AnswerValue? handlePreload(String? params) {
    if (params == null) {
      // JavaRosa fails with a NullPointerException.
      throw ArgumentError("invalid preload params for preload mode 'date'");
    }
    DateTime? date;
    if (params == 'today') {
      date = clock.now();
    } else if (params.substring(0, 11) == 'prevperiod-') {
      // `prevperiod-<type>-<start>-<head|tail>[-x|-][-<nAgo>]`
      final p = date_utils.split(params.substring(11), '-');
      try {
        final beginning = switch (p[2]) {
          'head' => true,
          'tail' => false,
          _ => throw const FormatException(),
        };
        // A missing fourth part means "exclude today", like an empty one.
        final includeToday = switch (p.length >= 4 ? p[3] : '') {
          'x' => true,
          '' => false,
          _ => throw const FormatException(),
        };
        final nAgo = p.length >= 5
            ? javaParseInt(p[4]) ?? (throw const FormatException())
            : 1;
        date = date_utils.getPastPeriodDate(
          clock.now(),
          p[0],
          p[1],
          beginning: beginning,
          includeToday: includeToday,
          nAgo: nAgo,
        );
      } on Object {
        throw ArgumentError("invalid preload params for preload mode 'date'");
      }
    }
    if (date == null) {
      // JavaRosa's `new DateData(null)` fails with a NullPointerException.
      throw ArgumentError("invalid preload params for preload mode 'date'");
    }
    return DateValue(date);
  }

  @override
  bool handlePostProcess(TreeElement node, String? params) => false;
}

final class _PropertyPreloadHandler implements PreloadHandler {
  _PropertyPreloadHandler(this._preloader);

  final QuestionPreloader _preloader;

  @override
  String get preloadHandled => 'property';

  @override
  AnswerValue? handlePreload(String? params) {
    if (params == null) return null;
    final value = _preloader.properties.getProperty(params);
    return value != null && value.isNotEmpty ? StringValue(value) : null;
  }

  @override
  bool handlePostProcess(TreeElement node, String? params) {
    final value = node.value?.displayText;
    if (params != null &&
        params.isNotEmpty &&
        value != null &&
        value.isNotEmpty) {
      _preloader.properties.setProperty(params, value);
    }
    return false;
  }
}

final class _TimestampPreloadHandler implements PreloadHandler {
  @override
  String get preloadHandled => 'timestamp';

  @override
  AnswerValue? handlePreload(String? params) =>
      params == 'start' ? DateTimeValue(clock.now()) : null;

  @override
  bool handlePostProcess(TreeElement node, String? params) {
    if (params != 'end') return false;
    node.setAnswer(DateTimeValue(clock.now()));
    return true;
  }
}

final class _UidPreloadHandler implements PreloadHandler {
  @override
  String get preloadHandled => 'uid';

  @override
  AnswerValue? handlePreload(String? params) =>
      StringValue('uuid:${randomUuid()}');

  @override
  bool handlePostProcess(TreeElement node, String? params) => false;
}
