// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (ExternalParamsException, ExternalAppIntentProvider,
//  ExternalAppsUtils), Copyright (C) 2014 University of Washington; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

/// A parameter of an external app (`ex:` appearance or group `intent`)
/// that couldn't be evaluated. Port of ODK Collect's
/// `ExternalParamsException`.
class ExternalParamsException implements Exception {
  /// Creates the exception.
  ExternalParamsException(this.message, [this.cause]);

  /// What went wrong.
  final String message;

  /// The underlying error.
  final Object? cause;

  @override
  String toString() => message;
}

/// Thrown by `XFormDelegates.launchExternalApp` when no app handles the
/// request (Android's `ActivityNotFoundException`); the question then
/// shows the form's `noAppErrorString` and accepts typed answers.
class ExternalAppNotFoundException implements Exception {
  /// Creates the exception.
  const ExternalAppNotFoundException([this.message]);

  /// Details, if any.
  final String? message;

  @override
  String toString() => message ?? 'ExternalAppNotFoundException';
}

/// The external app of an appearance such as
/// `ex:org.app.ACTION(key='value', other=/data/q)`: everything from `ex:`
/// to the last `)` (or to the next space), without `ex:`; `null` without
/// `ex:`. Port of the parsing in ODK Collect's `ExternalAppIntentProvider
/// .getIntentToRunExternalApp`.
String? externalAppSpec(String? appearance) {
  if (appearance == null) return null;
  final start = appearance.toLowerCase().indexOf('ex:');
  if (start == -1) return null;
  var spec = appearance.substring(start);
  if (spec.contains(')')) {
    spec = spec.substring(0, spec.lastIndexOf(')') + 1);
  } else if (spec.contains(' ')) {
    spec = spec.substring(0, spec.indexOf(' '));
  }
  return spec.substring(3);
}

/// Parses external app specifications and evaluates their parameters.
/// Port of ODK Collect's `ExternalAppsUtils`.
abstract final class ExternalAppsUtils {
  /// The intent (action or package) of [exString]: the text before `(`.
  static String extractIntentName(String exString) {
    if (!exString.contains('(')) {
      return exString.contains(')')
          ? exString.substring(0, exString.indexOf(')')).trim()
          : exString;
    }
    return exString.substring(0, exString.indexOf('(')).trim();
  }

  /// The `key=value` parameters between the parentheses of [exString],
  /// in order; commas inside `'...'` don't separate parameters.
  static Map<String, String> extractParameters(String exString) {
    final text = exString.trim();
    final leftParIndex = text.indexOf('(');
    if (leftParIndex == -1) return const {};
    final paramsStr = text.endsWith(')')
        ? text.substring(leftParIndex + 1, text.lastIndexOf(')'))
        : text.substring(leftParIndex + 1);
    final parameters = <String, String>{};
    for (final pair in _paramPairs(paramsStr.trim())) {
      final keyValue = _javaSplit(pair.trim(), '=');
      if (keyValue.length == 2) {
        parameters[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    return parameters;
  }

  static List<String> _paramPairs(String paramsStr) {
    final pairs = <String>[];
    var startPos = 0;
    var inQuotes = false;
    for (var current = 0; current < paramsStr.length; current++) {
      if (paramsStr[current] == "'") inQuotes = !inQuotes;
      if (current == paramsStr.length - 1) {
        pairs.add(paramsStr.substring(startPos));
      } else if (paramsStr[current] == ',' && !inQuotes) {
        pairs.add(paramsStr.substring(startPos, current));
        startPos = current + 1;
      }
    }
    return pairs;
  }

  /// Java's `String.split`: trailing empty strings are removed.
  static List<String> _javaSplit(String text, String separator) {
    final parts = text.split(separator);
    while (parts.length > 1 && parts.last.isEmpty) {
      parts.removeLast();
    }
    return parts;
  }

  /// The value of the parameter [text]: a `'constant'` (the closing quote
  /// is optional), `instanceProviderID()` ([instanceProviderId], `-1` for
  /// unsaved instances), or an XPath expression evaluated at [reference]
  /// in [form].
  static Object? getValueRepresentedBy(
    String text,
    TreeReference? reference,
    FormDef form, {
    String instanceProviderId = '-1',
  }) {
    if (text.startsWith("'")) {
      return text.endsWith("'") && text.length > 1
          ? text.substring(1, text.length - 1)
          : text.substring(1);
    }
    if (text == 'instanceProviderID()') return instanceProviderId;
    final context = reference == null
        ? form.evaluationContext
        : EvaluationContext.withContext(form.evaluationContext, reference);
    return unpack(parseXPath(text).eval(form.mainInstance, context));
  }

  /// Evaluates every parameter of [parameters] at [reference] (see
  /// [getValueRepresentedBy]); throws an [ExternalParamsException] for
  /// one that fails.
  static Map<String, Object?> evaluateParameters(
    Map<String, String> parameters,
    TreeReference? reference,
    FormDef form, {
    String instanceProviderId = '-1',
  }) => {
    for (final MapEntry(:key, :value) in parameters.entries)
      key: () {
        try {
          return getValueRepresentedBy(
            value,
            reference,
            form,
            instanceProviderId: instanceProviderId,
          );
        } on Object catch (e) {
          throw ExternalParamsException("Could not evaluate '$value'", e);
        }
      }(),
  };

  /// [value] as a string answer, or `null`.
  static StringValue? asStringData(Object? value) =>
      value == null ? null : StringValue('$value');

  /// [value] as an integer answer, or `null` if it isn't one.
  static IntegerValue? asIntegerData(Object? value) {
    if (value == null) return null;
    final i = javaParseInt('$value');
    return i == null ? null : IntegerValue(i);
  }

  /// [value] as a decimal answer, or `null` if it isn't one.
  static DecimalValue? asDecimalData(Object? value) {
    if (value == null) return null;
    final d = javaParseDouble('$value');
    return d == null ? null : DecimalValue(d);
  }
}
