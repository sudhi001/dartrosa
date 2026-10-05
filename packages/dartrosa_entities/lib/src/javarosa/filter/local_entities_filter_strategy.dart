// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (LocalEntitiesFilterStrategy), Copyright University
//  of Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:dartrosa/dartrosa.dart' show TreeReference;
import 'package:dartrosa/javarosa.dart';

import '../../storage/entities_repository.dart';
import '../../storage/query.dart';
import '../../storage/query_exception.dart';
import '../instance/local_entities_instance_adapter.dart';
import '../parse/xpath_expression_ext.dart';

/// A [FilterStrategy] that will use an [EntitiesRepository] to perform
/// filters. For supported expressions, this prevents the engine from using
/// its standard [FilterStrategy] chain which requires loading the whole
/// secondary instance into memory (assuming that
/// `LocalEntitiesInstanceProvider` or similar is used to take advantage of
/// partial parsing).
///
/// Port of
/// `org.odk.collect.entities.javarosa.filter.LocalEntitiesFilterStrategy`.
/// The repository's list names are read when the strategy is created;
/// create one per form load, as Collect does.
final class LocalEntitiesFilterStrategy implements FilterStrategy {
  /// Creates a strategy querying [entitiesRepository].
  LocalEntitiesFilterStrategy(EntitiesRepository entitiesRepository)
    : _instanceAdapter = LocalEntitiesInstanceAdapter(entitiesRepository);

  final LocalEntitiesInstanceAdapter _instanceAdapter;

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    final instanceId = sourceInstance.instanceId;
    if (instanceId == null || !_instanceAdapter.supportsInstance(instanceId)) {
      return next();
    }

    final query = predicate.toQuery(sourceInstance, context);
    if (query == null) return next();
    try {
      return _queryToTreeReferences(query, instanceId, sourceInstance);
    } on QueryException {
      return next();
    }
  }

  List<TreeReference> _queryToTreeReferences(
    Query query,
    String instanceId,
    DataInstance sourceInstance,
  ) {
    final results = _instanceAdapter.query(instanceId, query);
    sourceInstance.replacePartialElements(results);
    return [
      for (final element in results)
        (element..parent = sourceInstance.root).ref,
    ];
  }
}
