import 'package:dartrosa/javarosa.dart';

import '../../storage/entities_repository.dart';
import '../../storage/query.dart';
import '../../storage/query_exception.dart';
import '../instance/local_entities_instance_adapter.dart';

/// `pulldata(instance, child, filterChild, filterValue)` on local entity
/// lists: the `child` value of the first entity whose `filterChild` is
/// `filterValue` (`''` if none). Other instances go to [fallback] (e.g.
/// the app's CSV `pulldata`), or give `''`.
///
/// Port of
/// `org.odk.collect.entities.javarosa.filter.PullDataFunctionHandler`.
/// The repository's list names are read when the handler is created.
final class PullDataFunctionHandler extends XPathFunctionHandler {
  /// Creates the handler.
  PullDataFunctionHandler(
    EntitiesRepository entitiesRepository, {
    XPathFunctionHandler? fallback,
  }) : _instanceAdapter = LocalEntitiesInstanceAdapter(entitiesRepository),
       _fallback = fallback;

  final LocalEntitiesInstanceAdapter _instanceAdapter;
  final XPathFunctionHandler? _fallback;

  /// The function name, `pulldata`.
  static const functionName = 'pulldata';

  @override
  String get name => functionName;

  @override
  List<List<XPathArgType>> get prototypes => const [];

  @override
  bool get rawArgs => true;

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    final instanceId = toXPathString(args[0]);

    if (_instanceAdapter.supportsInstance(instanceId)) {
      final child = toXPathString(args[1]);
      final filterChild = toXPathString(args[2]);
      final filterValue = toXPathString(args[3]);

      try {
        final results = _instanceAdapter.query(
          instanceId,
          StringEqQuery(filterChild, filterValue),
        );
        if (results.isEmpty) return '';
        return results.first.firstChild(child)?.value?.value ?? '';
      } on QueryException {
        return '';
      }
    }
    return _fallback?.eval(args, context) ?? '';
  }
}
