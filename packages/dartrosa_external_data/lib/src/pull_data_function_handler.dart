import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

/// Answers `pulldata()` for instances other than CSV media, such as
/// Collect's local entity lists.
///
/// Stands in for Collect's `LocalEntitiesInstanceAdapter` as used by the
/// entities module's `PullDataFunctionHandler`; an entities package can
/// implement it over its repository.
abstract interface class PullDataInstanceAdapter {
  /// Whether [instanceId] is one of this adapter's instances.
  bool supportsInstance(String instanceId);

  /// The items of [instanceId] whose child [filterChild] equals
  /// [filterValue], in order. Throws [PullDataQueryException] if the query
  /// can't be answered.
  List<TreeElement> query(
    String instanceId,
    String filterChild,
    String filterValue,
  );
}

/// A [PullDataInstanceAdapter] query failed (Collect's `QueryException`).
final class PullDataQueryException implements Exception {
  /// Creates the exception with [message].
  PullDataQueryException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'PullDataQueryException: $message';
}

/// `pulldata(instance, child, filter-child, value)` over the instances of
/// [instanceAdapter], falling back to [fallback] (the CSV handler) for
/// other instance ids.
///
/// Port of the entities module's
/// `org.odk.collect.entities.javarosa.filter.PullDataFunctionHandler`.
final class PullDataFunctionHandler extends XPathFunctionHandler {
  /// Creates the handler.
  PullDataFunctionHandler(this.instanceAdapter, {this.fallback});

  /// The instances answered directly, if any.
  final PullDataInstanceAdapter? instanceAdapter;

  /// Handles other instance ids (Collect: `ExternalDataHandlerPull`).
  final XPathFunctionHandler? fallback;

  @override
  String get name => 'pulldata';

  @override
  List<List<XPathArgType>> get prototypes => const [];

  @override
  bool get rawArgs => true;

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    final adapter = instanceAdapter;
    final instanceId = args.isEmpty ? '' : toXPathString(args[0]);
    if (adapter != null && adapter.supportsInstance(instanceId)) {
      if (args.length < 4) {
        throw XPathUnhandledException(
          "function 'pulldata' requires 4 arguments. ${args.length} provided.",
        );
      }
      final child = toXPathString(args[1]);
      final filterChild = toXPathString(args[2]);
      final filterValue = toXPathString(args[3]);
      try {
        final first = adapter
            .query(instanceId, filterChild, filterValue)
            .firstOrNull;
        return first?.getChild(child, 0)?.value?.displayText ?? '';
      } on PullDataQueryException {
        return '';
      }
    }
    return fallback?.eval(args, context) ?? '';
  }
}

/// A [PullDataInstanceAdapter] over in-memory lists of items, each a map of
/// child name to value (for tests and simple apps).
final class InMemoryPullDataInstanceAdapter implements PullDataInstanceAdapter {
  /// Creates the adapter serving [instances] (instance id → items).
  InMemoryPullDataInstanceAdapter(this.instances);

  /// The items of each instance.
  final Map<String, List<Map<String, String>>> instances;

  @override
  bool supportsInstance(String instanceId) => instances.containsKey(instanceId);

  @override
  List<TreeElement> query(
    String instanceId,
    String filterChild,
    String filterValue,
  ) => [
    for (final item in instances[instanceId] ?? const <Map<String, String>>[])
      if (item[filterChild] == filterValue) _toElement(item),
  ];

  static TreeElement _toElement(Map<String, String> item) {
    final element = TreeElement('item');
    for (final MapEntry(:key, :value) in item.entries) {
      element.addChild(TreeElement(key)..value = StringValue(value));
    }
    return element;
  }
}
