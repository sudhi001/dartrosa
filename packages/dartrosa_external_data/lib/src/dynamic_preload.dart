import 'package:dartrosa/javarosa.dart';

import 'external_data_handler.dart';
import 'external_data_handler_pull.dart';
import 'external_data_util.dart';

/// Marks a form that uses `pulldata()` or a `search()` appearance, so its
/// CSV media are imported when it loads.
///
/// Port of Collect's `DynamicPreloadExtra`. DartRosa addition:
/// [referencedDataSets], the data set names given as string literals, used
/// to find the CSVs when the app can't list the form's media.
final class DynamicPreloadExtra {
  /// Creates the marker.
  DynamicPreloadExtra([Iterable<String> referencedDataSets = const []])
    : referencedDataSets = Set.unmodifiable(referencedDataSets);

  /// Normalized data set names (lower case, without `.csv`) passed as
  /// literals to `pulldata()` and `search()`.
  final Set<String> referencedDataSets;
}

/// Finds out whether a form uses `pulldata()` or `search()` and marks it
/// with a [DynamicPreloadExtra]. Keeps per-form state: use one per parse.
///
/// Port of Collect's `DynamicPreloadParseProcessor` (added to every parser
/// by `DynamicPreloadXFormParserFactory`).
final class DynamicPreloadParseProcessor
    implements XPathProcessor, QuestionProcessor, FormDefProcessor {
  var _containsPullData = false;
  var _containsSearch = false;
  final Set<String> _dataSets = {};

  @override
  void processXPath(XPathExpression expression) {
    _collectPullDataSets(expression);
    if (_containsPullData) return;
    if (expression.containsFunc(ExternalDataHandlerPull.handlerName)) {
      _containsPullData = true;
    }
  }

  @override
  void processQuestion(QuestionDef question) {
    final search = ExternalDataUtil.getSearchXPathExpression(
      question.appearance,
    );
    if (search?.args.first case XPathStringLiteral(:final value)) {
      _dataSets.add(ExternalDataHandler.normalize(value));
    }
    if (search != null) _containsSearch = true;
  }

  @override
  void processFormDef(FormDef form) {
    if (_containsPullData || _containsSearch) {
      form.extras.put(DynamicPreloadExtra(_dataSets));
    }
  }

  void _collectPullDataSets(XPathExpression expression) {
    switch (expression) {
      case XPathFuncExpr(:final id, :final args):
        if (args case [
          XPathStringLiteral(:final value),
          ...,
        ] when id.toString() == ExternalDataHandlerPull.handlerName) {
          _dataSets.add(ExternalDataHandler.normalize(value));
        }
        args.forEach(_collectPullDataSets);
      case XPathBinaryOpExpr(:final a, :final b):
        _collectPullDataSets(a);
        _collectPullDataSets(b);
      case XPathNumNegExpr(:final a):
        _collectPullDataSets(a);
      case XPathFilterExpr(:final x, :final predicates):
        _collectPullDataSets(x);
        predicates.forEach(_collectPullDataSets);
      case XPathPathExpr(:final filterExpr, :final steps):
        if (filterExpr != null) _collectPullDataSets(filterExpr);
        for (final step in steps) {
          step.predicates.forEach(_collectPullDataSets);
        }
      case XPathNumericLiteral() ||
          XPathStringLiteral() ||
          XPathVariableReference():
        break;
    }
  }
}
