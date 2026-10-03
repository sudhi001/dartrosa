/// The XPath function library. Port of `XPathFuncExpr.eval` and its
/// helpers.
library;

import '../model/condition/evaluation_context.dart';
import '../model/instance/data_instance.dart';
import 'conversions.dart';
import 'exceptions.dart';
import 'expression.dart';
import 'nodeset.dart';

/// Evaluates the function call [call].
///
/// Built-in functions are checked first, then custom handlers registered on
/// [context], then its fallback handler; otherwise an
/// [XPathUnhandledException] is thrown.
Object evalFunction(
  XPathFuncExpr call,
  DataInstance? model,
  EvaluationContext context,
) {
  final name = call.id.toString();
  final args = [for (final arg in call.args) arg.eval(model, context)];

  final handler = context.functionHandlers[name];
  if (handler != null) return _evalCustom(handler, args, context);
  final fallback = context.fallbackFunctionHandler;
  if (fallback != null) return fallback.eval(name, args, context);
  throw XPathUnhandledException("function '$name'");
}

/// Matches [args] to the handler's prototypes (converting types), falling
/// back to the raw arguments when the handler accepts them.
Object _evalCustom(
  XPathFunctionHandler handler,
  List<Object> args,
  EvaluationContext context,
) {
  for (final prototype in handler.prototypes) {
    final typed = _matchPrototype(args, prototype);
    if (typed != null) return handler.eval(typed, context);
  }
  if (handler.rawArgs) return handler.eval(args, context);
  throw XPathTypeMismatchException("for function '${handler.name}'");
}

List<Object>? _matchPrototype(List<Object> args, List<XPathArgType> types) {
  if (types.length != args.length) return null;
  final typed = <Object>[];
  for (var i = 0; i < types.length; i++) {
    final arg = args[i];
    final type = types[i];
    final alreadyTyped = switch (type) {
      XPathArgType.boolean => arg is bool,
      XPathArgType.number => arg is double,
      XPathArgType.string => arg is String,
      XPathArgType.date => arg is DateTime,
      XPathArgType.nodeset => arg is XPathNodeset,
      XPathArgType.any => true,
    };
    if (alreadyTyped) {
      typed.add(arg);
      continue;
    }
    try {
      final converted = switch (type) {
        XPathArgType.boolean => toBoolean(arg),
        XPathArgType.number => toNumeric(arg),
        XPathArgType.string => toXPathString(arg),
        XPathArgType.date => toDate(arg, preserveTime: false),
        _ => null,
      };
      if (converted == null) return null;
      typed.add(converted);
    } on XPathTypeMismatchException {
      return null;
    }
  }
  return typed;
}
