// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XPathSyntaxException, XPathException,
//  XPathArityException, XPathTypeMismatchException, XPathUnhandledException,
//  XPathUnsupportedException, XPathMissingInstanceException), Copyright (C)
//  2009 JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// Port of the `org.javarosa.xpath` exception classes.
///
/// Messages match JavaRosa's exactly so conformance traces can compare
/// error output with the JVM oracle.
library;

/// Raised when an XPath expression cannot be parsed.
///
/// Port of `org.javarosa.xpath.parser.XPathSyntaxException`.
final class XPathSyntaxException implements Exception {
  /// Creates a syntax exception with an optional [message].
  const XPathSyntaxException([this.message]);

  /// Description of the syntax error, or `null` if none was given.
  final String? message;

  @override
  String toString() => message ?? 'XPathSyntaxException';
}

/// An error raised while evaluating an XPath expression; also the base
/// class of the more specific XPath errors below.
///
/// Port of `org.javarosa.xpath.XPathException`.
class XPathException implements Exception {
  /// Creates an exception; the message is `XPath evaluation: [detail]`.
  XPathException([String? detail])
    : _message = detail == null ? null : 'XPath evaluation: $detail';

  final String? _message;

  /// Where the failing expression was declared (for example a bind
  /// nodeset), attached by the engine once it is known.
  String? source;

  /// The message including [source], formatted as JavaRosa does.
  String? get message {
    final source = this.source;
    if (source == null) return _message;
    return 'The problem was located in $source\n$_message';
  }

  @override
  String toString() => message ?? runtimeType.toString();
}

/// A function was called with the wrong number of arguments.
///
/// Port of `org.javarosa.xpath.XPathArityException`.
final class XPathArityException extends XPathException {
  /// The function [functionName] expected exactly [expectedArity] arguments
  /// but received [providedArity].
  XPathArityException(
    this.functionName,
    int this.expectedArity,
    this.providedArity,
  ) : super(_format(functionName, '$expectedArity arguments', providedArity));

  /// The function [functionName] received [providedArity] arguments, which
  /// does not satisfy [expectedArityMessage] (for example "at least 2").
  XPathArityException.described(
    this.functionName,
    String expectedArityMessage,
    this.providedArity,
  ) : expectedArity = null,
      super(_format(functionName, expectedArityMessage, providedArity));

  /// Name of the function that was called.
  final String functionName;

  /// The exact arity expected, or `null` when the rule is not a single number.
  final int? expectedArity;

  /// Number of arguments actually provided.
  final int providedArity;

  static String _format(String name, String expected, int provided) =>
      'The $name function was provided the incorrect number of arguments:'
      '$provided. It expected $expected.';
}

/// A value could not be converted to the type an operation requires.
///
/// Port of `org.javarosa.xpath.XPathTypeMismatchException`.
final class XPathTypeMismatchException extends XPathException {
  /// Creates a type-mismatch exception described by [detail].
  XPathTypeMismatchException([String? detail])
    : super(detail == null ? null : 'type mismatch \n$detail');
}

/// The expression uses something the evaluator cannot handle, such as an
/// unknown function.
///
/// Port of `org.javarosa.xpath.XPathUnhandledException`.
final class XPathUnhandledException extends XPathException {
  /// Creates an exception for the unhandled construct [what].
  XPathUnhandledException([String? what])
    : super(what == null ? null : 'cannot handle $what');
}

/// The expression uses valid XPath that JavaRosa deliberately does not
/// support, such as an unsupported axis.
///
/// Port of `org.javarosa.xpath.XPathUnsupportedException`.
final class XPathUnsupportedException extends XPathException {
  /// Creates an exception for the unsupported [construct].
  XPathUnsupportedException([String? construct])
    : super(construct == null ? null : 'unsupported construct [$construct]');
}

/// The expression references a secondary instance that does not exist.
///
/// Port of `org.javarosa.xpath.XPathMissingInstanceException`.
final class XPathMissingInstanceException extends XPathException {
  /// Creates an exception for the missing instance [instanceName], with an
  /// optional custom [detail] message.
  XPathMissingInstanceException(this.instanceName, [String? detail])
    : super(detail ?? 'Instance $instanceName is missing');

  /// The `id` of the missing instance.
  final String instanceName;
}
