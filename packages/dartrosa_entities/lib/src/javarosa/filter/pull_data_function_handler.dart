import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart'
    show PullDataInstanceAdapter, PullDataQueryException;

import '../../storage/entities_repository.dart';
import '../../storage/query.dart';
import '../../storage/query_exception.dart';
import '../instance/local_entities_instance_adapter.dart';

/// `pulldata(instance, child, filterChild, filterValue)` on local entity
/// lists: the `child` value of the first entity whose `filterChild` is
/// `filterValue` (`''` if none). Other instances go to the fallback
/// handler, if any (e.g. the app's CSV `pulldata`), or give `''`.
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

/// Local entity lists as a `pulldata()` source for
/// `dartrosa_external_data`'s `ExternalDataPlugin`, which asks it before
/// falling back to CSV media — the order of Collect's entities
/// `PullDataFunctionHandler` with its CSV fallback.
final class EntitiesPullDataInstanceAdapter implements PullDataInstanceAdapter {
  /// Creates the adapter over [entitiesRepository].
  EntitiesPullDataInstanceAdapter(EntitiesRepository entitiesRepository)
    : _instanceAdapter = LocalEntitiesInstanceAdapter(entitiesRepository);

  final LocalEntitiesInstanceAdapter _instanceAdapter;

  @override
  bool supportsInstance(String instanceId) =>
      _instanceAdapter.supportsInstance(instanceId);

  @override
  List<TreeElement> query(
    String instanceId,
    String filterChild,
    String filterValue,
  ) {
    try {
      return _instanceAdapter.query(
        instanceId,
        StringEqQuery(filterChild, filterValue),
      );
    } on QueryException catch (e) {
      throw PullDataQueryException(e.message ?? '$e');
    }
  }
}
